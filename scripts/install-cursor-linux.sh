#!/usr/bin/env bash
# install-cursor-linux.sh - Install Cursor IDE on Linux
# Part of workshop-bootstrap

set -euo pipefail

_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_INSTALLER_DIR}/utils.sh"

detect_cursor_linux() {
    # Check CLI in PATH
    if command -v cursor &>/dev/null; then
        return 0
    fi
    
    # Check common install locations
    local cursor_paths=(
        "/opt/cursor/cursor"
        "/usr/bin/cursor"
        "$HOME/.local/bin/cursor"
        "$HOME/Applications/cursor.AppImage"
        "/usr/share/cursor/cursor"
    )
    
    for path in "${cursor_paths[@]}"; do
        if [[ -x "$path" ]]; then
            return 0
        fi
    done
    
    # Check for AppImage in Downloads
    if ls "$HOME/Downloads"/cursor*.AppImage &>/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

install_cursor_linux() {
    log_step "Installing Cursor IDE on Linux..."

    # Try AppImage method (most reliable across distros)
    install_cursor_appimage
}

install_cursor_appimage() {
    log_info "Installing Cursor via AppImage..."
    
    local INSTALL_DIR="$HOME/.local/bin"
    local APPIMAGE_PATH="$INSTALL_DIR/cursor.AppImage"
    
    mkdir -p "$INSTALL_DIR"
    
    # Download AppImage
    log_info "Downloading Cursor AppImage..."
    curl -fSL -o "$APPIMAGE_PATH" "https://downloader.cursor.sh/linux/appImage/x64"
    
    # Make executable
    chmod +x "$APPIMAGE_PATH"
    
    # Create wrapper script
    cat > "$INSTALL_DIR/cursor" << 'EOF'
#!/usr/bin/env bash
"$HOME/.local/bin/cursor.AppImage" "$@"
EOF
    chmod +x "$INSTALL_DIR/cursor"
    
    # Add to PATH if needed
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_info "Adding $INSTALL_DIR to PATH..."
        
        # Detect shell and update config
        local shell_rc=""
        if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
            shell_rc="$HOME/.zshrc"
        else
            shell_rc="$HOME/.bashrc"
        fi
        
        if ! grep -q "export PATH=.*\.local/bin" "$shell_rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            log_info "Added PATH update to $shell_rc"
        fi
        
        export PATH="$INSTALL_DIR:$PATH"
    fi
    
    # Create desktop entry
    create_cursor_desktop_entry
    
    log_success "Cursor installed to $APPIMAGE_PATH"
    return 0
}

install_cursor_deb() {
    log_info "Attempting to install Cursor via .deb package..."
    
    local DEB_PATH="/tmp/cursor.deb"
    
    # Download .deb (if available)
    curl -fSL -o "$DEB_PATH" "https://downloader.cursor.sh/linux/deb/x64" || {
        log_warn ".deb download not available, falling back to AppImage"
        install_cursor_appimage
        return $?
    }
    
    # Install
    sudo dpkg -i "$DEB_PATH" || sudo apt-get install -f -y
    rm -f "$DEB_PATH"
    
    log_success "Cursor installed via .deb"
    return 0
}

create_cursor_desktop_entry() {
    local DESKTOP_DIR="$HOME/.local/share/applications"
    local DESKTOP_FILE="$DESKTOP_DIR/cursor.desktop"
    
    mkdir -p "$DESKTOP_DIR"
    
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Cursor
Comment=AI Code Editor
Exec=$HOME/.local/bin/cursor %F
Icon=cursor
Type=Application
Categories=Development;IDE;
StartupWMClass=Cursor
MimeType=text/plain;inode/directory;
EOF
    
    log_info "Created desktop entry at $DESKTOP_FILE"
}

open_cursor_linux() {
    local workspace="${1:-.}"
    
    log_step "Opening Cursor..."
    
    if command -v cursor &>/dev/null; then
        cursor "$workspace" &
    elif [[ -x "$HOME/.local/bin/cursor" ]]; then
        "$HOME/.local/bin/cursor" "$workspace" &
    elif [[ -x "$HOME/.local/bin/cursor.AppImage" ]]; then
        "$HOME/.local/bin/cursor.AppImage" "$workspace" &
    else
        log_warn "Could not open Cursor automatically"
        log_info "Please open Cursor manually and open the workspace: $workspace"
        return 1
    fi
    
    log_success "Cursor opened"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_cursor_linux
fi

