#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Function to install GitLab CE
install_gitlab() {
    local version=$1
    echo "Installing GitLab CE version $version"

    # Replace the URL with the appropriate GitLab CE package URL
    #curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
    sudo yum install -y gitlab-ce-$version

    # Start GitLab service
    sudo gitlab-ctl restart

    # Check GitLab status
    sudo gitlab-ctl status
}

# Iterate through each version passed as argument
for version in "$@"; do
    install_gitlab "$version"
done
