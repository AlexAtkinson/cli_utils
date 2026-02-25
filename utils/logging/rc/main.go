package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const timeFormat = "2006-01-02T15:04:05.000Z"

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(), "rc - log task end and validate exit codes\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  rc [options] EXPECTED [KILL]\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Behavior:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Compares EXPECTED against ACTUAL (from --actual or RC_EXIT_CODE).\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - On match, logs: TASK END: <task>.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - On mismatch, logs an ERROR with expected/actual detail.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - If KILL is supplied, exits with ACTUAL when mismatch occurs.\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -a, --actual INT   Actual exit code to validate (default: $RC_EXIT_CODE or 0)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -t, --task TEXT    Task label (default: TASK from process environment)\n")
	fmt.Fprintf(flag.CommandLine.Output(), "                    Use either: export TASK=...; rc ...  OR  TASK=... rc ...\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help         Show this help and exit\n")
}

func normalizeArgs(args []string) []string {
	normalized := make([]string, 0, len(args))
	for _, arg := range args {
		switch arg {
		case "--help":
			normalized = append(normalized, "-h")
		case "--actual":
			normalized = append(normalized, "-a")
		case "--task":
			normalized = append(normalized, "-t")
		default:
			normalized = append(normalized, arg)
		}
	}
	return normalized
}

func parseInt(value string, field string) (int, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, errors.New(field + " is empty")
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("invalid %s %q", field, value)
	}

	return parsed, nil
}

func parseExpected(args []string) (int, bool, error) {
	if len(args) == 0 {
		return 0, false, errors.New("missing EXPECTED")
	}

	expected, err := parseInt(args[0], "EXPECTED")
	if err != nil {
		return 0, false, err
	}

	kill := false
	if len(args) > 1 {
		if strings.EqualFold(strings.TrimSpace(args[1]), "KILL") {
			kill = true
		} else {
			return 0, false, fmt.Errorf("unexpected argument %q (expected KILL)", args[1])
		}
	}

	if len(args) > 2 {
		return 0, false, errors.New("too many positional arguments")
	}

	return expected, kill, nil
}

func fallbackLog(level string, message string) {
	timestamp := time.Now().UTC().Format(timeFormat)
	fmt.Printf("%s %s: %s\n", timestamp, level, message)
}

func logWithLoggerx(level string, message string) bool {
	loggerxPath, err := exec.LookPath("loggerx")
	if err != nil {
		return false
	}

	cmd := exec.Command(loggerxPath, level, message)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if runErr := cmd.Run(); runErr != nil {
		return false
	}

	return true
}

func logMessage(level string, message string) {
	if logWithLoggerx(level, message) {
		return
	}
	fallbackLog(level, message)
}

func taskFromEnv() string {
	for _, key := range []string{"TASK", "task", "RC_TASK", "ET_TASK"} {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			return value
		}
	}
	return ""
}

func main() {
	flag.CommandLine.SetOutput(os.Stdout)
	flag.CommandLine.Usage = usage

	defaultTask := taskFromEnv()
	actualFlag := flag.Int("a", 0, "actual exit code")
	taskFlag := flag.String("t", defaultTask, "task label")
	help := flag.Bool("h", false, "show help")

	os.Args = append([]string{os.Args[0]}, normalizeArgs(os.Args[1:])...)
	flag.Parse()

	if *help {
		usage()
		return
	}

	expected, kill, err := parseExpected(flag.Args())
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		fmt.Fprintln(os.Stderr, "try: rc --help")
		os.Exit(2)
	}

	actual := *actualFlag
	if rawEnvActual := strings.TrimSpace(os.Getenv("RC_EXIT_CODE")); rawEnvActual != "" {
		parsed, parseErr := parseInt(rawEnvActual, "RC_EXIT_CODE")
		if parseErr != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", parseErr)
			os.Exit(2)
		}
		actual = parsed
	}

	task := strings.TrimSpace(*taskFlag)
	if task == "" {
		task = "(unset TASK)"
	}

	if expected == actual {
		logMessage("SUCCESS", fmt.Sprintf("TASK END: %s.", task))
		return
	}

	logMessage("ERROR", fmt.Sprintf("TASK END: %s (exit code: %d -- expected code: %d)", task, actual, expected))
	if kill {
		os.Exit(actual)
	}
}
