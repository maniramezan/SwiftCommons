#!/bin/bash
set -euo pipefail

repo_name="${1:-SwiftCommons}"
target_name="SwiftCommons"

docc_output_dir="/tmp/docc"

mkdir -p "$docc_output_dir"

swift package --allow-writing-to-directory "$docc_output_dir" \
    generate-documentation \
    --target "$target_name" \
    --output-path "$docc_output_dir" \
    --transform-for-static-hosting \
    --hosting-base-path "/${repo_name}" 1>&2

archive_path="$(find "$docc_output_dir" -maxdepth 1 -name '*.doccarchive' -type d | head -n 1)"
if [ -n "$archive_path" ]; then
    printf '%s\n' "$archive_path"
    exit 0
fi

if [ -f "$docc_output_dir/index.html" ]; then
    printf '%s\n' "$docc_output_dir"
    exit 0
fi

echo "No .doccarchive or static site produced"
exit 1
