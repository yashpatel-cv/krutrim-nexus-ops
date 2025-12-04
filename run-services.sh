#!/usr/bin/env bash
# run-services.sh - Bootstraps and runs the Python Orchestrator

set -Eeuo pipefail

BASE_DIR="$(dirname "$(realpath "$0")")"
VENV_DIR="$BASE_DIR/venv"

# Ensure Python 3
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required."
    exit 1
fi

# Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install pyyaml
fi

# Run
echo "Starting Service Orchestrator..."
"$VENV_DIR/bin/python3" "$BASE_DIR/services.py"
