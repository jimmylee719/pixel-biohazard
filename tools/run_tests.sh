#!/bin/zsh
# 執行行為測試，最多等 TIMEOUT 秒（腳本有語法錯誤時 Godot 不會自己結束，避免卡住）。
# 用法：tools/run_tests.sh   結束代碼 0 = 全部通過
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
TIMEOUT=${TIMEOUT:-400}
LOG=${LOG:-/tmp/pixel_biohazard_test.log}
cd "$(dirname "$0")/.."
$GODOT --headless --path . res://tools/tests/prototype_test.tscn > "$LOG" 2>&1 &
PID=$!
for i in $(seq 1 $TIMEOUT); do
	sleep 1
	kill -0 $PID 2>/dev/null || break
done
if kill -0 $PID 2>/dev/null; then
	kill $PID
	echo "TIMEOUT（可能是腳本語法錯誤，看 $LOG）"
	grep -E "SCRIPT ERROR|Parse Error" -A1 "$LOG" | head -20
	exit 2
fi
wait $PID
CODE=$?
grep -E "  FAIL|PASSED|FAILED|SCRIPT ERROR" "$LOG"
echo "PASS: $(grep -c '  PASS' "$LOG")"
exit $CODE
