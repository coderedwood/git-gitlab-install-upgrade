#!/usr/bin/env bash
# safer upgrade script for gitlab omnibus packages
# preserves original behaviour but adds preflight checks, backups, dry-run and logging

set -euo pipefail

# Back up the original script if not already backed up
if [ ! -f upgrade-gitlab.sh.orig ]; then
    cp -- upgrade-gitlab.sh upgrade-gitlab.sh.orig || true
fi

LOGFILE="/var/log/gitlab-upgrade-$(date +%Y%m%d%H%M%S).log"
DRY_RUN=0

usage(){
    cat <<USAGE
Usage: $0 [--dry-run] <version1> [version2 ...]

Example: sudo $0 10.1.2 11.6.4 12.4.4

This script will:
 - perform lightweight preflight checks
 - create a backup (if possible) using gitlab-rake
 - attempt to install the specified omnibus package versions in order
 - reconfigure and restart GitLab between versions

Use --dry-run to see planned actions without making changes.
USAGE
}

log(){
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOGFILE"
}

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
    shift
fi

if [ $# -lt 1 ]; then
    usage
    exit 2
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (or via sudo)"
   exit 1
fi

# Preflight checks
log "Starting GitLab upgrade script"

command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1 || { log "No yum/dnf found. Unsupported platform."; exit 3; }
command -v gitlab-ctl >/dev/null 2>&1 || { log "gitlab-ctl not found in PATH. Is GitLab installed?"; exit 4; }

# Check free disk space (simple check on /var)
avail_kb=$(df --output=avail /var | tail -n1 | tr -d ' ')
if [ "$avail_kb" -lt 524288 ]; then
    log "Warning: less than 512MB available on /var. Upgrades may fail. Available KB=$avail_kb"
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

# Helper to check whether a package version is available in repos
pkg_available(){
    local pkg="$1"
    if command -v yum >/dev/null 2>&1; then
        yum --quiet --showduplicates list "$pkg" 2>/dev/null | grep -q "$pkg" || return 1
    elif command -v dnf >/dev/null 2>&1; then
        dnf --quiet --showduplicates list "$pkg" 2>/dev/null | grep -q "$pkg" || return 1
    else
        return 1
    fi
}

# Install and reconfigure step
install_and_reconfigure(){
    local version="$1"
    local pkgname="gitlab-ce-${version}"
    log "Processing version ${version}"

    if [ $DRY_RUN -eq 1 ]; then
        log "DRY-RUN: would check availability of ${pkgname}"
        log "DRY-RUN: would run: yum/dnf install -y ${pkgname}"
        log "DRY-RUN: would run: gitlab-ctl reconfigure && gitlab-ctl restart && gitlab-ctl status"
        return 0
    fi

    if ! pkg_available "$pkgname"; then
        log "Package ${pkgname} not found in configured repos. Aborting."; return 10
    fi

    if command -v yum >/dev/null 2>&1; then
        log "Installing ${pkgname} with yum"
        yum install -y "$pkgname" >>"$LOGFILE" 2>&1
    else
        log "Installing ${pkgname} with dnf"
        dnf install -y "$pkgname" >>"$LOGFILE" 2>&1
    fi

    log "Running gitlab-ctl reconfigure"
    if ! gitlab-ctl reconfigure >>"$LOGFILE" 2>&1; then
        log "gitlab-ctl reconfigure failed — check $LOGFILE"
    fi

    log "Restarting GitLab services"
    gitlab-ctl restart >>"$LOGFILE" 2>&1 || log "gitlab-ctl restart returned non-zero"

    log "Checking GitLab status"
    gitlab-ctl status >>"$LOGFILE" 2>&1 || log "gitlab-ctl status returned non-zero"
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
