#!/bin/sh
# Installs dwim from its GitHub releases:
#
#   curl -fsSL https://dwim.sh/install.sh | sh
#
# DWIM_VERSION picks a release (such as v0.1.0) instead of the latest, and
# DWIM_INSTALL_DIR a directory for the binary instead of ~/.local/bin.
#
# Everything is inside main, called on the last line, so that a download cut
# short runs nothing.

set -eu

main() {
    colors
    repo="dwim-sh/dwim"

    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os-$arch" in
        Darwin-arm64) target=aarch64-apple-darwin platform="macOS on Apple silicon" ;;
        Linux-x86_64 | Linux-amd64) target=x86_64-unknown-linux-gnu platform="Linux on x86-64" ;;
        Linux-aarch64 | Linux-arm64) target=aarch64-unknown-linux-gnu platform="Linux on ARM64" ;;
        *) fail "there is no release for $os on $arch yet; build from source with: cargo install --git https://github.com/$repo" ;;
    esac

    need curl
    need tar
    need mktemp

    if [ -n "${DWIM_VERSION:-}" ]; then
        base="https://github.com/$repo/releases/download/$DWIM_VERSION"
    else
        base="https://github.com/$repo/releases/latest/download"
    fi
    name="dwim-$target"
    bin_dir="${DWIM_INSTALL_DIR:-$HOME/.local/bin}"
    man_dir="${XDG_DATA_HOME:-$HOME/.local/share}/man/man1"

    logo

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT INT TERM

    doing "Downloading dwim for $platform"
    curl -fsL --proto '=https' --tlsv1.2 "$base/$name.tar.gz" -o "$tmp/$name.tar.gz" ||
        fail "could not download $base/$name.tar.gz"
    curl -fsL --proto '=https' --tlsv1.2 "$base/$name.tar.gz.sha256" -o "$tmp/$name.tar.gz.sha256" ||
        fail "could not download $base/$name.tar.gz.sha256"
    did "Downloaded dwim for $platform"

    doing "Checking the download"
    verify "$tmp" "$name.tar.gz"
    did "Checked the download against its SHA-256"

    doing "Installing"
    tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
    mkdir -p "$bin_dir" "$man_dir"
    install -m 755 "$tmp/$name/dwim" "$bin_dir/dwim"
    install -m 644 "$tmp/$name/dwim.1" "$man_dir/dwim.1"
    version="$("$bin_dir/dwim" --version 2>/dev/null || echo dwim)"
    did "Installed $bold$version$reset in $(tilde "$bin_dir")"

    if [ "$os" = Linux ] && ! has_vulkan; then
        warn "No Vulkan loader (libvulkan.so.1) found: dwim needs a Vulkan 1.1 driver to run."
    fi

    echo
    case ":$PATH:" in
        *":$bin_dir:"*) say "Start dwim with:" ;;
        *)
            say "$(tilde "$bin_dir") is not on your PATH yet. Add it with:"
            echo
            say "    $bold$(path_command)$reset"
            echo
            say "and open a new terminal. Then start dwim with:"
            ;;
    esac
    echo
    say "    ${bold}dwim$reset"
    echo
    say "${dim}The first run fetches the model (6 GB). After that, it all runs on this machine.$reset"
    echo
}

# Draws the robot from the front page, two pixels to a character cell: each
# letter below is a pixel (k black, w white, g green, . clear), and awk turns
# each pair of rows into one line of half blocks. It only draws in color.
logo() {
    [ -n "$reset" ] || return 0
    awk -v k="$k" -v w="$w" -v g="$g" '
        function color(c) { return c == "k" ? k : c == "w" ? w : g }
        BEGIN { print "" }
        NR % 2 { top = $0; next }
        {
            line = ""
            for (i = 1; i <= length(top); i++) {
                t = substr(top, i, 1); b = substr($0, i, 1)
                if (t == "." && (b == "." || b == "")) line = line " "
                else if (t == ".") line = line "\033[38;" color(b) "m\342\226\204\033[0m"
                else if (b == "." || b == "") line = line "\033[38;" color(t) "m\342\226\200\033[0m"
                else line = line "\033[38;" color(t) ";48;" color(b) "m\342\226\200\033[0m"
            }
            if (NR == 20) line = line "    \033[1;38;" g "mdwim\033[0m"
            if (NR == 22) line = line "    \033[2mdo what I mean\033[0m"
            print "  " line
        }
        END { print "" }
    ' <<'EOF'
................kkkkkkkk................
.............kkkkkwwwwkkkkk.............
...........kkkwwwwwwwwwwwwkkk...........
..........kkwwwwwwwwwwwwwwwwkk..........
.........kkwwwwwwwwwwwwwwwwwwkk.........
........kkwwwwwkkkkkkkkkkwwwwwkk........
........kwwwkkkkkkkkkkkkkkkkwwwkk.......
.......kkwwkkkkkkkkkkkkkkkkkkwwwk.......
.......kwwkkkkkkkkkkkkkkkkkkkkwwkk......
.....kkkwwkkkkkkkkkkkkkkkkkkkkwwkkk.....
....kkwkwkkkkkkkkkkkkkkkkkkkkkkwkwwk....
....kwwkwkkkkkkkkkkkkkkkkkkkkkkwkwwk....
...kgkwkwkkkkggggkkkkkkggggkkkkwkwkgk...
...kgkwkwkkkggggggkkkkggggggkkkwkwkgk...
...kgkwkwkkkgkkkkggkkkggkkkggkkwkwkgk...
...kgkwkwkkkkkkkkkkkkkkkkkkkkkkwkwkgk...
....kkwkwkkkkkkkkkkkkkkkkkkkkkkwkwwk....
....kkwkwwkkkkkkkkkkkkkkkkkkkkkwkwwk....
.....kkkwwkkkkkkkkkkkkkkkkkkkkwwkkk.....
.......kwwwwkkkkkkkkkkkkkkkkkwwwk.......
........kkwwwwwwwwwwwwwwwwwwwwwkk.......
.........kkkkkkkkkkkkkkkkkkkkkk.........
............kkkkkkkkkkkkkkkk............
............kkwwwkkkkkkkwwkkk...........
...........kkkwwwwwwwwwwwwkkkk..........
..........kkkkwwwwkkkkwwwwkkkk..........
.........kwwwkwwwwggggwwwwkkwwk.........
..kk.....kwwwkwwwwggggwwwwkwwwk.....kk..
.kkkk...kkwwwkwwwwggggwwwwkwwwwk...kkkkk
kk.kkkkkkkkwwkkwwwkkkkwwwwkwwwkkkkkkk.kk
kkkkkkwwwwkwwkkwwwwwwwwwwkkkwkwwwwkkkkkk
.kkkkwwwwwkkk.kwwwwwwwwwwk.kkkwwwwwkkkkk
..kkkwwwwkkkk..kwwwwwwwwkk.kkkkwwwwkkkk.
....kkkkkkkkkkkkkkwwwwwkkkkkkkkkkkkk....
.....kkwwwwkwwwkkkkkkkkkkwwwkwwwwwk.....
.....kwwwwwwkkwwwkkkkkkkwwkkwwwwwwkk....
....kkwwwwwwwwkkwkkkkkkwkkwwwwwwwwkk....
.....kwwwwwwwwwkkkkkkkkkkwwwwwwwwwkk....
.....kwwwwwwwwwkkwwwwkwkkwwwwwwwwwk.....
......kwwwwwwwwkkwwwwkkkkwwwwwwwwkk.....
.......kkkkwwwwkkwwwwkwkkkwwwkkkk.......
..........kkkkkkkkkkkkkkkkkkkkk.........
EOF
}

# Checks a file against the SHA-256 checksum next to it.
verify() {
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$1" && sha256sum -c "$2.sha256" >/dev/null) || fail "checksum mismatch for $2"
    elif command -v shasum >/dev/null 2>&1; then
        (cd "$1" && shasum -a 256 -c "$2.sha256" >/dev/null) || fail "checksum mismatch for $2"
    else
        warn "Neither sha256sum nor shasum found, so the download is not checked."
    fi
}

has_vulkan() {
    if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q 'libvulkan\.so\.1'; then
        return 0
    fi
    for dir in /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu /usr/local/lib; do
        [ -e "$dir/libvulkan.so.1" ] && return 0
    done
    return 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || fail "this installer needs '$1'"
}

# Sets the escape sequences the output uses, or leaves them empty when the
# output is not a terminal that takes color. On a terminal that says it has
# 24-bit color, the logo uses the front page's exact colors.
colors() {
    bold="" dim="" green="" yellow="" red="" reset="" clear=""
    [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] || return 0
    esc="$(printf '\033')"
    bold="${esc}[1m" dim="${esc}[2m" green="${esc}[32m" yellow="${esc}[33m" red="${esc}[31m" reset="${esc}[0m" clear="$(printf '\r')${esc}[2K"
    case "${COLORTERM:-}" in
        truecolor | 24bit) k="2;19;20;22" w="2;252;245;229" g="2;52;231;180" ;;
        *) k="5;233" w="5;255" g="5;43" ;;
    esac
    green="${esc}[38;${g}m"
}

# Shows a step while it runs, on a terminal; did replaces it once it is done.
doing() {
    [ -z "$reset" ] || printf '  %s○%s %s…' "$dim" "$reset" "$1"
}

did() {
    printf '%s  %s✓%s %s\n' "$clear" "$green" "$reset" "$1"
}

warn() {
    printf '%s  %s!%s %s\n' "$clear" "$yellow" "$reset" "$1"
}

say() {
    printf '  %s\n' "$1"
}

fail() {
    printf '%s' "${clear:-}"
    printf '  %s✗%s dwim: %s\n' "${red:-}" "${reset:-}" "$1" >&2
    exit 1
}

# Writes a path under the home directory as ~/….
tilde() {
    case "$1" in
        "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# The command that puts the install directory on PATH for the user's shell.
path_command() {
    case "$bin_dir" in
        "$HOME"/*) dir="\$HOME${bin_dir#"$HOME"}" ;;
        *) dir="$bin_dir" ;;
    esac
    case "${SHELL:-}" in
        */zsh) printf "echo 'export PATH=\"%s:\$PATH\"' >> ~/.zshrc" "$dir" ;;
        */bash) printf "echo 'export PATH=\"%s:\$PATH\"' >> ~/.bashrc" "$dir" ;;
        */fish) printf 'fish_add_path %s' "$(tilde "$bin_dir")" ;;
        *) printf "echo 'export PATH=\"%s:\$PATH\"' >> ~/.profile" "$dir" ;;
    esac
}

main "$@"
