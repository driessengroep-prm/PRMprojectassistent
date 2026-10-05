#!/usr/bin/env bash
# Zet de Projectenassistent op prm-projectassistent.driessengroep.nl. Wordt door GitHub
# Actions gedraaid, maar werkt ook vanaf een laptop met SSH-toegang tot de VM.
#
# Alleen wat de browser nodig heeft gaat mee: index.html en de avatars.
# index.html gaat als laatste, zodat de browser nooit een pagina krijgt die naar
# nog-niet-aanwezige bestanden verwijst.
set -euo pipefail
cd "$(dirname "$0")/.."

DOEL="buddy-admin@40.115.59.118:/data/caddy/apps/prm-projectassistent/"

# De vier webhook-adressen gaan hier de pagina in, uit de omgeving. Ze staan
# dus niet in de repository, die openbaar is. Is er niets meegegeven, dan
# blijft de plaatshouder staan en vat de pagina dat op als 'niet ingevuld' -
# dan plak je de adressen zelf onder Instellingen.
#
# Een ontbrekend adres is geen reden om het publiceren af te breken: dan zou
# een vergeten secret de hele tool offline halen, terwijl de pagina er prima
# zonder werkt.
WERKMAP="$(mktemp -d)"
trap 'rm -rf "$WERKMAP"' EXIT
cp index.html "$WERKMAP/index.html"

vul() {
  local plaatshouder="$1" waarde="${2:-}"
  if [ -z "$waarde" ]; then
    echo "let op: $plaatshouder is niet meegegeven; dat veld blijft leeg"
    return
  fi
  # | als scheidingsteken, want een URL zit vol met /
  sed -i "s|$plaatshouder|$waarde|g" "$WERKMAP/index.html"
}

vul __PRM_WEBHOOK__   "${PRM_WEBHOOK_URL:-}"
vul __PRM_RESULTAAT__ "${PRM_RESULTAAT_URL:-}"
vul __PRM_VERWIJDER__ "${PRM_VERWIJDER_URL:-}"
vul __PRM_LIJST__     "${PRM_LIJST_URL:-}"

rsync -az --delete \
  --include='avatars/' --include='avatars/*.png' \
  --exclude='*' \
  ./ "$DOEL"
rsync -az "$WERKMAP/index.html" "$DOEL"
echo "Gepubliceerd naar https://prm-projectassistent.driessengroep.nl"
