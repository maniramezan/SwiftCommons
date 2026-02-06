#!/bin/bash
set -euo pipefail

source_path="${1:-}"
if [ -z "$source_path" ]; then
    echo "Missing documentation path"
    exit 1
fi

docc_site_dir="/tmp/docc-site"

mkdir -p "$docc_site_dir"
if [ -f "$source_path/index.html" ]; then
    cp -R "$source_path"/. "$docc_site_dir"/
    exit 0
fi

if [ -d "$source_path" ] && [ "${source_path##*.}" = "doccarchive" ]; then
    cp -R "$source_path"/. "$docc_site_dir"/
    exit 0
fi

echo "Unsupported documentation path: $source_path"
exit 1
