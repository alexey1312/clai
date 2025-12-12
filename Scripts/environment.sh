#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ ! -x "$PROJECT_ROOT/bin/mise" ]]; then
    echo "Error: bin/mise not found"
    exit 1
fi

export PATH="$PROJECT_ROOT/bin:$PATH"
eval "$("$PROJECT_ROOT/bin/mise" activate bash)"
mise trust "$PROJECT_ROOT/mise.toml"
mise install

echo "Environment ready!"
