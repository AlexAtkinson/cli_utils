package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type levelSpec struct {
	color  string
	indent int
}

const timeFormat = "2006-01-02T15-04-05Z"

var levelTable = map[string]levelSpec{
	"EMERGENCY": {color: "\x1b[01;30;41m", indent: 39},
	"ALERT":     {color: "\x1b[01;31;43m", indent: 35},
	"CRITICAL":  {color: "\x1b[01;97;41m", indent: 38},
	"ERROR":     {color: "\x1b[01;31m", indent: 35},
	"WARNING":   {color: "\x1b[01;33m", indent: 37},
	"NOTICE":    {color: "\x1b[01;30;107m", indent: 36},
	"INFO":      {color: "\x1b[01;39m", indent: 34},
	"DEBUG":     {color: "\x1b[01;97;46m", indent: 35},
	"SUCCESS":   {color: "\x1b[01;32m", indent: 37},
}

func commandName() string {
	name := strings.TrimSpace(filepath.Base(os.Args[0]))
	if name == "" {
		return "loggerx"
	}
	return name
}

func usage() {
	cmd := commandName()
	fmt.Fprintf(flag.CommandLine.Output(), "%s - syslog-style logger for better DX\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  %s <LEVEL> <MESSAGE...>\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Levels:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG SUCCESS\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Behavior:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Writes colored output to stdout.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Sends raw message to syslog via logger.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Accepts multi-line messages.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Uses APP_NAME from environment when set; otherwise infers caller name.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - If LOG_TO_FILE=true, also appends formatted output to LOG_FILE.\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Examples:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  %s INFO \"Service started\"\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "  APP_NAME=myapp %s WARNING \"Disk usage high\"\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help           Show this help and exit\n\n")
}

func normalizeArgs(args []string) []string {
	normalized := make([]string, 0, len(args))
	for _, arg := range args {
		switch arg {
		case "--help":
			normalized = append(normalized, "-h")
		default:
			normalized = append(normalized, arg)
		}
	}
	return normalized
}

func envBool(name string) bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv(name)))
	return v == "1" || v == "true" || v == "yes" || v == "on"
}

func collapseSpaces(value string) string {
	return strings.Join(strings.Fields(value), " ")
}

func appendFile(path string, text string) error {
	file, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = file.WriteString(text + "\n")
	return err
}

func inferAppName() string {
	if appName := strings.TrimSpace(os.Getenv("APP_NAME")); appName != "" {
		return appName
	}
	if parentPath, err := os.Readlink(fmt.Sprintf("/proc/%d/exe", os.Getppid())); err == nil {
		name := filepath.Base(parentPath)
		if name != "" && name != "loggerx" {
			return name
		}
	}
	return filepath.Base(os.Args[0])
}

func sendSyslog(raw string) error {
	cmd := exec.Command("logger")
	cmd.Stdin = strings.NewReader(raw)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	flag.CommandLine.SetOutput(os.Stdout)
	flag.CommandLine.Usage = usage

	help := flag.Bool("h", false, "show help")

	os.Args = append([]string{os.Args[0]}, normalizeArgs(os.Args[1:])...)
	flag.Parse()

	if *help {
		usage()
		return
	}

	if flag.NArg() < 2 {
		fmt.Fprintln(os.Stderr, "error: expected LEVEL and MESSAGE...")
		fmt.Fprintf(os.Stderr, "try: %s --help\n", commandName())
		os.Exit(2)
	}

	level := strings.ToUpper(flag.Arg(0))
	spec, ok := levelTable[level]
	if !ok {
		fmt.Fprintf(os.Stderr, "Invalid log level: %q\n", level)
		os.Exit(1)
	}

	message := strings.TrimLeft(strings.Join(flag.Args()[1:], " "), " ")
	timestamp := time.Now().UTC().Format(timeFormat)
	hostname := os.Getenv("HOSTNAME")
	if strings.TrimSpace(hostname) == "" {
		if h, err := os.Hostname(); err == nil {
			hostname = h
		}
	}
	appName := inferAppName()
	appPID := fmt.Sprintf("[%d] ", os.Getppid())

	renderedLevel := spec.color + level + "\x1b[0m"
	formatted := fmt.Sprintf("%s %s %s%s%s: %s", timestamp, hostname, appName, appPID, renderedLevel, message)
	indent := strings.Repeat(" ", spec.indent)
	logLine := strings.ReplaceAll(formatted, "\n", "\n"+indent)

	if envBool("LOG_TO_FILE") {
		if logFile := strings.TrimSpace(os.Getenv("LOG_FILE")); logFile != "" {
			fmt.Println(logLine)
			if err := appendFile(logFile, logLine); err != nil {
				fmt.Fprintf(os.Stderr, "error: unable to append to log file %q: %v\n", logFile, err)
				os.Exit(1)
			}
		} else {
			fmt.Println(logLine)
		}
	} else {
		fmt.Println(logLine)
	}

	raw := fmt.Sprintf("%s%s%s: %s", appName, appPID, level, collapseSpaces(message))
	if err := sendSyslog(raw); err != nil {
		os.Exit(1)
	}
}
