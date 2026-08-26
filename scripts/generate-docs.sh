#!/bin/bash
set -euo pipefail

# Regenerates docs/ from the CDYahooKit DocC catalog for GitHub Pages hosting.

swift package --disable-sandbox generate-documentation \
    --target CDYahooKit \
    --output-path docs \
    --transform-for-static-hosting \
    --hosting-base-path CDYahooKit

# generate-documentation's --output-path clears the whole docs/ directory, which also holds
# this repo's committed docs/superpowers/ (specs and implementation plans) — restore it from
# git so this script never silently deletes tracked, non-DocC content.
git checkout -- docs/superpowers

touch docs/.nojekyll

cat > docs/index.html <<'EOF'
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="refresh" content="0; url=documentation/cdyahookit/" />
  </head>
  <body></body>
</html>
EOF

cat > docs/404.html <<'EOF'
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="refresh" content="0; url=/CDYahooKit/documentation/cdyahookit/" />
  </head>
  <body></body>
</html>
EOF

echo "Documentation generated at docs/"
