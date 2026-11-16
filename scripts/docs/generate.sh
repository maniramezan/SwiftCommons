#!/bin/bash
set -euo pipefail

repo_name="${1:-SwiftCommons}"
targets=(SwiftCommons SwiftCommonsSpeech SwiftCommonsTestSupport)

docc_output_dir="/tmp/docc"

mkdir -p "$docc_output_dir"

target_args=()
for target in "${targets[@]}"; do
    target_args+=(--target "$target")
done

# Build with every trait so the docs cover the whole API (SwiftData is default; CSV is opt-in).
# Combined documentation puts all three modules in one site.
swift package --enable-all-traits --allow-writing-to-directory "$docc_output_dir" \
    generate-documentation \
    "${target_args[@]}" \
    --enable-experimental-combined-documentation \
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
