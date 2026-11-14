#!/usr/bin/env bash
# Runs the GUT suite headless. Usage: ./run_tests.sh [res://tests/path/test_x.gd]
# Exit code 0 only when GUT reports that all tests passed and the engine reported
# no script errors or leaked resources.
GODOT="${GODOT:-/d/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
EXTRA=()
if [ -n "$1" ]; then EXTRA=("-gselect=$(basename "$1")"); fi
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json "${EXTRA[@]}" 2>&1)
CODE=$?
echo "$OUT"
if [ $CODE -ne 0 ] || ! echo "$OUT" | grep -q "All tests passed"; then exit 1; fi
if echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|resources still in use"; then exit 1; fi
exit 0
