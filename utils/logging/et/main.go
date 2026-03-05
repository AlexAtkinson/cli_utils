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

const timeFormat = "2006-01-02T15-04-05Z"

func commandName() string {
	name := strings.TrimSpace(filepath.Base(os.Args[0]))
	if name == "" {
		return "et"
	}
	return name
}

func usage() {
	cmd := commandName()
	fmt.Fprintf(flag.CommandLine.Output(), "%s - log task start via loggerx\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  %s\n\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "Behavior:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Reads TASK from environment.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Logs: TASK START: <TASK>...\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - If TASK is unset, logs a warning and uses \"UNSET TASK\".\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Examples:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  export TASK=\"Deploy release\"\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  %s\n", cmd)
	fmt.Fprintf(flag.CommandLine.Output(), "\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help      Show this help and exit\n")
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

func inferAppName() string {
	if appName := strings.TrimSpace(os.Getenv("APP_NAME")); appName != "" {
		return appName
	}

	if parentPath, err := os.Readlink(fmt.Sprintf("/proc/%d/exe", os.Getppid())); err == nil {
		appName := strings.TrimSpace(filepath.Base(parentPath))
		if appName != "" && appName != "loggerx" {
			return appName
		}
	}

	return filepath.Base(os.Args[0])
}

func fallbackInfo(message string) {
	timestamp := time.Now().UTC().Format(timeFormat)
	appName := inferAppName()
	fmt.Printf("%s %s[%d] INFO: %s\n", timestamp, appName, os.Getppid(), message)
}

func logWithLevel(level string, message string) {
	if loggerxPath, err := exec.LookPath("loggerx"); err == nil {
		cmd := exec.Command(loggerxPath, level, message)
		env := os.Environ()
		env = append(env, "APP_NAME="+inferAppName())
		env = append(env, fmt.Sprintf("APP_PID=[%d] ", os.Getppid()))
		cmd.Env = env
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if runErr := cmd.Run(); runErr == nil {
			return
		}
	}

	if level == "WARNING" {
		fallbackInfo("WARNING: " + message)
		return
	}
	fallbackInfo(message)
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

	task := strings.TrimSpace(os.Getenv("TASK"))
	if task == "" {
		logWithLevel("WARNING", "'TASK' not set. 'TASK' must be exported.")
		task = "UNSET TASK"
	}

	message := fmt.Sprintf("TASK START: %s...", task)
	logWithLevel("INFO", message)
}
