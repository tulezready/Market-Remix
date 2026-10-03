#!/bin/sh
# Copies only the public website into dist/ for Cloudflare Pages.
# Cloudflare settings: Build command `sh scripts/build-site.sh`, Build output directory `dist`.
# Internal folders (docs/, db/, design-system/, .claude/, .github/) are never published.
set -eu
cd "$(dirname "$0")/.."
rm -rf dist
mkdir -p dist/photos dist/tools

cp ./*.html site.css site.js shop-data.js config.js logo-96.png logo.svg _headers dist/
[ -f data.json ] && cp data.json dist/
[ -f _redirects ] && cp _redirects dist/

# photos: images only (no README or working files)
find photos -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) |
  while read -r f; do mkdir -p "dist/$(dirname "$f")"; cp "$f" "dist/$f"; done

# district officers' intake tool and printable form
cp tools/intake.html tools/sme-form.pdf dist/tools/

# safety check: nothing internal slipped through
if find dist -name '*.sql' -o -name '*.md' -o -name '*.py' | grep -q .; then
  echo "Build stopped: an internal file (.sql, .md or .py) is in dist/" >&2; exit 1
fi
echo "Built dist/: $(find dist -type f | wc -l) files, $(du -sh dist | cut -f1)"
