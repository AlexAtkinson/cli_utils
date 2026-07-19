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
* [markdown-copyright-footer](utils/markdown-copyright-footer/README.md)
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
make md-copyright-install

# Uninstall a specific utility
make dts-uninstall
make loggerx-uninstall
make et-uninstall
make rc-uninstall
make fmt-table-uninstall
make git-create-gist-uninstall
make md-copyright-uninstall

# Uninstall all utilities
make uninstall-all

# Run fmt-table regression checks
make fmt-table-self-test

# Run markdown-copyright-footer regression checks
make md-copyright-self-test
```

## GitHub Releases

GitHub Releases are published per utility from [release-utils.yml](/home/alex/git/alexatkinson/cli_utils/.github/workflows/release-utils.yml).

Each product is versioned independently with the GitOps AutoVer action in mono-repo mode:

- Tag format: `<product>_<major.minor.patch>`
- Current products: `dts`, `fmt-center`, `fmt-table`, `et`, `loggerx`, `rc`
- Every product publishes a source archive: `<product>-<version>.tar.gz` plus a matching SHA256 file
- Go products also publish native archives for Linux, macOS, and Windows: `<product>-<version>-<os>-amd64>.tar.gz`

Cross-platform binary releases are currently produced for:

- `dts`
- `fmt-center`
- `fmt-table`
- `et`
- `loggerx`
- `rc`

Operational requirements for automatic versioning:

- Changes must land on `main` through merge commits, or through squash merges that retain the PR number and use semver labels.
- Branch names should follow the action's increment rules such as `feature/...`, `enhancement/...`, `fix/...`, or `ops/...`.
After a merged pull request changes one of the utility paths above, the workflow evaluates only that utility and publishes or updates its GitHub Release.

