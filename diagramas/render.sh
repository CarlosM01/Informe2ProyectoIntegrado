#!/usr/bin/env bash
# Renders every PlantUML source under diagramas/<carpeta>/ to PNG in figuras/<carpeta>/.
# Uses a local `plantuml` when available; otherwise the pinned Docker image.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
image="plantuml/plantuml:1.2026.9"

render() { # $1 = folder name shared by diagramas/ and figuras/
  local src="$root/diagramas/$1" out="$root/figuras/$1"
  mkdir -p "$out"
  if command -v plantuml >/dev/null 2>&1; then
    plantuml -tpng -o "$out" "$src"/*.puml
  else
    docker run --rm -u "$(id -u):$(id -g)" -v "$root:/work" "$image" \
      -tpng -o "/work/figuras/$1" "/work/diagramas/$1/*.puml"
  fi
  echo "ok  $1"
}

for dir in "$root"/diagramas/*/; do
  name="$(basename "$dir")"
  [[ "$name" == _* ]] && continue   # _comun holds includes, not figures
  render "$name"
done
