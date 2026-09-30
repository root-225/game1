#!/usr/bin/env bash
# Render gameplay screenshots with software OpenGL: tools/shots/run.sh <out_dir>
OUT="${1:-/tmp/shots}"; mkdir -p "$OUT"
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../.."
xvfb-run -a -s "-screen 0 1280x1400x24" "$GODOT" --path . --rendering-driver opengl3 \
  --resolution 540x960 res://tools/shots/shot.tscn -- "$OUT" 2>&1 | grep -E "shot |ERROR|SCRIPT" | grep -v 'Parameter "t"'
