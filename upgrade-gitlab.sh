#!/usr/bin/env bash
# safer upgrade script for gitlab omnibus packages
# preserves original behaviour but adds preflight checks, backups, dry-run and logging

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "This script requires bash. Run it with: bash $0 [--dry-run] <version1> [version2 ...]"
    exit 1
fi

# Back up the original script if not already backed up
if [ ! -f upgrade-gitlab.sh.orig ]; then
    cp -- upgrade-gitlab.sh upgrade-gitlab.sh.orig || true
fi

DRY_RUN=0
# Default logfile path - may be overridden for dry-run to a local path
DEFAULT_LOGDIR="/var/log"
LOGFILE="${DEFAULT_LOGDIR}/gitlab-upgrade-$(date +%Y%m%d%H%M%S).log"

usage(){
    cat <<USAGE
Usage: $0 [--dry-run] <version1> [version2 ...]

Examples:
  $0 10.1.2 11.6.4 12.4.4
  $0 "10.1.2 => 11.6.4 => 12.4.4"

This script will:
 - perform lightweight preflight checks
 - create a backup (if possible) using gitlab-rake
 - attempt to install the specified omnibus package versions in order
 - reconfigure and restart GitLab between versions

Use --dry-run to see planned actions without making changes.
USAGE
}

log(){
    local msg
    msg="$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"
    printf '%s\n' "$msg"
    if ! printf '%s\n' "$msg" >>"$LOGFILE" 2>/dev/null; then
        >&2 printf 'WARNING: could not write log file %s\n' "$LOGFILE"
    fi
}

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
    shift
fi

# Handle versions separated by "=>" if passed as a single argument
if [ $# -eq 1 ] && [[ "$1" == *" => "* ]]; then
    VERSIONS=($(echo "$1" | sed 's/ *=> */ /g'))
    set -- "${VERSIONS[@]}"
fi

if [ $# -lt 1 ]; then
    usage
    exit 2
fi

# Only require root when performing real operations. Allow --dry-run to be used
# by non-root users for testing/CI purposes.
if [[ $EUID -ne 0 && $DRY_RUN -ne 1 ]]; then
   echo "This script must be run as root (or via sudo). Use --dry-run to run without root for testing."
   exit 1
fi

# Preflight checks
if [ "$DRY_RUN" -eq 1 ]; then
    mkdir -p ./logs
    LOGFILE="./logs/gitlab-upgrade-$(date +%Y%m%d%H%M%S).log"
    log "DRY-RUN: skipping platform package manager and gitlab-ctl checks"
else
    command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1 || { log "No yum/dnf found. Unsupported platform."; exit 3; }
    command -v gitlab-ctl >/dev/null 2>&1 || { log "gitlab-ctl not found in PATH. Is GitLab installed?"; exit 4; }
fi

log "Starting GitLab upgrade script"

# Check free disk space (simple check on /var)
if [ "$DRY_RUN" -ne 1 ]; then
    if avail_kb=$(df --output=avail /var 2>/dev/null | tail -n1 | tr -d ' '); then
        if [ "$avail_kb" -lt 524288 ]; then
            log "Warning: less than 512MB available on /var. Upgrades may fail. Available KB=$avail_kb"
        fi
    else
        log "Warning: unable to determine available disk space on /var. Skipping disk check."
    fi
else
    log "DRY-RUN: skipping disk space check"
fi

# Attempt to create a backup (best-effort)
if [ $DRY_RUN -eq 1 ]; then
    log "DRY-RUN: would run: gitlab-rake gitlab:backup:create"
else
    if command -v gitlab-rake >/dev/null 2>&1; then
        log "Creating GitLab backup via gitlab-rake gitlab:backup:create"
        if ! gitlab-rake gitlab:backup:create >>"$LOGFILE" 2>&1; then
            log "Backup command failed — continuing cautiously. Check $LOGFILE"
        fi
    else
        log "gitlab-rake not available; skipping automated backup. Make sure you have a manual backup."
    fi
fi

detect_package_type(){
    if [ "$DRY_RUN" -eq 1 ]; then
        PACKAGE_TYPE="gitlab-ce"
        return 0
    fi

    if command -v rpm >/dev/null 2>&1; then
        if rpm -q gitlab-ce >/dev/null 2>&1; then
            PACKAGE_TYPE="gitlab-ce"
        elif rpm -q gitlab-ee >/dev/null 2>&1; then
            PACKAGE_TYPE="gitlab-ee"
        else
            local installed_pkg
            installed_pkg=$(rpm -qa | grep -E '^gitlab-(ce|ee)(-|$)' | head -n1 || true)
            if [ -n "$installed_pkg" ]; then
                if [[ "$installed_pkg" == gitlab-ee* ]]; then
                    PACKAGE_TYPE="gitlab-ee"
                else
                    PACKAGE_TYPE="gitlab-ce"
                fi
            else
                log "Unable to detect installed GitLab package type. Please ensure gitlab-ce or gitlab-ee is installed."
                return 1
            fi
        fi
    else
        log "RPM is not available; cannot detect installed GitLab package type."
        return 1
    fi

    log "Detected installed GitLab package type: ${PACKAGE_TYPE}"
}

if ! detect_package_type; then
    exit 5
fi

# Helper to check whether a package version is available in repos
pkg_available(){
    local pkg="$1"
    local basepkg version
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    if [[ "$pkg" == gitlab-ce-* ]]; then
        basepkg="gitlab-ce"
        version="${pkg#gitlab-ce-}"
    elif [[ "$pkg" == gitlab-ee-* ]]; then
        basepkg="gitlab-ee"
        version="${pkg#gitlab-ee-}"
    else
        log "Unable to parse package name '${pkg}'."
        return 1
    fi

    if command -v yum >/dev/null 2>&1; then
        yum --quiet --showduplicates list "${basepkg}" 2>/dev/null | awk '{print $1, $2}' | grep -qE "^${basepkg}(\.[^[:space:]]+)?[[:space:]]+${version}([-.]|$)" || return 1
    elif command -v dnf >/dev/null 2>&1; then
        dnf --quiet --showduplicates list "${basepkg}" 2>/dev/null | awk '{print $1, $2}' | grep -qE "^${basepkg}(\.[^[:space:]]+)?[[:space:]]+${version}([-.]|$)" || return 1
    else
        return 1
    fi
}

# Install and reconfigure step
install_and_reconfigure(){
    local version="$1"
    local pkgname="${PACKAGE_TYPE}-${version}"
    log "Processing version ${version}"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "DRY-RUN: would check availability of ${pkgname}"
        log "DRY-RUN: would run: yum/dnf install -y ${pkgname}*"
        log "DRY-RUN: would run: gitlab-ctl reconfigure && gitlab-ctl restart && gitlab-ctl status"
        return 0
    fi

    if ! pkg_available "$pkgname"; then
        log "Package ${pkgname} not found in configured repos. Aborting."
        return 1
    fi

    if command -v yum >/dev/null 2>&1; then
        log "Installing ${pkgname} with yum"
        if ! yum install -y "${pkgname}*" >>"$LOGFILE" 2>&1; then
            log "Failed to install ${pkgname}. See $LOGFILE"
            return 1
        fi
    else
        log "Installing ${pkgname} with dnf"
        if ! dnf install -y "${pkgname}*" >>"$LOGFILE" 2>&1; then
            log "Failed to install ${pkgname}. See $LOGFILE"
            return 1
        fi
    fi

    log "Running gitlab-ctl reconfigure"
    if ! gitlab-ctl reconfigure >>"$LOGFILE" 2>&1; then
        log "gitlab-ctl reconfigure failed — check $LOGFILE"
        return 1
    fi

    log "Restarting GitLab services"
    if ! gitlab-ctl restart >>"$LOGFILE" 2>&1; then
        log "gitlab-ctl restart returned non-zero"
        return 1
    fi

    log "Checking GitLab status"
    if ! gitlab-ctl status >>"$LOGFILE" 2>&1; then
        log "gitlab-ctl status returned non-zero"
        return 1
    fi

    return 0
}

# Iterate through versions
EXIT_CODE=0
for version in "$@"; do
    if ! install_and_reconfigure "$version"; then
        log "Failed to process version $version"
        EXIT_CODE=1
        break
    fi
done

log "Upgrade run completed (exit=$EXIT_CODE). Log: $LOGFILE"
exit $EXIT_CODE
