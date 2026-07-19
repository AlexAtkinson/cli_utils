#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 4 || $# -gt 8 ]]; then
     echo "usage: $0 <product-name> <product-path> <version> <output-dir> [binary-name goos goarch binary-path]" >&2
    exit 64
fi

product_name="$1"
product_path="$2"
version="$3"
output_dir="$4"
binary_name="${5:-}"
goos="${6:-}"
goarch="${7:-}"
binary_path="${8:-}"

repo_root="$(git rev-parse --show-toplevel)"
temp_dir="$(mktemp -d)"
archive_name="${product_name}-${version}.tar.gz"
checksum_name="${product_name}-${version}-SHA256SUMS.txt"
stage_name="${product_name}-${version}"
if [[ -n "$binary_name" ]]; then
     stage_name="${product_name}-${version}-${goos}-${goarch}"
     archive_name="${stage_name}.tar.gz"
     checksum_name="${stage_name}-SHA256SUMS.txt"
fi
stage_dir="${temp_dir}/${stage_name}"
source_dir="${temp_dir}/source"

cleanup() {
    rm -rf "$temp_dir"
}

trap cleanup EXIT

mkdir -p "$output_dir" "$source_dir" "$stage_dir"

if [[ -z "$binary_name" ]]; then
     git -C "$repo_root" archive --format=tar HEAD "$product_path" | tar -xf - -C "$source_dir"

     if [[ ! -d "${source_dir}/${product_path}" ]]; then
     	 echo "expected archived product path '${product_path}' was not found" >&2
     	 exit 1
     fi

     cp -a "${source_dir}/${product_path}/." "$stage_dir/"

     find "$stage_dir" \
     	 \( -type d \( -name target -o -name __pycache__ -o -name .pytest_cache \) -prune \) \
     	 -exec rm -rf {} +

     find "$stage_dir" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
else
     if [[ -z "$goos" || -z "$goarch" || -z "$binary_path" ]]; then
     	 echo "binary packaging requires goos, goarch, and binary_path" >&2
     	 exit 64
     fi

     if [[ ! -f "$binary_path" ]]; then
     	 echo "binary path not found: $binary_path" >&2
     	 exit 1
     fi

     binary_target="$stage_dir/$binary_name"
     if [[ "$goos" == "windows" ]]; then
     	 binary_target+=".exe"
     fi

     cp "$binary_path" "$binary_target"
fi

tar -czf "${output_dir}/${archive_name}" -C "$temp_dir" "$stage_name"

(
    cd "$output_dir"
    sha256sum "$archive_name" > "$checksum_name"
)

echo "archive=${output_dir}/${archive_name}"
echo "checksum=${output_dir}/${checksum_name}"