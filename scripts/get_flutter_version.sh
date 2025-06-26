#!/usr/bin/env bash
awk -F: '/^[[:space:]]*flutter:/ {gsub(/'\''|"/,"",$2); gsub(/^[[:space:]]+/,"",$2); print $2; exit}' pubspec.yaml
