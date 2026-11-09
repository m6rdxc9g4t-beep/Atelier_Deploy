#!/usr/bin/env bash
# Kit de démo « Studio Garance » : sudo ./demo/charger.sh [charger|retirer|etat] [--apps viz,projets]
# Voir demo/README.md.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" -eq 0 ] || { echo "Lance-le avec sudo (il écrit dans data/)." >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 est nécessaire (apt install python3)." >&2; exit 1; }
exec python3 demo/kit.py "$@"
