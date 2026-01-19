#!/usr/bin/env bash
set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/scripts/_common.sh"

print_header "WHPH - Test Suite"

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
        cd "$PROJECT_ROOT/src"
        fvm flutter test || {
            print_error "Flutter tests failed"
            exit 1
        }
        print_success "Flutter tests passed"
        cd "$PROJECT_ROOT"
    elif command -v flutter &>/dev/null; then
        print_section "🔷 Running Flutter Tests"
        cd "$PROJECT_ROOT/src"
        flutter test || {
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
    INCLUDE_DIR="$PROJECT_ROOT/src/linux"

    # Find all C++ test files
    TEST_FILES=$(find "$PROJECT_ROOT/src/test" -name "*_test.cpp")

    if [ -z "$TEST_FILES" ]; then
        print_warning "No C++ test files found."
    else
        for SOURCE in $TEST_FILES; do
            TEST_NAME=$(basename "$SOURCE" .cpp)
            BINARY="${SOURCE%.*}"
            BASE_NAME=$(basename "$SOURCE" _test.cpp)

            # Attempt to find the corresponding source file in src/linux
            NATIVE_SRC=$(find "$PROJECT_ROOT/src/linux" -name "${BASE_NAME}.cpp" | head -1)

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
