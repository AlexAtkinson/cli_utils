# My Linux Utilities

A monorepo for my Linux utilities.

These utilities will generally be in golang, but may vary as needed.

## Project Table of Contents

* [dts](utils/dts/README.md)
* [et](utils/et/README.md)
* [fmt-table](utils/fmt-table/README.md)
* [fmt-table-py](utils/fmt-table-py/README.md)
* [git-create-gist](utils/git-create-gist/README.md)
* [loggerx](utils/loggerx/README.md)
* [rc](utils/rc/README.md)

## Root Makefile Usage

Run commands from the repo root:

```bash
# Build all Go utilities
make go-build

# Install all Go utilities
make go-install

# Uninstall all Go utilities
make go-uninstall

# Build a specific Go utility
make dts-build
make loggerx-build
make et-build
make rc-build
make fmt-table-build
make git-create-gist-build

# Install a specific Go utility
make dts-install
make loggerx-install
make et-install
make rc-install
make fmt-table-install
make git-create-gist-install

# Uninstall a specific utility
make dts-uninstall
make loggerx-uninstall
make et-uninstall
make rc-uninstall
make fmt-table-uninstall
make git-create-gist-uninstall

# Uninstall all utilities
make uninstall-all

# Run fmt-table regression checks
make fmt-table-self-test
```

