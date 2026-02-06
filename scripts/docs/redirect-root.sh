#!/bin/bash
set -euo pipefail

module_name="${1:-SwiftCommons}"
module_slug="$(printf '%s' "$module_name" | tr '[:upper:]' '[:lower:]')"

docc_site_dir="/tmp/docc-site"
index_path="${docc_site_dir}/index.html"

cat > "$index_path" <<EOF
<!doctype html>
<html lang="en-US">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=documentation/${module_slug}/">
    <title>Redirecting…</title>
  </head>
  <body>
    <script>
      window.location.replace("documentation/${module_slug}/");
    </script>
    <p>
      Redirecting to
      <a href="documentation/${module_slug}/">documentation/${module_slug}/</a>…
    </p>
  </body>
</html>
EOF
