#!/bin/sh
# Patch Metabase JS/CSS bundles for Atomtech branding
set -e

JAR="/app/metabase.jar"
STAGING="/tmp/branding"

mkdir -p "$STAGING/frontend_client/app/dist"

# --- Patch JS bundles: replace embed badge URL, aria-label, and logo component ---
for JS_FILE in $(unzip -l "$JAR" | grep -oE 'frontend_client/app/dist/app-(public|embed-sdk|embed)\.[^ ]+\.js'); do
  echo "Patching badge in: $JS_FILE"
  unzip -p "$JAR" "$JS_FILE" > "$STAGING/$JS_FILE"

  # All three replacements in a single sed pass
  sed -i \
    -e 's|https://www.metabase.com?utm_medium=referral&utm_source=product&utm_campaign=powered_by_metabase&utm_content=${t}|https://atomtech.es/servicios/analitica-de-datos|g' \
    -e 's|"aria-label":"Metabase"|"aria-label":"Atomtech"|g' \
    -e 's|(0,l\.jsx)(c\.A,{height:32,"aria-label":"Atomtech"})|(0,l.jsxs)("span",{style:{display:"inline-flex",alignItems:"center",gap:"4px"},children:[(0,l.jsx)("img",{src:"/app/assets/img/logo.svg",alt:"Atomtech",style:{height:"22px",filter:"brightness(0) saturate(100%) invert(39%) sepia(7%) saturate(538%) hue-rotate(173deg)"}}),(0,l.jsx)("span",{style:{fontWeight:700,fontSize:"14px"},children:"Atomtech"})]})|g' \
    "$STAGING/$JS_FILE"

  # Verify each patch actually applied (sed exits 0 even on no match)
  grep -q 'atomtech.es/servicios/analitica-de-datos' "$STAGING/$JS_FILE" || \
    { echo "ERROR: Badge URL patch did not apply to $JS_FILE"; exit 1; }
  grep -q 'src:"/app/assets/img/logo.svg"' "$STAGING/$JS_FILE" || \
    { echo "ERROR: Logo component patch did not apply to $JS_FILE"; exit 1; }
  # aria-label:"Metabase" must be gone (consumed by sed 2 + 3)
  if grep -q '"aria-label":"Metabase"' "$STAGING/$JS_FILE"; then
    echo "ERROR: aria-label still says Metabase in $JS_FILE"; exit 1
  fi
done

# --- Verify at least one JS bundle was patched ---
JS_COUNT=$(unzip -l "$JAR" | grep -cE 'frontend_client/app/dist/app-(public|embed-sdk|embed)\.[^ ]+\.js' || true)
[ "$JS_COUNT" -eq 0 ] && echo "ERROR: No JS bundles matched — JAR structure may have changed" && exit 1

# --- Patch app-main CSS: nav bar logo override ---
CSS_MAIN=$(unzip -l "$JAR" | grep -oE 'frontend_client/app/dist/app-main\.[^ ]+\.css' | head -1)
echo "Patching nav CSS: $CSS_MAIN"
unzip -p "$JAR" "$CSS_MAIN" > "$STAGING/$CSS_MAIN"
cat >> "$STAGING/$CSS_MAIN" << 'CSSEOF'

[data-testid="main-logo"]{display:none!important}
[data-testid="main-logo-link"]{display:flex!important;align-items:center}
[data-testid="main-logo-link"]::after{content:"";display:block;width:32px;height:32px;background:url("/app/assets/img/logo.svg") center/contain no-repeat}
CSSEOF

# --- Update JAR with all patched files and asset files in one pass ---
cd "$STAGING"
find frontend_client -type f | xargs zip -u "$JAR"

echo "Branding patches applied successfully"
