# fmt-table

A command-line utility to generate formatted tables in the terminal.

## Installation

1. Navigate to the `cli_utils/fmt-table` directory:

   ```bash
   cd cli_utils/fmt-table
   ```

2. Run the installation script:

   ```bash
   ./install.sh
   ```

3. If the chosen installation directory is not in your `PATH`, add it in your shell config.

## Uninstallation

From the `cli_utils/utils/fmt-table-py` directory:

```bash
./uninstall.sh
```

## Usage

```bash
fmt-table [-h] [-t TITLE_ROW] [-r ROW] [-w WIDTH] [-f] [-e] [-a] [-c] [-n] [-m] [-b1] [-s] [-F]
```

By default, `fmt-table` writes table output to standard output.

In an interactive terminal, append-style sequential runs redraw the prior table region in place (instead of appending duplicate full-table output).

If a normal shell prompt/input cycle occurs between invocations, `fmt-table` prints a fresh table snapshot for that call.

Use `-s`/`--screen` to render in the interactive `curses` screen mode.

- `q`: quit
- `j` / `k` or arrow keys: scroll
- `PageUp` / `PageDown`: page scroll

When output is redirected or piped, it prints plain text instead.

## Arguments

- `-h`, `--help`: Show the help message and exit.
- `-t TITLE_ROW`, `--title-row TITLE_ROW`: Comma-separated values for the table title row.
- `-r ROW`, `--row ROW`: Comma-separated values for a content row (repeatable).
- `-w WIDTH`, `--width WIDTH`: Width strategy (`dynamic`, `equal`, `full`, or numeric width).
- `-f`, `--frame`: Wrap table in a frame border.
- `-e`, `--end`: Print a closing frame after the last row.
- `-a`, `--append`: Skip top border when appending framed output.
- `-c`, `--clear-state`: Clear persisted state.
- `-n`, `--new-session`: Ignore previous persisted state for this run.
- `-m`, `--markdown`: Set session output format to Markdown when creating a new table session.
- `-b1`, `--bold-first-column`: Bold first column in data rows (TTY/curses view).
- `-s`, `--screen`: Render in interactive curses screen mode (TTY only).
- `-F`, `--force`: Accepted for compatibility; no prompt is used.

## State Persistence

`fmt-table` persists the latest session state to:

`~/.cache/fmt-table/state.json`

This includes title row, content rows, width strategy, and frame options.

Output format is also session state:

- The session format is chosen when the session is created.
- `-m` only affects new sessions (`-n` or first run with no existing session state).
- After session creation, subsequent rows keep the established format regardless of `-m`.

- Use `-n/--new-session` to ignore previous state on a run.
- Use `-c/--clear-state` to remove persisted state.

## Examples

```bash
# Simple table
fmt-table -t "Name,Age" -r "Alice,30" -r "Bob,24"

# Full frame
fmt-table -t "Name,Age,City" -r "Alice,30,New York" -r "Bob,24,London" -f

# Custom width
fmt-table -t "Product,Price" -r "Laptop,1200" -r "Mouse,25" -w 60

# Full-width framing
fmt-table -t "Task,Status,Progress" -r "Coding,In Progress,75%" -w full -f

# Markdown output
fmt-table -t "Header A,Header B" -r "Data 1,Data 2" -m

# Reuse prior state and add rows
fmt-table -t "Fruit,Color" -r "Apple,Red" -f
fmt-table -r "Banana,Yellow"
fmt-table -r "Grape,Purple" -e

# Clear persisted state
fmt-table -c
```

## Quick Self-Test

Run the built-in regression check script:

```bash
./self-test.sh
```

It validates help output, Markdown rendering, framed ASCII output, and state persistence behavior.
