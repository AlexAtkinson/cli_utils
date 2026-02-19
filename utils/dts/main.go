package main

import (
	"flag"
	"fmt"
	"os"
	"time"
)

const (
	formatDefault = "2006-01-02T15:04:05.000Z"
	formatSecond  = "2006-01-02T15:04:05Z"
	formatFile    = "2006-01-02T15-04-05Z"
)

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(), "dts - print UTC timestamps in multiple formats\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Usage:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  dts [options]\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -f, --file      Print filename-safe UTC format: YYYY-MM-DDTHH-MM-SSZ\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -s, --seconds   Print second precision UTC format: YYYY-MM-DDTHH:MM:SSZ\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  -h, --help      Show this help and exit\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Default output:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  UTC timestamp with millisecond precision: YYYY-MM-DDTHH:MM:SS.mmmZ\n\n")
	fmt.Fprintf(flag.CommandLine.Output(), "Examples:\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  dts\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  dts -s\n")
	fmt.Fprintf(flag.CommandLine.Output(), "  dts --file\n")
}

func normalizeArgs(args []string) []string {
	normalized := make([]string, 0, len(args))
	for _, arg := range args {
		switch arg {
		case "--file":
			normalized = append(normalized, "-f")
		case "--seconds":
			normalized = append(normalized, "-s")
		case "--help":
			normalized = append(normalized, "-h")
		default:
			normalized = append(normalized, arg)
		}
	}
	return normalized
}

func main() {
	flag.CommandLine.SetOutput(os.Stdout)
	flag.CommandLine.Usage = usage

	fileFormat := flag.Bool("f", false, "print filename-safe UTC format")
	secondPrecision := flag.Bool("s", false, "print second precision UTC format")
	help := flag.Bool("h", false, "show help")

	os.Args = append([]string{os.Args[0]}, normalizeArgs(os.Args[1:])...)
	flag.Parse()

	if *help {
		usage()
		return
	}

	if *fileFormat && *secondPrecision {
		fmt.Fprintln(os.Stderr, "error: use only one of -f/--file or -s/--seconds")
		os.Exit(2)
	}

	if flag.NArg() > 0 {
		fmt.Fprintln(os.Stderr, "error: this command does not accept positional arguments")
		fmt.Fprintln(os.Stderr, "try: dts --help")
		os.Exit(2)
	}

	now := time.Now().UTC()
	format := formatDefault
	if *fileFormat {
		format = formatFile
	} else if *secondPrecision {
		format = formatSecond
	}

	fmt.Println(now.Format(format))
}
