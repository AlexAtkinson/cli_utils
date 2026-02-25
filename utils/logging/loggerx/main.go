package main

import (
	"flag"
	"fmt"
	"log/syslog"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type levelSpec struct {
	color    string
	indent   int
	priority syslog.Priority
}

const timeFormat = "2006-01-02T15:04:05.000Z"

var levelTable = map[string]levelSpec{
	"EMERGENCY": {color: "\x1b[01;30;41m", indent: 39, priority: syslog.LOG_EMERG},
	"ALERT":     {color: "\x1b[01;31;43m", indent: 35, priority: syslog.LOG_ALERT},
	"CRITICAL":  {color: "\x1b[01;97;41m", indent: 38, priority: syslog.LOG_CRIT},
	"ERROR":     {color: "\x1b[01;31m", indent: 35, priority: syslog.LOG_ERR},
	"WARNING":   {color: "\x1b[01;33m", indent: 37, priority: syslog.LOG_WARNING},
	"NOTICE":    {color: "\x1b[01;30;107m", indent: 36, priority: syslog.LOG_NOTICE},
	"INFO":      {color: "\x1b[01;39m", indent: 34, priority: syslog.LOG_INFO},
	"DEBUG":     {color: "\x1b[01;97;46m", indent: 35, priority: syslog.LOG_DEBUG},
	"SUCCESS":   {color: "\x1b[01;32m", indent: 37, priority: syslog.LOG_INFO},
}

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(), "loggerx - colorized terminal logger with syslog output\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  loggerx [options] LEVEL MESSAGE...\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Levels:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG SUCCESS\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  --log-to-file        Also append rendered output to a log file\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  --log-file PATH      Log file path (default: $LOG_FILE or ./loggerx.log)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  --no-color           Disable ANSI colors in terminal output\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help           Show this help and exit\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Environment:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  LOG_TO_FILE=true|false   Default value for --log-to-file\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  LOG_FILE=PATH            Default value for --log-file\n")
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

func sendSyslog(tag string, priority syslog.Priority, raw string) error {
	writer, err := syslog.New(priority, tag)
	if err != nil {
		return err
	}
	defer writer.Close()

	_, err = writer.Write([]byte(raw))
	return err
}

func main() {
	flag.CommandLine.SetOutput(os.Stdout)
	flag.CommandLine.Usage = usage

	defaultLogFile := strings.TrimSpace(os.Getenv("LOG_FILE"))
	if defaultLogFile == "" {
		defaultLogFile = "loggerx.log"
	}

	logToFile := flag.Bool("log-to-file", envBool("LOG_TO_FILE"), "append terminal output to log file")
	logFile := flag.String("log-file", defaultLogFile, "file path for --log-to-file")
	noColor := flag.Bool("no-color", false, "disable ANSI colors in output")
	help := flag.Bool("h", false, "show help")

	os.Args = append([]string{os.Args[0]}, normalizeArgs(os.Args[1:])...)
	flag.Parse()

	if *help {
		usage()
		return
	}

	if flag.NArg() < 2 {
		fmt.Fprintln(os.Stderr, "error: expected LEVEL and MESSAGE")
		fmt.Fprintln(os.Stderr, "try: loggerx --help")
		os.Exit(2)
	}

	level := strings.ToUpper(flag.Arg(0))
	spec, ok := levelTable[level]
	if !ok {
		fmt.Fprintln(os.Stderr, "ERROR Invalid log level")
		os.Exit(1)
	}

	message := strings.TrimLeft(strings.Join(flag.Args()[1:], " "), " ")
	timestamp := time.Now().UTC().Format(timeFormat)

	renderedLevel := level
	if !*noColor {
		renderedLevel = spec.color + level + "\x1b[0m"
	}

	formatted := fmt.Sprintf("%s %s: %s", timestamp, renderedLevel, message)
	indent := strings.Repeat(" ", spec.indent)
	logLine := strings.ReplaceAll(formatted, "\n", "\n"+indent)

	fmt.Println(logLine)
	if *logToFile {
		if err := appendFile(*logFile, logLine); err != nil {
			fmt.Fprintf(os.Stderr, "error: unable to append to log file %q: %v\n", *logFile, err)
			os.Exit(1)
		}
	}

	tag := filepath.Base(os.Args[0])
	raw := fmt.Sprintf("%s %s: %s", tag, level, collapseSpaces(message))
	if err := sendSyslog(tag, spec.priority, raw); err != nil {
		fmt.Fprintf(os.Stderr, "warning: unable to write to syslog: %v\n", err)
	}
}
