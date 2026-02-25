package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

const timeFormat = "2006-01-02T15:04:05.000Z"

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(), "et - log task start messages\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  et [TASK words...]\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Behavior:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - If TASK arguments are provided, they are joined into the task name.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - If no TASK args are provided, et uses the TASK environment variable.\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  - Emits: TASK START: <task>...\n\n")
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

func taskFromInput(positional []string) string {
	if len(positional) > 0 {
		return strings.TrimSpace(strings.Join(positional, " "))
	}
	return strings.TrimSpace(os.Getenv("TASK"))
}

func fallbackInfo(message string) {
	timestamp := time.Now().UTC().Format(timeFormat)
	fmt.Printf("%s INFO: %s\n", timestamp, message)
}

func logTaskStart(message string) {
	if loggerxPath, err := exec.LookPath("loggerx"); err == nil {
		cmd := exec.Command(loggerxPath, "INFO", message)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if runErr := cmd.Run(); runErr == nil {
			return
		}
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

	task := taskFromInput(flag.Args())
	if task == "" {
		fmt.Fprintln(os.Stderr, "error: task is empty")
		fmt.Fprintln(os.Stderr, "pass a task as arguments or set TASK in the environment")
		fmt.Fprintln(os.Stderr, "try: et --help")
		os.Exit(2)
	}

	message := fmt.Sprintf("TASK START: %s...", task)
	logTaskStart(message)
}
