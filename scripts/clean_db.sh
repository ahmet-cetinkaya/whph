#!/bin/bash

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Script to clean the debug database for WHPH
# Usage: ./scripts/clean_db.sh

DB_PATH="$HOME/.local/share/whph/debug_whph"

if [ -d "$DB_PATH" ]; then
    acore_log_info "This will delete the debug database at: $DB_PATH"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DB_PATH"
        acore_log_success "Debug database removed successfully."
    else
        acore_log_warning "Operation cancelled."
    fi
else
    acore_log_warning "Debug database not found at: $DB_PATH"
fi
