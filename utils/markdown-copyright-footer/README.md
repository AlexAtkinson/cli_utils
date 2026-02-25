# markdown-copyright-footer

`md-add-copyright` normalizes markdown copyright footer blocks and appends a canonical footer when needed.

## Usage

```bash
md-add-copyright [--check] [--verbose] [--quiet] [--json] [--detect-year] [--update] [--year <yyyy>] [--owner <name>] [--path <dir> | --file <file>]
```

## Common examples

```bash
# Scan from current directory (prompts first)
md-add-copyright

# Check mode (no writes)
md-add-copyright --check --path docs

# Force update with detected year
md-add-copyright --detect-year --owner "Acme Corp" --path docs --update

# Single file
md-add-copyright --file docs/README.md --owner "Acme Corp" --year 2026 --update
```

## Make targets

From this directory:

```bash
make self-test
make install
make uninstall
```

## Direct scripts

```bash
./self-test.sh
./install.sh
./uninstall.sh
```

## Manual page

After install:

```bash
man md-add-copyright
```
