#!/usr/bin/env bash

# Git helper functions for CI/CD workflows
# Provides reusable utilities for common git operations

# Pull with rebase, falling back to merge if rebase fails
# Handles unstaged/untracked changes by stashing them temporarily
#
# Usage:
#   git_pull_with_fallback [filter_pattern]
#
# Arguments:
#   filter_pattern - Optional grep pattern to exclude from stash check
#                    (e.g., "packaging/aur" to ignore changes in that path)
#
# Example:
#   git_pull_with_fallback "packaging/aur"
#   git_pull_with_fallback  # No filter, stash all changes
git_pull_with_fallback() {
    local filter_pattern="$1"

    # Handle any unstaged changes before pulling (including untracked files)
    if [[ -n "$filter_pattern" ]]; then
        if [[ -n "$(git status --porcelain | grep -v "$filter_pattern")" ]]; then
            echo "⚠️ Found unstaged/untracked changes, stashing before pull..."
            git stash push -u -m "Temporary stash before rebase" || true
        fi
    else
        if [[ -n "$(git status --porcelain)" ]]; then
            echo "⚠️ Found unstaged/untracked changes, stashing before pull..."
            git stash push -u -m "Temporary stash before rebase" || true
        fi
    fi

    # Pull with rebase, fallback to merge if it fails
    if ! git pull --rebase --no-recurse-submodules --no-edit 2>/dev/null; then
        echo "⚠️ Rebase failed, using merge instead..."
        # Only abort if a rebase is actually in progress
        if [[ -f ".git/rebase-apply" || -f ".git/rebase-merge" ]]; then
            git rebase --abort 2>/dev/null || true
        fi
        # Use merge with allow-unrelated-histories for divergent branches
        # This handles cases where main branch or tags were added after feature branch creation
        # Use 'theirs' strategy to automatically accept remote changes when conflicts occur
        git pull --no-recurse-submodules --no-edit --allow-unrelated-histories --strategy-option theirs
    fi

    # Clean up stash (don't restore, these are temporary build artifacts)
    if git stash list | grep -q "Temporary stash before rebase"; then
        STASH_REF=$(git stash list | grep "Temporary stash before rebase" | head -1 | cut -d: -f1)
        git stash drop "$STASH_REF" || true
    fi
}
