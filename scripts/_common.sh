#!/bin/bash

# Common output functions for Project One-Hour scripts
# This file contains shared output functions used across multiple scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
print_header() {
    echo
    echo "=================================================================="
    echo "$1"
    echo "=================================================================="
    echo
}

# Print section
print_section() {
    echo
    echo "--- $1 ---"
    echo
}

# End of common output functions
