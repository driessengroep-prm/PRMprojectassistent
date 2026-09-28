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

rsync -az --delete \
  --include='avatars/' --include='avatars/*.png' \
  --exclude='*' \
  ./ "$DOEL"
rsync -az index.html "$DOEL"
echo "Gepubliceerd naar https://prm-projectassistent.driessengroep.nl"
