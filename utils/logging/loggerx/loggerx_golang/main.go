package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type levelSpec struct {
	color string
}

const timeFormat = "2006-01-02T15-04-05Z"

var levelTable = map[string]levelSpec{
	"EMERGENCY": {color: "\x1b[01;30;41m"},
	"ALERT":     {color: "\x1b[01;31;43m"},
	"CRITICAL":  {color: "\x1b[01;30;48:5:208m"},
	"ERROR":     {color: "\x1b[01;31m"},
	"WARNING":   {color: "\x1b[01;33m"},
	"NOTICE":    {color: "\x1b[01;95m"},
	"INFO":      {color: "\x1b[01;39m"},
	"DEBUG":     {color: "\x1b[01;94m"},
	"SUCCESS":   {color: "\x1b[01;32m"},
}

var numericLevelMap = map[string]string{
	"0": "EMERGENCY",
	"1": "ALERT",
	"2": "CRITICAL",
	"3": "ERROR",
	"4": "WARNING",
	"5": "NOTICE",
	"6": "INFO",
	"7": "DEBUG",
	"9": "SUCCESS",
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
	fmt.Printf("\n%s - syslog-style logger for improved developer experience (DX)\n\n", cmd)
	fmt.Printf("Writes output to stdout and sends raw messages to syslog via logger.\n")
	fmt.Printf("Supports multi-line messages and dynamic application naming.\n\n")
	fmt.Printf("Usage:\n")
	fmt.Printf("    %s <LEVEL> <MESSAGE...>\n\n", cmd)
	fmt.Printf("Levels:\n")
	fmt.Printf("    0/EMERGENCY    3/ERROR        6/INFO\n")
	fmt.Printf("    1/ALERT        4/WARNING      7/DEBUG\n")
	fmt.Printf("    2/CRITICAL     5/NOTICE       9/SUCCESS\n\n")
	fmt.Printf("Environment Variables:\n")
	fmt.Printf("    APP_NAME       Optional. Overrides inferred application name in logs.\n")
	fmt.Printf("    APP_PID        Optional. Overrides inferred PID in logs (e.g., for et/rc forwarding).\n")
	fmt.Printf("    LOG_TO_FILE    If set to \"true\", also appends formatted output to LOG_FILE.\n")
	fmt.Printf("    LOG_FILE       Path to log file when LOG_TO_FILE is enabled.\n")
	fmt.Printf("    SYSLOG         If set to \"true\", sends output to syslog as well as stdout.\n\n")
	fmt.Printf("Examples:\n")
	fmt.Printf("    %s INFO \"Service started\"\n", cmd)
	fmt.Printf("    export APP_NAME=myapp; %s WARNING \"Disk usage high\"\n\n", cmd)
}

func normalizeRawMessage(value string) string {
	if value == "" {
		return value
	}

	lines := strings.Split(value, "\n")
	for i := 1; i < len(lines); i++ {
		lines[i] = "    " + strings.TrimLeft(lines[i], "\t ")
	}

	return strings.Join(lines, "\n")
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

func normalizeLevel(value string) (string, bool) {
	if level, ok := numericLevelMap[value]; ok {
		return level, true
	}
	if _, ok := levelTable[value]; ok {
		return value, true
	}
	return "", false
}

func inferAppName() string {
	if appName := strings.TrimSpace(os.Getenv("APP_NAME")); appName != "" {
		return appName
	}

	ppid := os.Getppid()
	envPath := fmt.Sprintf("/proc/%d/task/%d/environ", ppid, ppid)
	if data, err := os.ReadFile(envPath); err == nil {
		entries := strings.Split(string(data), "\x00")
		for _, entry := range entries {
			if strings.HasPrefix(entry, "_=") {
				underscore := strings.TrimSpace(strings.TrimPrefix(entry, "_="))
				if underscore != "" {
					name := filepath.Base(underscore)
					if name != "" {
						if name == "loggerx" {
							break
						}
						return name
					}
				}
				break
			}
		}
	}

	name := commandName()
	if strings.TrimSpace(name) == "" {
		name = "loggerx"
	}

	if name == "loggerx" {
		cmdlinePath := fmt.Sprintf("/proc/%d/task/%d/cmdline", ppid, ppid)
		if data, err := os.ReadFile(cmdlinePath); err == nil {
			first := strings.SplitN(string(data), "\x00", 2)[0]
			if first = strings.TrimSpace(first); first != "" {
				if inferred := filepath.Base(first); strings.TrimSpace(inferred) != "" {
					name = inferred
				}
			}
		}
	}

	return name
}

func sendSyslog(raw string) error {
	cmd := exec.Command("logger")
	cmd.Stdin = strings.NewReader(raw)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "-h" || os.Args[1] == "--help") {
		usage()
		return
	}

	if len(os.Args) < 3 {
		usage()
		os.Exit(1)
	}

	argLevel := os.Args[1]
	level, levelValid := normalizeLevel(argLevel)
	if !levelValid {
		level = "ERROR"
		argLevel = strings.TrimSpace(argLevel)
		if argLevel == "" {
			argLevel = ""
		}
		os.Args = []string{os.Args[0], "ERROR", fmt.Sprintf("Invalid log level: '%s'!", argLevel)}
	}

	spec, exists := levelTable[level]
	if !exists {
		fmt.Fprintf(os.Stderr, "Invalid log level: '%s'!\n", level)
		os.Exit(1)
	}

	message := strings.TrimLeft(strings.Join(os.Args[2:], " "), " ")
	messageLines := strings.Split(message, "\n")
	for i := range messageLines {
		messageLines[i] = strings.TrimLeft(messageLines[i], " ")
	}
	message = strings.Join(messageLines, "\n")

	timestamp := time.Now().UTC().Format(timeFormat)
	hostname := os.Getenv("HOSTNAME")
	if strings.TrimSpace(hostname) == "" {
		if h, err := os.Hostname(); err == nil {
			hostname = h
		}
	}
	appName := inferAppName()
	appPID := os.Getenv("APP_PID")
	if appPID == "" {
		appPID = fmt.Sprintf("[%d] ", os.Getppid())
	}

	renderedLevel := spec.color + level + "\x1b[0m"
	formatted := fmt.Sprintf("%s %s %s%s%s: %s", timestamp, hostname, appName, appPID, renderedLevel, message)
	formatted = strings.TrimSuffix(formatted, "\n")
	paddingWidth := len(fmt.Sprintf("%s %s %s%s%s:", timestamp, hostname, appName, appPID, level)) + 1
	indent := strings.Repeat(" ", paddingWidth)
	logLine := strings.ReplaceAll(formatted, "\n", "\n"+indent)

	if os.Getenv("LOG_TO_FILE") == "true" {
		if logFile := os.Getenv("LOG_FILE"); strings.TrimSpace(logFile) != "" {
			_ = appendFile(logFile, logLine)
		}
		fmt.Println(logLine)
	}

	raw := fmt.Sprintf("%s%s%s: %s", appName, appPID, level, normalizeRawMessage(message))
	if os.Getenv("SYSLOG") == "true" {
		_ = sendSyslog(raw)
	}

	fmt.Println(logLine)

	if !levelValid {
		os.Exit(1)
	}
}
