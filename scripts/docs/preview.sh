#!/bin/bash
set -euo pipefail

docc_site_dir="/tmp/docc-site"
port="${PORT:-8000}"

if [ ! -d "$docc_site_dir" ]; then
    echo "No DocC site at $docc_site_dir"
    exit 1
fi

echo "Serving $docc_site_dir at http://127.0.0.1:${port}"
python -m http.server "$port" --directory "$docc_site_dir"
