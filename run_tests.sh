#!/usr/bin/env bash
# Runs the GUT suite headless.
#   ./run_tests.sh                      fast suite: tests/unit and tests/integration (~2 min)
#   ./run_tests.sh --all                full suite: also tests/slow (~5.5 min; CI and releases)
#   ./run_tests.sh res://tests/x/test_y.gd   only that script (any folder)
# Exit code 0 only when GUT reports that all tests passed and the engine reported
# no script errors or leaked resources.
GODOT="${GODOT:-/d/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
CONFIG=.gutconfig.json
EXTRA=()
for arg in "$@"; do
	if [ "$arg" = "--all" ]; then
		CONFIG=.gutconfig_full.json
	else
		CONFIG=.gutconfig_full.json # a named script may live in tests/slow
		EXTRA+=("-gselect=$(basename "$arg")")
	fi
done
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=$CONFIG "${EXTRA[@]}" 2>&1)
CODE=$?
echo "$OUT"
if [ $CODE -ne 0 ] || ! echo "$OUT" | grep -q "All tests passed"; then exit 1; fi
if echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|resources still in use"; then exit 1; fi
exit 0
