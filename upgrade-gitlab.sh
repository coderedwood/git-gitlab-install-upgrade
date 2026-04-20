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

run_and_log(){
    local cmd=("$@")
    local cmd_desc status
    cmd_desc="$(printf ' %q' "${cmd[@]}")"
    log "Executing:${cmd_desc}"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "DRY-RUN: would run:${cmd_desc}"
        return 0
    fi

    if command -v script >/dev/null 2>&1; then
        if script -q -c "${cmd[*]}" /dev/null 2>&1 | tee -a "$LOGFILE"; then
            status=0
        else
            status=${PIPESTATUS[0]}
            log "Interactive capture via script failed with status ${status}; falling back to direct output"
            if "${cmd[@]}" 2>&1 | tee -a "$LOGFILE"; then
                status=0
            else
                status=${PIPESTATUS[0]}
            fi
        fi
    else
        if "${cmd[@]}" 2>&1 | tee -a "$LOGFILE"; then
            status=0
        else
            status=${PIPESTATUS[0]}
        fi
    fi

    return "$status"
}

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
    shift
fi

# Handle versions separated by "=>" if passed as a single argument or across multiple args
NEEDS_NORMALIZE=0
for arg in "$@"; do
    if [ "$arg" = "=>" ] || [[ "$arg" == *"=>"* ]]; then
        NEEDS_NORMALIZE=1
        break
    fi
done

if [ "$NEEDS_NORMALIZE" -eq 1 ]; then
    VERSIONS=()
    for arg in "$@"; do
        if [ "$arg" = "=>" ]; then
            continue
        fi
        arg="${arg//=>/ }"
        for version in $arg; do
            VERSIONS+=("$version")
        done
    done
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
    log "DRY-RUN: running in dry-run mode"
    log "DRY-RUN: skipping platform package manager and gitlab-ctl checks"
else
    log "Checking required tools: yum/dnf and gitlab-ctl"
    command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1 || { log "No yum/dnf found. Unsupported platform."; exit 3; }
    command -v gitlab-ctl >/dev/null 2>&1 || { log "gitlab-ctl not found in PATH. Is GitLab installed?"; exit 4; }
    log "Found required tools and confirmed GitLab is installed"
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
        if ! run_and_log gitlab-rake gitlab:backup:create; then
            log "Backup command failed — continuing cautiously. Check $LOGFILE"
        else
            log "GitLab backup completed successfully"
        fi
    else
        log "gitlab-rake not available; skipping automated backup. Make sure you have a manual backup."
    fi
fi

detect_package_type(){
    log "Detecting installed GitLab package type"
    if [ "$DRY_RUN" -eq 1 ]; then
        PACKAGE_TYPE="gitlab-ce"
        log "DRY-RUN: assuming installed GitLab package type ${PACKAGE_TYPE}"
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

log "Versions to process: $*"

# Helper to check whether a package version is available in repos
pkg_available(){
    local pkg="$1"
    local basepkg version
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    log "Checking availability of package ${pkg}"
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
        if yum --quiet list available "${pkg}*" 2>/dev/null | grep -qE "^${basepkg}(\.[^[:space:]]+)?[[:space:]]+${version}([-.]|$)"; then
            return 0
        fi
        yum --quiet list available "${basepkg}" 2>/dev/null | awk '{print $1, $2}' | grep -qE "^${basepkg}(\.[^[:space:]]+)?[[:space:]]+${version}([-.]|$)" || return 1
    elif command -v dnf >/dev/null 2>&1; then
        if dnf --quiet list available "${pkg}*" 2>/dev/null | grep -qE "^${basepkg}(\.[^[:space:]]+)?[[:space:]]+${version}([-.]|$)"; then
            return 0
        fi
        dnf --quiet list available "${basepkg}" 2>/dev/null | awk '{print $1, $2}' | grep -qE "^${basepkg}(\.[^[:space:]]+)?[[:space:]]+${version}([-.]|$)" || return 1
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
        log "DRY-RUN: would complete processing version ${version}"
        return 0
    fi

    if ! pkg_available "$pkgname"; then
        log "Package ${pkgname} not found in configured repos. Aborting."
        return 1
    fi
    log "Package ${pkgname} is available in configured repos"

    if command -v yum >/dev/null 2>&1; then
        log "Installing ${pkgname} with yum"
        if ! run_and_log yum install -y "${pkgname}*"; then
            log "Failed to install ${pkgname}. See $LOGFILE"
            return 1
        fi
        log "Cleaning yum package cache after install"
        run_and_log yum clean packages
    else
        log "Installing ${pkgname} with dnf"
        if ! run_and_log dnf install -y "${pkgname}*"; then
            log "Failed to install ${pkgname}. See $LOGFILE"
            return 1
        fi
        log "Cleaning dnf package cache after install"
        run_and_log dnf clean packages
    fi
    log "Installation of ${pkgname} completed"

    log "Applying SELinux workaround before reconfigure"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "DRY-RUN: would patch selinux recipe and disable enforcement"
    else
        run_and_log bash -lc 'if ! grep -q "not_if { true }" /opt/gitlab/embedded/cookbooks/gitlab/recipes/selinux.rb; then sed -i "/bash \"Set proper security context on ssh files for selinux\" do/a \\  not_if { true }" /opt/gitlab/embedded/cookbooks/gitlab/recipes/selinux.rb; fi'
        run_and_log setenforce 0 || log "setenforce failed or is not available; continuing"
    fi

    log "Running gitlab-ctl reconfigure"
    local reconfigure_attempts=3
    local reconfigure_success=0
    for attempt in $(seq 1 "$reconfigure_attempts"); do
        log "Reconfigure attempt $attempt of $reconfigure_attempts"
        if run_and_log gitlab-ctl reconfigure; then
            reconfigure_success=1
            break
        else
            log "gitlab-ctl reconfigure attempt $attempt failed"
            if [ "$attempt" -lt "$reconfigure_attempts" ]; then
                log "Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    if [ "$reconfigure_success" -eq 0 ]; then
        log "All reconfigure attempts failed"
        return 1
    fi
    log "gitlab-ctl reconfigure completed"

    log "Restarting GitLab services"
    local restart_attempts=3
    local restart_success=0
    for attempt in $(seq 1 "$restart_attempts"); do
        log "Restart attempt $attempt of $restart_attempts"
        if run_and_log gitlab-ctl restart; then
            restart_success=1
            break
        else
            log "gitlab-ctl restart attempt $attempt failed"
            if [ "$attempt" -lt "$restart_attempts" ]; then
                log "Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    if [ "$restart_success" -eq 0 ]; then
        log "All restart attempts failed; proceeding to status check"
    fi
    log "GitLab services restart completed"

    log "Checking GitLab status"
    local status_attempts=5
    local status_success=0
    for attempt in $(seq 1 "$status_attempts"); do
        log "Status check attempt $attempt of $status_attempts"
        if run_and_log gitlab-ctl status; then
            status_success=1
            break
        else
            log "gitlab-ctl status attempt $attempt returned non-zero (some services may still be starting)"
            if [ "$attempt" -lt "$status_attempts" ]; then
                log "Waiting 5 seconds before retry..."
                sleep 5
            fi
        fi
    done
    if [ "$status_success" -eq 0 ]; then
        log "Status checks failed after $status_attempts attempts"
        return 1
    fi
    log "GitLab status check completed for version ${version}"

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

upgrade_git;
check_background_migrations;
check_gitlab_version;
upgrade_gitlab;