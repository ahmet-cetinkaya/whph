#!/usr/bin/env bash
set -e

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../packages/acore-scripts/src/logger.sh"

# Get the project root directory
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

acore_log_header "WHPH - Test Suite"

# Kill any running whph processes before testing
acore_log_info "Killing any running whph processes..."
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
        acore_log_section "Running Flutter Tests"
        cd "$PROJECT_ROOT/src"
        fvm flutter test || {
            acore_log_error "Flutter tests failed"
            exit 1
        }
        acore_log_success "Flutter tests passed"
        cd "$PROJECT_ROOT"
    elif command -v flutter &>/dev/null; then
        acore_log_section "Running Flutter Tests"
        cd "$PROJECT_ROOT/src"
        flutter test || {
            acore_log_error "Flutter tests failed"
            exit 1
        }
        acore_log_success "Flutter tests passed"
        cd "$PROJECT_ROOT"
    else
        acore_log_warning "Flutter/FVM command not found, skipping flutter tests."
    fi
fi

# 2. Run C++ Native Tests
if [ "$SKIP_CPP" = false ]; then
    acore_log_section "Running Linux C++ Tests"
    INCLUDE_DIR="$PROJECT_ROOT/src/linux"

    # Define common source files needed for linking
    # We compile these once or include them in the g++ command
    COMMON_SOURCES="$PROJECT_ROOT/src/linux/window_utils.cpp $PROJECT_ROOT/src/linux/window_detector.cpp $PROJECT_ROOT/src/linux/window_detector_x11.cpp $PROJECT_ROOT/src/linux/window_detector_wayland.cpp $PROJECT_ROOT/src/linux/window_detector_fallback.cpp"

    # Find all C++ test files in src/test/linux
    # If src/test/linux doesn't exist, try src/test for backward compatibility or general tests
    TEST_DIR="$PROJECT_ROOT/src/test/linux"
    if [ ! -d "$TEST_DIR" ]; then
        TEST_DIR="$PROJECT_ROOT/src/test"
    fi

    TEST_FILES=$(find "$TEST_DIR" -name "*_test.cpp")

    if [ -z "$TEST_FILES" ]; then
        acore_log_warning "No C++ test files found in $TEST_DIR."
    else
        for SOURCE in $TEST_FILES; do
            TEST_NAME=$(basename "$SOURCE" .cpp)
            BINARY="${SOURCE%.*}"

            acore_log_info "Running $TEST_NAME..."
            acore_log_info "Compiling $BINARY..."

            # Compile with all sources to ensure symbols are resolved
            # We use pkg-config for glib-2.0 which is used by window_utils/detector
            # shellcheck disable=SC2046
            if g++ -g -o "$BINARY" \
                "$SOURCE" \
                $COMMON_SOURCES \
                $(pkg-config --cflags --libs glib-2.0) \
                -I "$INCLUDE_DIR"; then

                acore_log_info "Executing $BINARY..."
                if "$BINARY"; then
                    acore_log_success "$TEST_NAME passed"
                else
                    acore_log_error "C++ tests failed for $TEST_NAME"
                    exit 1
                fi

                # Cleanup binary
                rm -f "$BINARY"
            else
                acore_log_error "C++ compilation failed for $TEST_NAME"
                exit 1
            fi
        done
    fi
fi

acore_log_header "All tests completed successfully!"
