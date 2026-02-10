#!/usr/bin/env bash
# install-cursor-linux.sh - Install Cursor IDE on Linux
# Part of workshop-bootstrap
#
# Supports: Debian/Ubuntu (.deb), Fedora/RHEL (.rpm), and any distro (AppImage)
# Supports: x64 and arm64 architectures
# Uses the latest stable version from api2.cursor.sh

set -euo pipefail

_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_INSTALLER_DIR}/utils.sh"

# Download base URL - uses "latest" to always get the current stable release
CURSOR_DOWNLOAD_BASE="https://api2.cursor.sh/updates/download/golden"

# --- Architecture detection ---

detect_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64|amd64)   echo "x64" ;;
        aarch64|arm64)   echo "arm64" ;;
        *)
            log_error "Unsupported architecture: $machine"
            exit 1
            ;;
    esac
}

# --- Package manager detection ---
# Returns the best install format for this system: deb, rpm, or appimage

detect_install_format() {
    if command -v dpkg &>/dev/null && command -v apt-get &>/dev/null; then
        echo "deb"
    elif command -v rpm &>/dev/null && (command -v dnf &>/dev/null || command -v yum &>/dev/null || command -v zypper &>/dev/null); then
        echo "rpm"
    else
        echo "appimage"
    fi
}

# --- Build download URL ---
# Pattern: ${BASE}/linux-{arch}[-format]/cursor/latest
#   AppImage: linux-x64         / linux-arm64
#   Deb:      linux-x64-deb     / linux-arm64-deb
#   RPM:      linux-x64-rpm     / linux-arm64-rpm

build_download_url() {
    local arch="$1"
    local format="$2"

    local platform="linux-${arch}"
    if [[ "$format" != "appimage" ]]; then
        platform="${platform}-${format}"
    fi

    echo "${CURSOR_DOWNLOAD_BASE}/${platform}/cursor/latest"
}

# --- Cursor detection ---

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

# --- Main install entry point ---

install_cursor_linux() {
    local arch format url
    arch="$(detect_arch)"
    format="$(detect_install_format)"
    url="$(build_download_url "$arch" "$format")"

    log_step "Installing Cursor IDE on Linux..."
    log_info "Architecture: $arch"
    log_info "Install format: $format"
    log_info "Download URL: $url"

    case "$format" in
        deb)
            install_cursor_deb "$url" "$arch"
            ;;
        rpm)
            install_cursor_rpm "$url" "$arch"
            ;;
        appimage)
            install_cursor_appimage "$url" "$arch"
            ;;
    esac
}

# --- .deb installer (Debian, Ubuntu, Mint, Pop!_OS, etc.) ---

install_cursor_deb() {
    local url="$1"
    local arch="$2"
    local deb_path="/tmp/cursor.deb"

    log_info "Installing Cursor via .deb package..."

    log_info "Downloading Cursor .deb..."
    curl -fSL -o "$deb_path" "$url" || {
        log_warn ".deb download failed, falling back to AppImage"
        local fallback_url
        fallback_url="$(build_download_url "$arch" "appimage")"
        install_cursor_appimage "$fallback_url" "$arch"
        return $?
    }

    log_info "Installing .deb package (may prompt for password)..."
    sudo dpkg -i "$deb_path" || sudo apt-get install -f -y
    rm -f "$deb_path"

    log_success "Cursor installed via .deb"
    return 0
}

# --- .rpm installer (Fedora, RHEL, CentOS, openSUSE, etc.) ---

install_cursor_rpm() {
    local url="$1"
    local arch="$2"
    local rpm_path="/tmp/cursor.rpm"

    log_info "Installing Cursor via .rpm package..."

    log_info "Downloading Cursor .rpm..."
    curl -fSL -o "$rpm_path" "$url" || {
        log_warn ".rpm download failed, falling back to AppImage"
        local fallback_url
        fallback_url="$(build_download_url "$arch" "appimage")"
        install_cursor_appimage "$fallback_url" "$arch"
        return $?
    }

    log_info "Installing .rpm package (may prompt for password)..."
    if command -v dnf &>/dev/null; then
        sudo dnf install -y "$rpm_path"
    elif command -v yum &>/dev/null; then
        sudo yum localinstall -y "$rpm_path"
    elif command -v zypper &>/dev/null; then
        sudo zypper --no-confirm install "$rpm_path"
    else
        sudo rpm -i "$rpm_path"
    fi
    rm -f "$rpm_path"

    log_success "Cursor installed via .rpm"
    return 0
}

# --- AppImage installer (universal fallback) ---

install_cursor_appimage() {
    local url="$1"
    local arch="$2"

    log_info "Installing Cursor via AppImage..."

    local install_dir="$HOME/.local/bin"
    local appimage_path="$install_dir/cursor.AppImage"

    mkdir -p "$install_dir"

    log_info "Downloading Cursor AppImage..."
    curl -fSL -o "$appimage_path" "$url"

    chmod +x "$appimage_path"

    # Create wrapper script so `cursor` works from the command line
    cat > "$install_dir/cursor" << 'WRAPPER'
#!/usr/bin/env bash
"$HOME/.local/bin/cursor.AppImage" "$@"
WRAPPER
    chmod +x "$install_dir/cursor"

    # Add ~/.local/bin to PATH if needed
    ensure_local_bin_in_path "$install_dir"

    # Create desktop entry for app launchers
    create_cursor_desktop_entry

    log_success "Cursor installed to $appimage_path"
    return 0
}

# --- Helpers ---

ensure_local_bin_in_path() {
    local install_dir="$1"

    if [[ ":$PATH:" == *":$install_dir:"* ]]; then
        return 0
    fi

    log_info "Adding $install_dir to PATH..."

    # Detect shell config file
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

    export PATH="$install_dir:$PATH"
}

create_cursor_desktop_entry() {
    local desktop_dir="$HOME/.local/share/applications"
    local desktop_file="$desktop_dir/cursor.desktop"

    mkdir -p "$desktop_dir"

    cat > "$desktop_file" << EOF
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

    log_info "Created desktop entry at $desktop_file"
}

# --- Open Cursor ---

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
