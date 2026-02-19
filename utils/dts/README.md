# dts

A small UTC timestamp CLI implemented in Go.

## Output modes

- Default: `YYYY-MM-DDTHH:MM:SS.mmmZ`
- `-s` / `--seconds`: `YYYY-MM-DDTHH:MM:SSZ`
- `-f` / `--file`: `YYYY-MM-DDTHH-MM-SSZ`

## Usage

```bash
dts [options]
```

### Options

- `-f`, `--file` filename-safe UTC format
- `-s`, `--seconds` second precision UTC format
- `-h`, `--help` show help and exit

## Install

From this directory:

```bash
chmod +x install.sh
./install.sh
```

## Uninstall

From this directory:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Manual page

After installation, open:

```bash
man dts
```
