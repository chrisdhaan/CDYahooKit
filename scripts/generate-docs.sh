#!/bin/bash
set -euo pipefail

# Regenerates docs/ from the CDYahooKit DocC catalog for GitHub Pages hosting.
#
# docs/superpowers/ is gitignored local planning material, not DocC output — this script's
# --output-path clears the whole docs/ directory, so it will delete those local files too if
# they're present. That's expected: they're never committed, so there's nothing to lose from
# git's perspective. Committing the regenerated docs/ output itself is a separate, deliberate
# step (done on its own, tied to a release — see the sibling frameworks' "Regenerate DocC
# documentation for vX.Y.Z" commits) and should not be bundled into feature-branch PRs.

swift package --disable-sandbox generate-documentation \
    --target CDYahooKit \
    --output-path docs \
    --transform-for-static-hosting \
    --hosting-base-path CDYahooKit

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
