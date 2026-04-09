#!/bin/bash
set -e

# Installation script for gitlab/gitlab-ce RPM repository
#
# Usage:
#   curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
#
# With authentication:
#   username=myuser password=mypass ./script.rpm.sh

username="${username:-}"
password="${password:-}"

abort_unsupported ()
{
  cat >&2 <<EOF
Platform not supported by this installer.
Override detection: os=el dist=6 ./script.rpm.sh
Documentation: https://docs.gitlab.com/install/
Contact support for help.
EOF
  exit 1
}

detect_system_info ()
{
  [ -n "$os" ] && [ -n "$dist" ] && return 0

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    os=$ID
    case $os in
      poky|sles|opensuse) dist=$VERSION_ID ;;
      opensuse-leap) os=opensuse; dist=$VERSION_ID ;;
      amzn) os=amazon; dist=$VERSION_ID ;;
      rocky|almalinux|rhel|centos) os=el; dist=$(echo "$VERSION_ID" | cut -d. -f1) ;;
      *) dist=$(echo "$VERSION_ID" | cut -d. -f1) ;;
    esac
  elif command -v lsb_release &> /dev/null; then
    dist=$(lsb_release -r | cut -f2 | cut -d. -f1)
    os=$(lsb_release -i | cut -f2 | awk '{print tolower($1)}')
  elif [ -f /etc/oracle-release ]; then
    dist=$(cut -d' ' -f5 /etc/oracle-release | cut -d. -f1)
    os=ol
  elif [ -f /etc/fedora-release ]; then
    dist=$(cut -d' ' -f3 /etc/fedora-release)
    os=fedora
  elif [ -f /etc/redhat-release ]; then
    local hint
    hint=$(head -1 /etc/redhat-release | awk '{print tolower($1)}')
    case $hint in
      centos)
        dist=$(awk '{print $3}' /etc/redhat-release | cut -d. -f1)
        os=centos
        ;;
      scientific)
        dist=$(awk '{print $4}' /etc/redhat-release | cut -d. -f1)
        os=scientific
        ;;
      *)
        dist=$(awk '{print tolower($7)}' /etc/redhat-release | cut -d. -f1)
        os=redhatenterpriseserver
        ;;
    esac
  elif grep -q Amazon /etc/issue 2>/dev/null; then
    dist=6
    os=aws
  else
    abort_unsupported
  fi

  if [ -z "$os" ] || [ -z "$dist" ]; then
    abort_unsupported
  fi
}

should_skip_pygpgme ()
{
  case $os in
    ol|el|rocky|almalinux|centos|rhel)
      [ "$dist" -gt 7 ] 2>/dev/null && return 0
      ;;
    fedora)
      [ "$dist" -gt 19 ] 2>/dev/null && return 0
      ;;
    amazon)
      local major="${dist%%[.-]*}"
      [[ ! " 1 2 2016 2017 2018 " =~ \ $major\  ]] && return 0
      ;;
  esac
  return 1
}

install_optional_deps ()
{
  if ! should_skip_pygpgme; then
    yum install -y pygpgme --disablerepo="gitlab_gitlab-ce" 2>/dev/null || true
  fi

  yum install -y yum-utils --disablerepo="gitlab_gitlab-ce" || true
}

refresh_cache ()
{
  yum -q makecache -y --disablerepo='*' --enablerepo="gitlab_gitlab-ce" 2>/dev/null || true
  yum -q makecache -y --disablerepo='*' --enablerepo="gitlab_gitlab-ce-source" 2>/dev/null || true
}

refresh_zypper ()
{
  zypper --gpg-auto-import-keys refresh "gitlab_gitlab-ce" 2>/dev/null || true
  zypper --gpg-auto-import-keys refresh "gitlab_gitlab-ce-source" 2>/dev/null || true
}

fetch_and_install_repo ()
{
  local url=$1
  local dest=$2
  local curl_opts

  if [ -n "$username" ] && [ -n "$password" ]; then
    curl_opts=(-sSfL -u "${username}:${password}")
  else
    curl_opts=(-sSfL)
  fi

  curl "${curl_opts[@]}" "$url" > "$dest" || {
    local code=$?
    rm -f "$dest"

    case $code in
      22)
        cat >&2 <<EOF
Repository config not available: $url
OS/distribution may not be supported or detection failed.
Try: os=el dist=6 ./script.rpm.sh
See: https://docs.gitlab.com/install/
EOF
        ;;
      35|60)
        cat >&2 <<EOF
TLS error connecting to https://packages.gitlab.com
Check: ca-certificates package, libssl version
EOF
        ;;
      *)
        cat >&2 <<EOF
Failed to download: $url
Verify curl installation.
EOF
        ;;
    esac
    exit 1
  }
}

rpm_import_package_keys ()
{
  local repo_file=$1

  # Currently, seems only to be needed on old Zypper.
  if [ "$os" = "sles" ] && [ "$dist" = "12.5" ]; then
    # extract out known key paths, remove any spaces from the name, and sort them.
    local pubkeys=$(grep pub.gpg "$repo_file" | sed 's/ //g' | sort -u)
    for key in $pubkeys ;
    do
      # instruct RPM to import (thus trust) these keys.
      rpm --import "$key"
      echo "RPM has imported $key"
    done

    echo "The following GitLab signing keys have been trusted:"
    rpm -qa --qf '%{VERSION}-%{RELEASE} %{SUMMARY}\n' gpg-pubkey* | grep -i gitlab
  fi
}

inject_credentials_to_repo_file ()
{
  local repo_file=$1

  if [ -n "$username" ] && [ -n "$password" ]; then
    if [ "$os" = "sles" ] || [ "$os" = "opensuse" ]; then
      sed -i "s|\(baseurl=https://\)\(.*\)|\1${username}:${password}@\2?auth=basic|g" "$repo_file"
    else
      sed -i "s|\(baseurl=https://\)\(.*\)|\1${username}:${password}@\2|g" "$repo_file"
    fi
  fi
}

main ()
{
  detect_system_info

  local repo_url="https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/${os}/${dist}/config_file.repo"
  local repo_dest

  if [ "$os" = "sles" ] || [ "$os" = "opensuse" ]; then
    repo_dest="/etc/zypp/repos.d/gitlab_gitlab-ce.repo"
  else
    repo_dest="/etc/yum.repos.d/gitlab_gitlab-ce.repo"
  fi

  fetch_and_install_repo "$repo_url" "$repo_dest"
  inject_credentials_to_repo_file "$repo_dest"

  if [ "$os" = "sles" ] || [ "$os" = "opensuse" ]; then
    refresh_zypper
    rpm_import_package_keys "$repo_dest"
  else
    install_optional_deps
    refresh_cache
  fi

  cat <<EOF
Repository installed successfully.
Packages are ready to install.
EOF
}

main
