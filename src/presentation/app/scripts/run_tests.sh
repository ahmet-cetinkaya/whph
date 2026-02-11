#!/usr/bin/env bash
set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
FLUTTER_PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/scripts/_common.sh"

print_header "WHPH - Test Suite"

# Kill any running whph processes before testing
print_info "Killing any running whph processes..."
pkill -9 whph 2>/dev/null || true

# Parse arguments
SKIP_FLUTTER=false
SKIP_CPP=false

for arg in "$@"; do
    case $arg in
    --skip-flutter)
        SKIP_FLUTTER=true
        ;;
    --skip-cpp | --skip-native)
        SKIP_CPP=true
        ;;
    esac
done

# 1. Run Flutter Tests
if [ "$SKIP_FLUTTER" = false ]; then
    if command -v fvm &>/dev/null; then
        print_section "🔷 Running Flutter Tests"
        cd "$FLUTTER_PROJECT_ROOT"
        # Run unit tests and host-safe integration tests
        # We exclude today_page_performance_test.dart as it requires a real device/emulator
        fvm flutter test "$PROJECT_ROOT/tests/unit_tests" $(find "$PROJECT_ROOT/tests/integration_tests" -name "*_test.dart" ! -name "today_page_performance_test.dart") || {
            print_error "Flutter tests failed"
            exit 1
        }
        print_success "Flutter tests passed"
        cd "$PROJECT_ROOT"
    elif command -v flutter &>/dev/null; then
        print_section "🔷 Running Flutter Tests"
        cd "$FLUTTER_PROJECT_ROOT"
        flutter test "$PROJECT_ROOT/tests/unit_tests" $(find "$PROJECT_ROOT/tests/integration_tests" -name "*_test.dart" ! -name "today_page_performance_test.dart") || {
            print_error "Flutter tests failed"
            exit 1
        }
        print_success "Flutter tests passed"
        cd "$PROJECT_ROOT"
    else
        print_warning "Flutter/FVM command not found, skipping flutter tests."
    fi
fi

# 2. Run C++ Native Tests
if [ "$SKIP_CPP" = false ]; then
    print_section "🟦 Running Linux C++ Tests"
    INCLUDE_DIR="$FLUTTER_PROJECT_ROOT/linux"

    # Find all C++ test files in the entire tests directory
    TEST_FILES=$(find "$PROJECT_ROOT/tests" -name "*_test.cpp")

    if [ -z "$TEST_FILES" ]; then
        print_warning "No C++ test files found."
    else
        for SOURCE in $TEST_FILES; do
            TEST_NAME=$(basename "$SOURCE" .cpp)
            BINARY="${SOURCE%.*}"
            BASE_NAME=$(basename "$SOURCE" _test.cpp)

            # Attempt to find the corresponding source file in linux directory
            NATIVE_SRC=$(find "$FLUTTER_PROJECT_ROOT/linux" -name "${BASE_NAME}.cpp" | head -1)

            if [ -n "$NATIVE_SRC" ]; then
                print_info "Running $TEST_NAME..."
                print_info "Compiling $BINARY..."
                # shellcheck disable=SC2046
                g++ -o "$BINARY" \
                    "$SOURCE" \
                    "$NATIVE_SRC" \
                    $(pkg-config --cflags --libs glib-2.0) \
                    -I "$INCLUDE_DIR" || {
                    print_error "C++ compilation failed for $TEST_NAME"
                    exit 1
                }

                print_info "Executing $BINARY..."
                "$BINARY" || {
                    print_error "C++ tests failed for $TEST_NAME"
                    exit 1
                }
                print_success "$TEST_NAME passed"
            else
                print_warning "Could not find source file for $SOURCE, skipping."
            fi
        done
    fi
fi

print_header "All tests completed successfully!"
