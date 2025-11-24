#!/usr/bin/env bash
# Run all plugin tests for Quickstop marketplace

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

echo "======================================"
echo "Running Quickstop Plugin Tests"
echo "======================================"
echo ""

# Track results
TOTAL=0
PASSED=0
FAILED=0
FAILED_TESTS=()

# Find and run all test files
for plugin_dir in "$PLUGINS_DIR"/*; do
    if [ -d "$plugin_dir" ]; then
        plugin_name=$(basename "$plugin_dir")
        test_file="$plugin_dir/test_${plugin_name}.py"

        if [ -f "$test_file" ]; then
            echo "--------------------------------------"
            echo "Testing: $plugin_name"
            echo "--------------------------------------"

            TOTAL=$((TOTAL + 1))

            if python3 "$test_file"; then
                PASSED=$((PASSED + 1))
                echo "✓ $plugin_name tests PASSED"
            else
                FAILED=$((FAILED + 1))
                FAILED_TESTS+=("$plugin_name")
                echo "❌ $plugin_name tests FAILED"
            fi
            echo ""
        fi
    fi
done

# Summary
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Total plugins tested: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Failed plugins:"
    for failed in "${FAILED_TESTS[@]}"; do
        echo "  - $failed"
    done
    exit 1
fi

echo ""
echo "All tests passed! ✓"
exit 0
