#!/bin/bash

# Script to clean the debug database for WHPH
# Usage: ./src/scripts/clean_db.sh

DB_PATH="$HOME/.local/share/whph/debug_whph"

if [ -d "$DB_PATH" ]; then
    echo "This will delete the debug database at: $DB_PATH"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DB_PATH"
        echo "Debug database removed successfully."
    else
        echo "Operation cancelled."
    fi
else
    echo "Debug database not found at: $DB_PATH"
fi
