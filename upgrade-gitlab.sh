#!/bin/bash
# Dependencies
# latest version of git
# postgres version requirement per release of gitlab in release tree

# Steps
# Check for background processes
# Check which version of gitlab is installed
# Check glib version
# Back up Postgres Database
# Back up gitlab instance for version 
# Bring down gitlab instance
# Check which version of git is installed, install latest if not latest
# Install gitlab versions as per release tree

# Source the script with the function definitions
source ./git-install-upgrade.sh

# Function to upgrade Git
upgrade_git() {
    if command -v git >/dev/null 2>&1; then
        git_version=$(git --version | awk '{print $3}')
        fetch_version=$(fetch_git_version)

        # Compare versions using a helper function or tool
        if [ "$(printf '%s\n' "$fetch_version" "$git_version" | sort -V | head -n1)" != "$git_version" ]; then
            download_git
        else
            echo "Git is up-to-date."
        fi
    else
        echo "Git is not installed."
    fi
}


# check_background_migrations(){
#     echo 'Checking for background migrations'
#     sudo gitlab-rake gitlab:elastic:list_pending_migrations
# }

# check_gitlab_version(){
#     echo 'Checking Gitlab Version'
#     sudo grep gitlab-ce /opt/gitlab/version-manifest.txt
# }

# # Check if running as root
# if [[ $EUID -ne 0 ]]; then
#    echo "This script must be run as root"
#    exit 1
# fi

# # Function to install GitLab CE
# install_gitlab() {
#     local version=$1
#     echo "Installing GitLab CE version $version"

#     # Replace the URL with the appropriate GitLab CE package URL
#     #curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
#     sudo yum install -y gitlab-ce-$version

#     # Start GitLab service
#     sudo gitlab-ctl restart

#     # Check GitLab status
#     sudo gitlab-ctl status
# }

# # Iterate through each version passed as argument
# for version in "$@"; do
#     install_gitlab "$version"
# done
