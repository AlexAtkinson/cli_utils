package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func commandName() string {
	name := strings.TrimSpace(filepath.Base(os.Args[0]))
	if name == "" {
		return "rc"
	}
	return name
}

func usage() {
	cmd := commandName()
	fmt.Fprintf(flag.CommandLine.Output(), "%s - validate exit code and log task end via loggerx\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "NOTE: This departs from legacy 'rc', now requiring a minimum of two arguments.\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  %s <exit_code> <expected_code> [KILL]\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Arguments:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  exit_code      Actual exit code to evaluate. Will always be '$?'.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  expected_code  Expected exit code.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  KILL           Optional. Terminate program on error.\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Behavior:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Reads TASK from environment.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Logs SUCCESS on match, ERROR on mismatch.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - If TASK is unset, logs a warning and uses \"UNSET TASK\".\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Examples:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  export TASK=\"Run tests\"\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  false; %s $? 0 KILL\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help         Show this help and exit\n")
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

func parseInt(value string) (int, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, fmt.Errorf("value is empty")
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("invalid integer %q", value)
	}

	return parsed, nil
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

func logWithLoggerx(level string, message string) {
	loggerxPath, err := exec.LookPath("loggerx")
	if err != nil {
		fmt.Fprintf(os.Stderr, "loggerx not found: %v\n", err)
		os.Exit(127)
	}

	cmd := exec.Command(loggerxPath, level, message)
	env := os.Environ()
	env = append(env, "APP_NAME="+inferAppName())
	cmd.Env = env
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "loggerx failed: %v\n", err)
		os.Exit(1)
	}
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

	args := flag.Args()
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "error: missing required arguments")
		fmt.Fprintf(os.Stderr, "try: %s --help\n", commandName())
		os.Exit(2)
	}
	if len(args) > 3 {
		fmt.Fprintln(os.Stderr, "error: too many arguments")
		fmt.Fprintf(os.Stderr, "try: %s --help\n", commandName())
		os.Exit(2)
	}

	exitCode, err := parseInt(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid exit_code: %v\n", err)
		os.Exit(2)
	}
	exitDesired, err := parseInt(args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: invalid expected_code: %v\n", err)
		os.Exit(2)
	}

	task := strings.TrimSpace(os.Getenv("TASK"))
	if task == "" {
		logWithLoggerx("WARNING", "'TASK' not set. 'TASK' must be exported.")
		task = "UNSET TASK"
	}

	if exitDesired == exitCode {
		logWithLoggerx("SUCCESS", fmt.Sprintf("TASK END: %s.", task))
		return
	}

	logWithLoggerx("ERROR", fmt.Sprintf("TASK END: %s. (exit code: %d, expected: %d)", task, exitCode, exitDesired))
	if len(args) == 3 && strings.TrimSpace(args[2]) == "KILL" {
		os.Exit(exitCode)
	}
}
