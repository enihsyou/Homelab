#!/usr/bin/env bash
# setup-mirror.sh — detect the host system and configure fast mirrors
# for common package managers and language ecosystems.
#
# Design principles:
#   * Detect what's actually installed before touching anything.
#   * Default mode is DRY-RUN: every file change is shown as a unified
#     diff, every CLI value change is shown as "old → new".
#   * Pass -y (or --yes) to actually apply the changes.
#   * Only rely on POSIX shell + coreutils/sed/awk/grep/diff (i.e.
#     binutils-class utilities that ship with every Linux/macOS).
#   * Encapsulate all ANSI escape codes in a single colour helper
#     block; the rest of the script only calls the log_* functions.
#
# Override mirror URLs by exporting the corresponding MIRROR_* env var, e.g.
#   MIRROR_NPM=https://registry.npmmirror.com ./setup-mirror.sh

set -Eeuo pipefail

# ----- Defaults (override via env) -----------------------------------------
: "${MIRROR_CERNET:=https://mirrors.cernet.edu.cn}"
: "${MIRROR_UBUNTU:=${MIRROR_CERNET}/ubuntu}"
: "${MIRROR_DEBIAN:=${MIRROR_CERNET}/debian}"
: "${MIRROR_DEBIAN_SECURITY:=${MIRROR_CERNET}/debian-security}"
: "${MIRROR_ARCH:=${MIRROR_CERNET}/archlinux/\$repo/os/\$arch}"
: "${MIRROR_PYPI:=${MIRROR_CERNET}/pypi/web/simple}"
: "${MIRROR_NPM:=https://registry.npmmirror.com}"
: "${MIRROR_CARGO:=${MIRROR_CERNET}/crates.io-index}"
: "${MIRROR_GOPROXY:=https://goproxy.cn/,direct}"
: "${MIRROR_GEM:=https://mirrors.tuna.tsinghua.edu.cn/rubygems/}"
: "${MIRROR_COMPOSER:=https://mirrors.aliyun.com/composer/}"

# ----- Runtime flags -------------------------------------------------------
APPLY=0   # 1 when -y/--yes is given; everything else runs in dry-run

# ----- Colour & logging helpers --------------------------------------------
# All ANSI escape codes live inside this single block; the rest of the
# script only uses the high-level log_* functions and the C_* variables.
_init_colors() {
    if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != "dumb" ] \
        && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
        C_RESET=$(tput sgr0)
        C_BOLD=$(tput bold)
        C_DIM=$(tput dim 2>/dev/null || tput sgr0)
        C_RED=$(tput setaf 1)
        C_GREEN=$(tput setaf 2)
        C_YELLOW=$(tput setaf 3)
        C_BLUE=$(tput setaf 4)
        C_MAGENTA=$(tput setaf 5)
        C_CYAN=$(tput setaf 6)
    else
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_DIM=$'\033[2m'
        C_RED=$'\033[31m'
        C_GREEN=$'\033[32m'
        C_YELLOW=$'\033[33m'
        C_BLUE=$'\033[34m'
        C_MAGENTA=$'\033[35m'
        C_CYAN=$'\033[36m'
    fi
}
_init_colors

# log helpers — the ONLY way the script should print status. If you need
# a new style of message, add a function here rather than sprinkling
# printf/ANSI codes throughout the rest of the file.
log_info()    { printf '%s[%sINFO%s]%s %s\n'  "$C_CYAN"    "$C_BOLD" "$C_CYAN"    "$C_RESET" "$*"; }
log_ok()      { printf '%s[%s OK %s]%s %s\n'  "$C_GREEN"   "$C_BOLD" "$C_GREEN"   "$C_RESET" "$*"; }
log_warn()    { printf '%s[%sWARN%s]%s %s\n'  "$C_YELLOW"  "$C_BOLD" "$C_YELLOW"  "$C_RESET" "$*" >&2; }
log_err()     { printf '%s[%sFAIL%s]%s %s\n'  "$C_RED"     "$C_BOLD" "$C_RED"     "$C_RESET" "$*" >&2; }
log_section() { printf '\n%s==>%s %s%s%s\n'    "$C_BOLD$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
log_action()  { printf '  %s->%s %s\n'         "$C_MAGENTA" "$C_RESET" "$*"; }
log_detail()  { printf '       %s\n'           "$*"; }
log_skip()    { printf '       %s(skip)%s %s\n' "$C_DIM" "$C_RESET" "$*"; }

die() { log_err "$*"; exit 1; }

# ----- Apply-or-diff helpers -----------------------------------------------
# Every write-capable setup_* function routes through one of these two
# helpers. They honour $APPLY: dry-run shows a diff / old→new, apply
# mode actually runs the provided command (or copies the proposed file
# into place, using sudo when needed).

# apply_or_diff_value <label> <current_value> <proposed_value> <apply_cmd...>
# These helpers always return 0. The outcome (no-change / applied / failed)
# is communicated through the log_* functions; the return value is NOT
# a status code, because under `set -e` any non-zero return from a bare
# function call would abort the whole script. Callers must not check it.
apply_or_diff_value() {
    local label="$1" current="$2" proposed="$3"
    shift 3

    if [ "$current" = "$proposed" ]; then
        log_skip "$label already: ${current:-<unset>}"
        return 0
    fi

    if [ "$APPLY" -eq 0 ]; then
        printf '       %s- %s%s\n' "$C_RED"   "${current:-<unset>}" "$C_RESET"
        printf '       %s+ %s%s\n' "$C_GREEN" "$proposed"          "$C_RESET"
    else
        if "$@"; then
            log_ok "$label -> $proposed"
        else
            log_warn "$label change failed: $*"
        fi
    fi
    return 0
}

# _emit_diff <current> <proposed> <label>
# Indented, colour-highlighted unified diff. Used by apply_or_diff_file.
_emit_diff() {
    local current="$1" proposed="$2" label="$3"
    log_detail "Diff for $label:"
    diff -u --label "a/${label}" --label "b/${label}" "$current" "$proposed" \
        | sed -E "s|^(\+\+\+ b/.*)$|${C_GREEN}\\1${C_RESET}|; \
                 s|^(---\ a/.*)$|${C_RED}\\1${C_RESET}|; \
                 s|^(\+[^+].*)$|${C_GREEN}\\1${C_RESET}|; \
                 s|^(-[^-].*)$|${C_RED}\\1${C_RESET}|" \
        | sed 's/^/         /' || true
}

# _copy_with_sudo <proposed> <current>
# Pick the right copy mechanism: prefer direct write, fall back to sudo.
_copy_with_sudo() {
    local proposed="$1" current="$2"
    local dir
    dir=$(dirname "$current")
    if [ "$(id -u)" -eq 0 ] || [ -w "$current" ] || [ -w "$dir" ]; then
        cp "$proposed" "$current"
    elif [ -n "${SUDO:-}" ]; then
        $SUDO cp "$proposed" "$current"
    else
        log_warn "No write permission for $current and sudo unavailable"
        return 1
    fi
}

# apply_or_diff_file <current_file> <proposed_file> [label]
# Routes to either write (in apply mode) or diff (in dry-run mode).
# If <current_file> does not exist, in dry-run the proposed content is
# dumped verbatim; in apply mode the file is created.
# Returns 0 unconditionally; see apply_or_diff_value for the rationale.
apply_or_diff_file() {
    local current="$1" proposed="$2" label="${3:-$1}"

    if [ ! -f "$current" ]; then
        if [ "$APPLY" -eq 0 ]; then
            log_detail "(file does not exist; would create with contents:)"
            sed 's/^/         /' "$proposed"
        else
            if _copy_with_sudo "$proposed" "$current"; then
                log_ok "Created $label"
            else
                log_warn "Failed to create $label"
            fi
        fi
        return 0
    fi

    if cmp -s "$current" "$proposed"; then
        log_skip "$label: no changes"
        return 0
    fi

    if [ "$APPLY" -eq 0 ]; then
        _emit_diff "$current" "$proposed" "$label"
    else
        if _copy_with_sudo "$proposed" "$current"; then
            log_ok "Wrote $label"
        else
            log_warn "Failed to write $label"
        fi
    fi
    return 0
}

# ----- Tiny utilities ------------------------------------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

file_contains() {
    # file_contains <path> <substring> — true if the file exists and
    # contains the substring (literal, not regex).
    local f="$1" needle="$2"
    [ -f "$f" ] || return 1
    grep -F -q -- "$needle" "$f"
}

# ----- OS / tool detection -------------------------------------------------
os_id=""
os_id_like=""
os_codename=""
os_version_id=""
os_pretty=""
SUDO=""

detect_os() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_id="${ID:-}"
        os_id_like="${ID_LIKE:-}"
        os_codename="${VERSION_CODENAME:-}"
        os_version_id="${VERSION_ID:-}"
        os_pretty="${PRETTY_NAME:-${NAME:-}}"
    else
        os_id=$(uname -s | tr '[:upper:]' '[:lower:]')
        os_pretty="$os_id"
    fi
}

detect_priv() {
    SUDO=""
    if [ "$(id -u)" -ne 0 ] && has_cmd sudo; then
        SUDO="sudo"
    fi
}

# ----- APT (Ubuntu / Debian) -----------------------------------------------
# Ubuntu 24.04+ and Debian 12+ use the DEB822 format in
# /etc/apt/sources.list.d/*.sources; older releases use the one-line
# format in /etc/apt/sources.list. We rewrite every apt source file we
# can find by piping through sed into a temp file, then either show
# the diff (dry-run) or copy it into place (-y).

_apt_rewrite_into() {
    # _apt_rewrite_into <input> <output> <mirror_host>
    # Apply the same sed transformations the implementation would, into
    # <output>. Mirror is just the host (e.g. "mirrors.cernet.edu.cn").
    local input="$1" output="$2" host="$3"
    sed -E \
        -e "s#(URIs:[[:space:]]+https?://)([A-Za-z0-9.-]*\.)?archive\.ubuntu\.com#\\1${host}/ubuntu#g" \
        -e "s#(deb(-src)?[[:space:]]+https?://)([A-Za-z0-9.-]*\.)?archive\.ubuntu\.com#\\1${host}/ubuntu#g" \
        -e "s#(URIs:[[:space:]]+https?://)([A-Za-z0-9.-]*\.)?deb\.debian\.org#\\1${host}#g" \
        -e "s#(URIs:[[:space:]]+https?://)([A-Za-z0-9.-]*\.)?security\.debian\.org/debian-security#\\1${host}-security#g" \
        -e "s#(deb(-src)?[[:space:]]+https?://)([A-Za-z0-9.-]*\.)?deb\.debian\.org/debian#\\1${host}/debian#g" \
        -e "s#(deb(-src)?[[:space:]]+https?://)([A-Za-z0-9.-]*\.)?security\.debian\.org/debian-security#\\1${host}-security#g" \
        "$input" > "$output"
}

setup_apt() {
    case "$os_id" in
        ubuntu)
            log_action "Rewriting Ubuntu apt sources to $MIRROR_UBUNTU"
            local host="${MIRROR_UBUNTU%/}"
            host="${host%/ubuntu}"   # template appends "/ubuntu" itself
            _apt_diff_files /etc/apt/sources.list.d/ubuntu.sources \
                            /etc/apt/sources.list \
                            "$host" \
                            "archive.ubuntu.com"
            ;;
        debian)
            log_action "Rewriting Debian apt sources to $MIRROR_DEBIAN"
            local host="${MIRROR_DEBIAN%/}"
            _apt_diff_files /etc/apt/sources.list.d/debian.sources \
                            /etc/apt/sources.list \
                            "$host" \
                            "deb.debian.org|security.debian.org"
            ;;
        *)
            log_detail "OS '$os_id' is not an apt distro — skipping"
            return 0
            ;;
    esac
}

# _apt_diff_files <primary_deb822> <primary_legacy> <mirror_host> <needle_re>
_apt_diff_files() {
    local primary_deb822="$1" primary_legacy="$2" host="$3" needle_re="$4"
    local -a files=()
    [ -f "$primary_deb822" ] && files+=("$primary_deb822")
    [ -f "$primary_legacy"  ] && files+=("$primary_legacy")

    for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [ -f "$f" ] || continue
        case "$f" in "$primary_deb822") continue ;; esac
        if grep -qE "$needle_re" "$f" 2>/dev/null; then
            files+=("$f")
        fi
    done

    if [ "${#files[@]}" -eq 0 ]; then
        log_skip "no matching apt source files found"
        return 0
    fi

    local f proposed
    for f in "${files[@]}"; do
        proposed=$(mktemp)
        _apt_rewrite_into "$f" "$proposed" "$host"
        apply_or_diff_file "$f" "$proposed" "${f##*/}"
        rm -f "$proposed"
    done
}

# ----- Pacman (Arch / Manjaro / etc.) --------------------------------------
setup_pacman() {
    if ! has_cmd pacman; then
        log_detail "pacman not installed — skipping"
        return 0
    fi
    case "$os_id$os_id_like" in
        *arch*|*manjaro*|*endeavour*|"") ;;
        *) log_detail "Distro '$os_id' doesn't look like Arch — skipping pacman"; return 0 ;;
    esac

    local mirrorlist=/etc/pacman.d/mirrorlist
    [ -f "$mirrorlist" ] || { log_skip "no $mirrorlist"; return 0; }

    if file_contains "$mirrorlist" "## Added by setup-mirror.sh"; then
        log_skip "$mirrorlist already has a setup-mirror entry"
        return 0
    fi

    local proposed
    proposed=$(mktemp)
    {
        printf '## Added by setup-mirror.sh on %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'Server = %s\n' "$MIRROR_ARCH"
        cat "$mirrorlist"
    } > "$proposed"

    log_action "Prepending mirror entry to $mirrorlist"
    apply_or_diff_file "$mirrorlist" "$proposed" "${mirrorlist##*/}"
    rm -f "$proposed"
}

# ----- npm -----------------------------------------------------------------
setup_npm() {
    if ! has_cmd npm; then log_detail "npm not installed — skipping"; return 0; fi
    local current
    current=$(npm config get registry 2>/dev/null || echo "")
    log_action "Setting npm registry to $MIRROR_NPM"
    apply_or_diff_value "npm registry" "$current" "$MIRROR_NPM" \
        npm config set registry "$MIRROR_NPM"
}

# ----- pip -----------------------------------------------------------------
setup_pip() {
    local pip_bin=""
    if has_cmd pip3; then pip_bin=pip3
    elif has_cmd pip; then pip_bin=pip
    else
        log_detail "pip not installed — skipping"
        return 0
    fi
    local current
    current=$("$pip_bin" config get global.index-url 2>/dev/null || true)
    log_action "Setting pip index-url to $MIRROR_PYPI"
    apply_or_diff_value "pip index-url" "$current" "$MIRROR_PYPI" \
        "$pip_bin" config set global.index-url "$MIRROR_PYPI"
}

# ----- uv ------------------------------------------------------------------
setup_uv() {
    if ! has_cmd uv; then log_detail "uv not installed — skipping"; return 0; fi
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml"
    if [ -f "$cfg" ] && file_contains "$cfg" "$MIRROR_PYPI"; then
        log_skip "uv already references $MIRROR_PYPI in $cfg"
        return 0
    fi
    local proposed
    proposed=$(mktemp)
    {
        if [ -f "$cfg" ]; then cat "$cfg"; fi
        printf '\n## Added by setup-mirror.sh on %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '[[index]]\n'
        printf 'url = "%s"\n' "$MIRROR_PYPI"
        printf 'default = true\n'
    } > "$proposed"
    log_action "Appending default index to $cfg"
    apply_or_diff_file "$cfg" "$proposed" "${cfg##*/}"
    rm -f "$proposed"
}

# ----- Cargo (Rust) --------------------------------------------------------
setup_cargo() {
    if ! has_cmd cargo; then log_detail "cargo not installed — skipping"; return 0; fi
    local cfg="${CARGO_HOME:-$HOME/.cargo}/config.toml"
    if [ -f "$cfg" ] && file_contains "$cfg" "sparse+${MIRROR_CARGO}"; then
        log_skip "cargo already references $MIRROR_CARGO"
        return 0
    fi
    local proposed
    proposed=$(mktemp)
    {
        if [ -f "$cfg" ]; then cat "$cfg"; fi
        printf '\n## Added by setup-mirror.sh\n'
        printf '[registries.cernet]\n'
        printf 'index = "sparse+%s/"\n' "$MIRROR_CARGO"
        printf '\n[source.crates-io]\n'
        printf 'replace-with = "cernet"\n'
    } > "$proposed"
    log_action "Adding cernet registry to $cfg"
    apply_or_diff_file "$cfg" "$proposed" "${cfg##*/}"
    rm -f "$proposed"
}

# ----- Go ------------------------------------------------------------------
setup_go() {
    if ! has_cmd go; then log_detail "go not installed — skipping"; return 0; fi
    local current
    current=$(go env GOPROXY 2>/dev/null || echo "")
    log_action "Setting GOPROXY to $MIRROR_GOPROXY"
    apply_or_diff_value "GOPROXY" "$current" "$MIRROR_GOPROXY" \
        go env -w GOPROXY="$MIRROR_GOPROXY"
}

# ----- RubyGems ------------------------------------------------------------
setup_gem() {
    if ! has_cmd gem; then log_detail "gem not installed — skipping"; return 0; fi
    local current
    current=$(gem sources -l 2>/dev/null | grep -E '^[[:space:]]*https?://' | head -1 | tr -d ' \t' || true)
    log_action "Setting gem source to $MIRROR_GEM"
    apply_or_diff_value "gem source" "$current" "$MIRROR_GEM" \
        gem sources --add "$MIRROR_GEM"
}

# ----- Composer (PHP) ------------------------------------------------------
setup_composer() {
    if ! has_cmd composer; then log_detail "composer not installed — skipping"; return 0; fi
    local cfg="$HOME/.composer/composer.json"
    [ ! -f "$cfg" ] && cfg="$HOME/.config/composer/composer.json"
    local current=""
    if [ -f "$cfg" ]; then
        current=$(grep -oE '"https?://[^"]+"' "$cfg" 2>/dev/null \
                  | grep -E 'packagist|composer' | head -1 | tr -d '"' || true)
    fi
    log_action "Setting composer packagist mirror to $MIRROR_COMPOSER"
    apply_or_diff_value "composer packagist" "$current" "$MIRROR_COMPOSER" \
        composer config -g repo.packagist composer "$MIRROR_COMPOSER"
}

# ----- Main ----------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [-y]

Detect the host OS and configure fast mirrors for the system package
managers and language toolchains that are actually installed.

By default the script runs in dry-run mode: every file change is shown
as a unified diff and every CLI value change is shown as "old → new".
Nothing is written. Pass -y (or --yes) to actually apply the changes.

Options:
  -y, --yes    Apply changes. Without this flag the script only reports
               what it would do.
  -h, --help   Show this message.

Environment overrides (all optional):
  MIRROR_CERNET, MIRROR_UBUNTU, MIRROR_DEBIAN, MIRROR_DEBIAN_SECURITY,
  MIRROR_ARCH, MIRROR_PYPI, MIRROR_NPM, MIRROR_CARGO, MIRROR_GOPROXY,
  MIRROR_GEM, MIRROR_COMPOSER
EOF
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes)    APPLY=1 ;;
            -h|--help)   usage; exit 0 ;;
            *) die "Unknown argument: $1 (use -h for help)" ;;
        esac
        shift
    done

    log_section "System detection"
    detect_os
    detect_priv
    log_info "OS:    ${os_pretty:-unknown}  (id=${os_id:-?}, codename=${os_codename:-?}, version=${os_version_id:-?})"
    log_info "Priv:  $([ "$(id -u)" -eq 0 ] && echo root || echo "user (sudo=$([ -n "$SUDO" ] && echo yes || echo no))")"
    if [ "$APPLY" -eq 0 ]; then
        log_warn "DRY-RUN mode — no files will be modified. Pass -y to apply."
    else
        log_warn "APPLY mode (-y) — files will be modified."
    fi

    log_section "System package managers"
    setup_apt
    setup_pacman

    log_section "Language toolchains"
    setup_npm
    setup_pip
    setup_uv
    setup_cargo
    setup_go
    setup_gem
    setup_composer

    log_section "Summary"
    if [ "$APPLY" -eq 0 ]; then
        log_info "Dry-run complete — re-run with -y to apply the diffs above."
    else
        log_ok   "Apply complete. Refresh the package cache manually if needed."
    fi
    printf '%sTip:%s pipe through %s| less -r%s for long diffs.\n' \
        "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
}

main "$@"
