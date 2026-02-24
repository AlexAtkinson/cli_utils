package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const redrawChainWindowSeconds = 1.0

var ansiPattern = regexp.MustCompile(`\x1b\[[0-9;]*m`)

type stateData struct {
	TitleRow              []string   `json:"title_row"`
	ContentRows           [][]string `json:"content_rows"`
	WidthArg              string     `json:"width_arg"`
	Frame                 bool       `json:"frame"`
	End                   bool       `json:"end"`
	OutputFormat          string     `json:"output_format"`
	LastRenderedLineCount int        `json:"last_rendered_line_count"`
	LastRenderedLines     []string   `json:"last_rendered_lines"`
	LastParentPID         int        `json:"last_parent_pid"`
	LastInvocationTS      float64    `json:"last_invocation_ts"`
}

type multiStringFlag []string

func (m *multiStringFlag) String() string {
	return strings.Join(*m, ",")
}

func (m *multiStringFlag) Set(value string) error {
	*m = append(*m, value)
	return nil
}

func defaultState() stateData {
	return stateData{
		TitleRow:              []string{},
		ContentRows:           [][]string{},
		WidthArg:              "dynamic",
		Frame:                 false,
		End:                   false,
		OutputFormat:          "markdown",
		LastRenderedLineCount: 0,
		LastRenderedLines:     []string{},
		LastParentPID:         0,
		LastInvocationTS:      0,
	}
}

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(), "Generate formatted tables in the terminal.\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  fmt-table [options]\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -t, --title-row TEXT     Comma-separated values for title row\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -r, --row TEXT           Comma-separated values for content row (repeatable)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -w, --width STR          Width strategy: dynamic|equal|full|INT\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -f, --frame              Accepted for compatibility (markdown-only output)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -e, --end                Accepted for compatibility (markdown-only output)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -a, --append             Append mode (skip top border on framed append)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -c, --clear-state        Clear persisted session state\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -n, --new-session        Ignore prior state for this invocation\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -m, --markdown           Accepted for compatibility (markdown-only output)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -b1, --bold-first-column Accepted for compatibility (no-op in Go version)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -s, --screen             Accepted for compatibility (falls back to stdout render)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -F, --force              Accepted for compatibility\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help               Show help and exit\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Examples:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  Create a table with header and rows:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "    fmt-table -n -t \"Name,Role\" -r \"Alice,Engineer\" -r \"Bob,Manager\" -f\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  Append rows to existing session:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "    fmt-table -r \"Charlie,Analyst\" -fa\n")
}

func normalizeArgs(args []string) []string {
	normalized := make([]string, 0, len(args))
	for _, arg := range args {
		switch arg {
		case "--title-row":
			normalized = append(normalized, "-t")
		case "--row":
			normalized = append(normalized, "-r")
		case "--width":
			normalized = append(normalized, "-w")
		case "--frame":
			normalized = append(normalized, "-f")
		case "--end":
			normalized = append(normalized, "-e")
		case "--append":
			normalized = append(normalized, "-a")
		case "--clear-state":
			normalized = append(normalized, "-c")
		case "--new-session":
			normalized = append(normalized, "-n")
		case "--markdown":
			normalized = append(normalized, "-m")
		case "--bold-first-column":
			normalized = append(normalized, "-b1")
		case "--screen":
			normalized = append(normalized, "-s")
		case "--force":
			normalized = append(normalized, "-F")
		case "--help":
			normalized = append(normalized, "-h")
		default:
			if strings.HasPrefix(arg, "-w") && len(arg) > 2 && !strings.HasPrefix(arg, "--") {
				normalized = append(normalized, "-w", arg[2:])
				continue
			}
			if strings.HasPrefix(arg, "-") && !strings.HasPrefix(arg, "--") && len(arg) > 2 {
				short := arg[1:]
				if isCombinedFlagSet(short) {
					for _, ch := range short {
						normalized = append(normalized, "-"+string(ch))
					}
					continue
				}
			}
			normalized = append(normalized, arg)
		}
	}
	return normalized
}

func isCombinedFlagSet(value string) bool {
	if value == "" {
		return false
	}
	allowed := "faecnmsFh"
	for _, ch := range value {
		if !strings.ContainsRune(allowed, ch) {
			return false
		}
	}
	return true
}

func parseRow(rowText string) []string {
	parts := strings.Split(rowText, ",")
	row := make([]string, 0, len(parts))
	for _, part := range parts {
		row = append(row, strings.TrimSpace(part))
	}
	return row
}

func stripANSI(text string) string {
	return ansiPattern.ReplaceAllString(text, "")
}

func getTerminalWidth() int {
	if value := strings.TrimSpace(os.Getenv("COLUMNS")); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 80
}

func calculateColumnWidths(titleRow []string, contentRows [][]string, widthArg string) []int {
	allRows := make([][]string, 0, 1+len(contentRows))
	if len(titleRow) > 0 {
		allRows = append(allRows, titleRow)
	}
	allRows = append(allRows, contentRows...)

	maxCols := 0
	for _, row := range allRows {
		if len(row) > maxCols {
			maxCols = len(row)
		}
	}
	if maxCols == 0 {
		return []int{10}
	}

	widths := make([]int, maxCols)
	for _, row := range allRows {
		for idx := 0; idx < maxCols; idx++ {
			cell := ""
			if idx < len(row) {
				cell = row[idx]
			}
			visible := len(stripANSI(cell))
			if visible > widths[idx] {
				widths[idx] = visible
			}
		}
	}

	switch {
	case widthArg == "equal":
		maxWidth := 1
		for _, width := range widths {
			if width > maxWidth {
				maxWidth = width
			}
		}
		equal := make([]int, maxCols)
		for idx := range equal {
			equal[idx] = maxWidth
		}
		return equal
	case widthArg == "full":
		return distributeWidth(getTerminalWidth(), maxCols)
	default:
		if custom, err := strconv.Atoi(widthArg); err == nil && custom > 0 {
			return distributeWidth(custom, maxCols)
		}
		return widths
	}
}

func distributeWidth(totalWidth int, cols int) []int {
	minFrame := 3*cols + 1
	contentArea := totalWidth - minFrame
	if contentArea < cols {
		contentArea = cols
	}
	base := contentArea / cols
	remainder := contentArea % cols
	widths := make([]int, cols)
	for idx := 0; idx < cols; idx++ {
		widths[idx] = base
		if idx < remainder {
			widths[idx]++
		}
		if widths[idx] < 1 {
			widths[idx] = 1
		}
	}
	return widths
}

func normalizeRow(row []string, maxCols int) []string {
	if len(row) < maxCols {
		out := make([]string, maxCols)
		copy(out, row)
		for idx := len(row); idx < maxCols; idx++ {
			out[idx] = ""
		}
		return out
	}
	return row[:maxCols]
}

func drawSeparator(colWidths []int) string {
	parts := make([]string, 0, len(colWidths))
	for _, width := range colWidths {
		parts = append(parts, strings.Repeat("-", width+2))
	}
	return "+" + strings.Join(parts, "+") + "+"
}

func renderASCIILines(titleRow []string, contentRows [][]string, colWidths []int, frame bool, end bool, appendMode bool) []string {
	lines := make([]string, 0)
	maxCols := len(colWidths)
	rowToLine := func(row []string) string {
		row = normalizeRow(row, maxCols)
		cells := make([]string, 0, maxCols)
		for idx := 0; idx < maxCols; idx++ {
			cells = append(cells, fmt.Sprintf(" %-*s ", colWidths[idx], row[idx]))
		}
		return "|" + strings.Join(cells, "|") + "|"
	}

	hasTitle := len(titleRow) > 0
	hasRows := len(contentRows) > 0
	hasContent := hasTitle || hasRows
	sep := drawSeparator(colWidths)

	if frame {
		lines = append(lines, sep)
	}

	if hasTitle {
		lines = append(lines, rowToLine(titleRow))
		if frame {
			lines = append(lines, sep)
		} else if hasRows {
			lines = append(lines, sep)
		}
	}

	for idx, row := range contentRows {
		lines = append(lines, rowToLine(row))
		if frame && idx < len(contentRows)-1 {
			lines = append(lines, sep)
		}
	}

	if end || (frame && hasContent) {
		lines = append(lines, sep)
	}

	return lines
}

func renderMarkdownLines(titleRow []string, contentRows [][]string, colWidths []int) []string {
	lines := make([]string, 0)
	maxCols := len(colWidths)
	rowToLine := func(row []string, bold bool) string {
		row = normalizeRow(row, maxCols)
		cells := make([]string, 0, maxCols)
		for idx := 0; idx < maxCols; idx++ {
			cell := row[idx]
			if bold {
				visible := len(stripANSI(cell))
				pad := colWidths[idx] - visible
				if pad < 0 {
					pad = 0
				}
				styled := "\x1b[1m" + cell + "\x1b[0m"
				cells = append(cells, " "+styled+strings.Repeat(" ", pad)+" ")
				continue
			}
			cells = append(cells, fmt.Sprintf(" %-*s ", colWidths[idx], cell))
		}
		return "|" + strings.Join(cells, "|") + "|"
	}

	if len(titleRow) > 0 {
		lines = append(lines, rowToLine(titleRow, true))
		sepParts := make([]string, 0, maxCols)
		for _, width := range colWidths {
			sepParts = append(sepParts, fmt.Sprintf(" %s ", strings.Repeat("-", width)))
		}
		lines = append(lines, "|"+strings.Join(sepParts, "|")+"|")
	}

	for _, row := range contentRows {
		lines = append(lines, rowToLine(row, false))
	}
	return lines
}

func renderStdoutDiff(lines []string, previous []string) {
	previousCount := len(previous)
	newCount := len(lines)
	overlap := previousCount
	if newCount < overlap {
		overlap = newCount
	}

	for idx := 0; idx < overlap; idx++ {
		if previous[idx] == lines[idx] {
			continue
		}
		up := previousCount - idx
		if up > 0 {
			fmt.Printf("\x1b[%dA", up)
		}
		fmt.Print("\r\x1b[2K")
		fmt.Print(lines[idx])
		if up > 0 {
			fmt.Printf("\x1b[%dB", up)
		}
	}

	if newCount > previousCount {
		for idx := previousCount; idx < newCount; idx++ {
			fmt.Print("\r\x1b[2K")
			fmt.Print(lines[idx])
			fmt.Print("\n")
		}
	} else if previousCount > newCount {
		for idx := newCount; idx < previousCount; idx++ {
			up := previousCount - idx
			if up > 0 {
				fmt.Printf("\x1b[%dA", up)
			}
			fmt.Print("\r\x1b[2K")
			if up > 0 {
				fmt.Printf("\x1b[%dB", up)
			}
		}
		shiftUp := previousCount - newCount
		if shiftUp > 0 {
			fmt.Printf("\x1b[%dA", shiftUp)
		}
	}

	fmt.Print("\r")
}

func stateFilePath() string {
	home, err := os.UserHomeDir()
	if err != nil || strings.TrimSpace(home) == "" {
		return filepath.Join(".", "state.json")
	}
	return filepath.Join(home, ".cache", "fmt-table", "state.json")
}

func loadState() stateData {
	state := defaultState()
	path := stateFilePath()
	content, err := os.ReadFile(path)
	if err != nil {
		return state
	}
	if err := json.Unmarshal(content, &state); err != nil {
		return defaultState()
	}
	if state.WidthArg == "" {
		state.WidthArg = "dynamic"
	}
	if state.OutputFormat == "" {
		state.OutputFormat = "markdown"
	}
	if state.TitleRow == nil {
		state.TitleRow = []string{}
	}
	if state.ContentRows == nil {
		state.ContentRows = [][]string{}
	}
	if state.LastRenderedLines == nil {
		state.LastRenderedLines = []string{}
	}
	return state
}

func saveState(state stateData) {
	path := stateFilePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return
	}
	encoded, err := json.Marshal(state)
	if err != nil {
		return
	}
	_ = os.WriteFile(path, encoded, 0o644)
}

func clearState() {
	_ = os.Remove(stateFilePath())
}

func mergeState(args parsedArgs) (stateData, bool) {
	state := defaultState()
	if !args.NewSession {
		state = loadState()
	}

	hadExisting := len(state.TitleRow) > 0 || len(state.ContentRows) > 0
	if args.NewSession || !hadExisting {
		state.OutputFormat = "markdown"
	}

	if args.TitleRow != "" {
		state.TitleRow = parseRow(args.TitleRow)
	}

	for _, rowText := range args.Rows {
		state.ContentRows = append(state.ContentRows, parseRow(rowText))
	}

	if args.WidthArg != "" {
		state.WidthArg = args.WidthArg
	}
	if args.Frame {
		state.Frame = true
	}
	if args.End {
		state.End = true
	}

	saveState(state)
	return state, hadExisting
}

type parsedArgs struct {
	TitleRow         string
	Rows             []string
	WidthArg         string
	Frame            bool
	End              bool
	Append           bool
	ClearState       bool
	NewSession       bool
	Markdown         bool
	BoldFirstColumn  bool
	Screen           bool
	Force            bool
	Help             bool
	UnexpectedPosArg []string
}

func parseArgs() (parsedArgs, error) {
	args := parsedArgs{}
	var rows multiStringFlag
	flag.CommandLine = flag.NewFlagSet(os.Args[0], flag.ContinueOnError)
	flag.CommandLine.SetOutput(os.Stdout)
	flag.CommandLine.Usage = usage

	flag.StringVar(&args.TitleRow, "t", "", "title row")
	flag.Var(&rows, "r", "content row")
	flag.StringVar(&args.WidthArg, "w", "dynamic", "width strategy")
	flag.BoolVar(&args.Frame, "f", false, "frame")
	flag.BoolVar(&args.End, "e", false, "end border")
	flag.BoolVar(&args.Append, "a", false, "append mode")
	flag.BoolVar(&args.ClearState, "c", false, "clear state")
	flag.BoolVar(&args.NewSession, "n", false, "new session")
	flag.BoolVar(&args.Markdown, "m", false, "markdown")
	flag.BoolVar(&args.BoldFirstColumn, "b1", false, "compatibility")
	flag.BoolVar(&args.Screen, "s", false, "compatibility")
	flag.BoolVar(&args.Force, "F", false, "compatibility")
	flag.BoolVar(&args.Help, "h", false, "help")

	normalized := normalizeArgs(os.Args[1:])
	if err := flag.CommandLine.Parse(normalized); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return args, nil
		}
		return args, err
	}

	args.Rows = rows
	args.UnexpectedPosArg = flag.CommandLine.Args()
	return args, nil
}

func isTTY(file *os.File) bool {
	info, err := file.Stat()
	if err != nil {
		return false
	}
	return (info.Mode() & os.ModeCharDevice) != 0
}

func main() {
	args, err := parseArgs()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(2)
	}

	if args.Help {
		usage()
		return
	}
	if len(args.UnexpectedPosArg) > 0 {
		fmt.Fprintln(os.Stderr, "error: unexpected positional arguments")
		fmt.Fprintln(os.Stderr, "try: fmt-table --help")
		os.Exit(2)
	}

	if args.ClearState {
		clearState()
		if args.TitleRow == "" && len(args.Rows) == 0 {
			fmt.Println("Fmt-table state cleared.")
			return
		}
	}

	if args.TitleRow == "" && len(args.Rows) == 0 {
		fmt.Fprintln(os.Stderr, "error: no table input provided")
		fmt.Fprintln(os.Stderr, "provide --title-row and/or --row")
		fmt.Fprintln(os.Stderr, "try: fmt-table --help")
		os.Exit(2)
	}

	state, hadExisting := mergeState(args)
	titleRow := state.TitleRow
	contentRows := state.ContentRows
	widthArg := state.WidthArg
	_ = state.Frame
	_ = state.End
	_ = state.OutputFormat

	interactiveStdout := isTTY(os.Stdout)
	currentParentPID := os.Getppid()
	currentTime := float64(time.Now().UnixNano()) / 1e9
	sameChainWindow := state.LastParentPID == currentParentPID && (currentTime-state.LastInvocationTS) <= redrawChainWindowSeconds
	appendContext := hadExisting && len(args.Rows) > 0 && args.TitleRow == ""

	colWidths := calculateColumnWidths(titleRow, contentRows, widthArg)
	lines := renderMarkdownLines(titleRow, contentRows, colWidths)

	if interactiveStdout {
		previous := state.LastRenderedLines
		if previous == nil {
			previous = []string{}
		}
		if appendContext && sameChainWindow {
			renderStdoutDiff(lines, previous)
		} else {
			fmt.Println(strings.Join(lines, "\n"))
		}

		state.LastRenderedLineCount = len(lines)
		state.LastRenderedLines = append([]string{}, lines...)
		state.LastParentPID = currentParentPID
		state.LastInvocationTS = currentTime
		saveState(state)
		return
	}

	fmt.Println(strings.Join(lines, "\n"))
}
