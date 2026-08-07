#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$PROJECT_DIR/bin/Release/net10.0/linux-x64"
APP="$OUT/DeskAlert"
TARBALL="$PROJECT_DIR/DeskAlert-linux-x64.tar.gz"

QT_DIR="${QT_DIR:-}"
if [[ -z "$QT_DIR" ]]; then
  QT_DIR="$(sed -n 's/.*<QtDir[^>]*>\(.*\)<\/QtDir>.*/\1/p' "$PROJECT_DIR/DeskAlert.csproj")"
fi
QT_DIR="${QT_DIR%/}"
if [[ -z "$QT_DIR" || ! -d "$QT_DIR/lib" ]]; then
  echo "error: Qt installation not found. Set QT_DIR or the <QtDir> in DeskAlert.csproj." >&2
  exit 1
fi

echo "Publishing"
dotnet publish "$PROJECT_DIR" -c Release -r linux-x64 -p:QtDir="$QT_DIR/"

echo "Bundling Qt runtime libs"
cp -a "$QT_DIR"/lib/libQt6*.so* "$OUT/lib/" 2>/dev/null || true

echo "Bundling ffmpeg media backend"
for lib in libavcodec libavformat libavutil libswresample libswscale; do
  for f in "$QT_DIR"/lib/"$lib".so.*.*.*; do
    if [[ -f "$f" ]]; then
      cp -a "$f" "$OUT/lib/"
    fi
  done
done

echo "Bundling QML modules and plugins"
mkdir -p "$OUT/qml" "$OUT/plugins"
cp -a "$QT_DIR"/qml/. "$OUT/qml/"
cp -a "$QT_DIR"/plugins/. "$OUT/plugins/"

echo "Patching RUNPATH to \$ORIGIN/lib"
python3 "$SCRIPT_DIR/patch_runpath.py" "$APP" '$ORIGIN/lib'

echo "Writing qt.conf"
printf '[Paths]\nPrefix = .\n' > "$OUT/qt.conf"

echo "Removing redundant artifacts"
rm -rf "$OUT/desk_alert" "$OUT/bin" "$OUT/publish"

echo "Packaging"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -a "$OUT" "$STAGE/DeskAlert"
tar -czf "$TARBALL" -C "$STAGE" DeskAlert

echo "Done: $TARBALL"
