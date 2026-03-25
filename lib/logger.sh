#!/bin/bash
# Logger library

info() { 
    if command -v gum &>/dev/null; then
        gum log --level info "$1" 2>/dev/null
    else
        echo "[INFO] $1"
    fi
}

warn() { 
    if command -v gum &>/dev/null; then
        gum log --level warn "$1" 2>/dev/null
    else
        echo "[WARN] $1"
    fi
}

error() { 
    if command -v gum &>/dev/null; then
        gum log --level error "$1" 2>/dev/null
    else
        echo "[ERROR] $1"
    fi
}

success() { 
    if command -v gum &>/dev/null; then
        gum log --level info "✓ $1" 2>/dev/null
    else
        echo "[OK] $1"
    fi
}
