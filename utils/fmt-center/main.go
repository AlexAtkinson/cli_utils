package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"syscall"
	"unicode/utf8"
	"unsafe"
)

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(), "fmt-center - center text on a terminal line\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  fmt-center [--width N] [text ...]\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -w, --width N  Row width used for centering and wrapping\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h             Show help\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "If no text argument is provided and data is piped to stdin, the text will be read from stdin.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "\nExamples:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  fmt-center hello world\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  fmt-center $'\\e[01;33mWARNING\\e[0m'\n")
}

func getTerminalWidth() int {
	// Explicit override for deterministic testing and scripted usage.
	if v := strings.TrimSpace(os.Getenv("FMT_CENTER_COLS")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}

	// Prefer querying the real TTY width from stdout/stdin/stderr.
	for _, fd := range []uintptr{os.Stdout.Fd(), os.Stdin.Fd(), os.Stderr.Fd()} {
		if cols := ttyCols(fd); cols > 0 {
			return cols
		}
	}

	// Fall back to COLUMNS if exported.
	if v := strings.TrimSpace(os.Getenv("COLUMNS")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}

	// Last-resort fallback.
	return 80
}

func ttyCols(fd uintptr) int {
	ws := &struct {
		Row    uint16
		Col    uint16
		Xpixel uint16
		Ypixel uint16
	}{}

	_, _, errno := syscall.Syscall(
		syscall.SYS_IOCTL,
		fd,
		uintptr(syscall.TIOCGWINSZ),
		uintptr(unsafe.Pointer(ws)),
	)
	if errno != 0 || ws.Col == 0 {
		return 0
	}
	return int(ws.Col)
}

func wrapText(text string, width int) []string {
	parts := strings.Split(text, "\n")
	if width <= 0 {
		return parts
	}

	out := make([]string, 0, len(parts)*2)

	for _, part := range parts {
		if part == "" {
			out = append(out, "")
			continue
		}

		var b strings.Builder
		visible := 0
		for idx := 0; idx < len(part); {
			if seqLen := ansiSeqLen(part[idx:]); seqLen > 0 {
				b.WriteString(part[idx : idx+seqLen])
				idx += seqLen
				continue
			}

			r, size := utf8.DecodeRuneInString(part[idx:])
			if r == utf8.RuneError && size == 1 {
				if visible == width {
					out = append(out, b.String())
					b.Reset()
					visible = 0
				}
				b.WriteByte(part[idx])
				idx++
				visible++
				continue
			}

			if visible == width {
				out = append(out, b.String())
				b.Reset()
				visible = 0
			}

			b.WriteRune(r)
			idx += size
			visible++
		}

		out = append(out, b.String())
	}

	return out
}

func ansiSeqLen(s string) int {
	if len(s) < 3 || s[0] != 0x1b || s[1] != '[' {
		return 0
	}
	for i := 2; i < len(s); i++ {
		b := s[i]
		if (b >= '0' && b <= '9') || b == ';' || b == '?' {
			continue
		}
		if b >= 0x40 && b <= 0x7e {
			return i + 1
		}
		return 0
	}
	return 0
}

func visibleRuneLen(s string) int {
	count := 0
	for idx := 0; idx < len(s); {
		if seqLen := ansiSeqLen(s[idx:]); seqLen > 0 {
			idx += seqLen
			continue
		}
		_, size := utf8.DecodeRuneInString(s[idx:])
		if size <= 0 {
			break
		}
		idx += size
		count++
	}
	return count
}

func main() {
	flag.CommandLine.SetOutput(os.Stdout)
	flag.CommandLine.Usage = usage
	help := flag.Bool("h", false, "show help")
	width := flag.Int("width", 0, "row width used for centering and wrapping")
	widthShort := flag.Int("w", 0, "row width used for centering and wrapping")
	flag.Parse()

	if *help {
		usage()
		return
	}

	if *width < 0 || *widthShort < 0 {
		fmt.Fprintln(os.Stderr, "error: --width/-w must be >= 0")
		os.Exit(2)
	}

	var text string

	args := flag.Args()
	if len(args) == 0 {
		// check for piped stdin
		fi, _ := os.Stdin.Stat()
		if (fi.Mode() & os.ModeCharDevice) == 0 {
			data, err := io.ReadAll(os.Stdin)
			if err != nil {
				fmt.Fprintf(os.Stderr, "error reading stdin: %v\n", err)
				os.Exit(2)
			}
			text = strings.TrimRight(string(data), "\n")
		} else {
			fmt.Fprintln(os.Stderr, "error: no input provided; try --help")
			os.Exit(2)
		}
	} else {
		text = strings.Join(args, " ")
	}

	rowWidth := getTerminalWidth()
	if *width > 0 {
		rowWidth = *width
	}
	if *widthShort > 0 {
		rowWidth = *widthShort
	}

	lines := wrapText(text, rowWidth)
	for _, line := range lines {
		strLen := visibleRuneLen(line)
		if strLen > rowWidth {
			strLen = rowWidth
		}

		totalPad := rowWidth - strLen
		if totalPad < 0 {
			totalPad = 0
		}
		leftPad := totalPad / 2        // floor (left-bias on odd padding)
		rightPad := totalPad - leftPad // ceil when odd

		leftFiller := strings.Repeat(" ", leftPad)
		rightFiller := strings.Repeat(" ", rightPad)

		fmt.Print(leftFiller)
		fmt.Print(line)
		fmt.Print(rightFiller)
		fmt.Print("\n")
	}
}
