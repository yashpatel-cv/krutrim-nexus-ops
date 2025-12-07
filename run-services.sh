#!/usr/bin/env bash
# run-services.sh - Bootstraps and runs the Python Orchestrator

set -Eeuo pipefail

BASE_DIR="$(dirname "$(realpath "$0")")"
VENV_DIR="$BASE_DIR/venv"

log() { echo "[$(date +'%H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; }

# Ensure Python 3
if ! command -v python3 &> /dev/null; then
    error "Python 3 is required but not found."
    exit 1
fi

# Verify Python version
PY_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
if [ "${PY_VERSION//./}" -lt 36 ]; then
    error "Python 3.6+ required, found $PY_VERSION"
    exit 1
fi

# Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
    log "Creating virtual environment..."
    if ! python3 -m venv "$VENV_DIR"; then
        error "Failed to create virtual environment"
        exit 1
    fi
    
    log "Installing dependencies..."
    if ! "$VENV_DIR/bin/pip" install pyyaml 2>&1; then
        error "Failed to install pyyaml"
        exit 1
    fi
fi

# Verify services.py exists
if [ ! -f "$BASE_DIR/services.py" ]; then
    error "services.py not found in $BASE_DIR"
    exit 1
fi

# Run
log "Starting Service Orchestrator..."
log "Working directory: $BASE_DIR"
log "Python: $($VENV_DIR/bin/python3 --version)"

exec "$VENV_DIR/bin/python3" "$BASE_DIR/services.py"
