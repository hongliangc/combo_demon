#!/bin/bash
# ============================================================
# Combo Demon — GUT 测试运行脚本
# ============================================================
# 用法:
#   bash test/run_tests.sh              # 运行全部测试
#   bash test/run_tests.sh unit         # 仅运行单元测试
#   bash test/run_tests.sh integration  # 仅运行集成测试
#   bash test/run_tests.sh <文件名>      # 运行指定测试文件
#
# 示例:
#   bash test/run_tests.sh test_health_component
#   bash test/run_tests.sh test_state_machine
# ============================================================

# Godot 可执行文件路径（根据本地环境调整）
GODOT="${GODOT_PATH:-D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe}"

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# GUT 命令行入口
GUT_SCRIPT="addons/gut/gut_cmdln.gd"

# 检查 Godot 可执行文件
if [ ! -f "$GODOT" ]; then
    echo "ERROR: Godot not found at: $GODOT"
    echo "Set GODOT_PATH environment variable or edit this script."
    exit 1
fi

# 检查 GUT 安装
if [ ! -f "$PROJECT_DIR/$GUT_SCRIPT" ]; then
    echo "ERROR: GUT not installed. Run: bash test/install_gut.sh"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

# 解析参数
case "${1:-all}" in
    all)
        echo "=== Running ALL tests ==="
        "$GODOT" --headless -s "$GUT_SCRIPT" \
            -gdir=res://test/unit,res://test/integration \
            -ginclude_subdirs \
            -gexit
        ;;
    unit)
        echo "=== Running UNIT tests ==="
        "$GODOT" --headless -s "$GUT_SCRIPT" \
            -gdir=res://test/unit \
            -ginclude_subdirs \
            -gexit
        ;;
    integration)
        echo "=== Running INTEGRATION tests ==="
        "$GODOT" --headless -s "$GUT_SCRIPT" \
            -gdir=res://test/integration \
            -ginclude_subdirs \
            -gexit
        ;;
    *)
        # 按文件名匹配（支持带或不带 test_ 前缀）
        FILE="$1"
        # 去掉 .gd 后缀（如果有）
        FILE="${FILE%.gd}"
        # 添加 test_ 前缀（如果没有）
        [[ "$FILE" != test_* ]] && FILE="test_${FILE}"

        echo "=== Running: ${FILE}.gd ==="
        "$GODOT" --headless -s "$GUT_SCRIPT" \
            -gdir=res://test/unit,res://test/integration \
            -ginclude_subdirs \
            -gselect="${FILE}.gd" \
            -gexit
        ;;
esac

EXIT_CODE=$?
echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "=== TESTS PASSED ==="
else
    echo "=== TESTS FAILED (exit code: $EXIT_CODE) ==="
fi
exit $EXIT_CODE
