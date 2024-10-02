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

        echo "Installed Git version: $git_version"
        echo "Latest Git version: $fetch_version"

        # Compare installed version with the fetched version
        if [ "$(printf '%s\n' "$git_version" "$fetch_version" | sort -V | head -n1)" != "$fetch_version" ]; then
            echo "Updating Git from version $git_version to $fetch_version..."
            download_git
            extract_git
            install_git
            remove_git_folder
            echo "Git has been upgraded to version $fetch_version"
        else
            echo "Git is up-to-date (version $git_version)."
        fi
    else
        echo "Git is not installed. Installing Git..."
        download_git
        extract_git
        install_git
        remove_git_folder
    fi
}


check_background_migrations(){
    echo 'Checking for background migrations'
    sudo gitlab-psql -c "SELECT job_class_name, table_name, column_name, job_arguments FROM batched_background_migrations WHERE status NOT IN(3, 6);"
}

check_gitlab_version(){
    echo 'Checking Gitlab Version'
    sudo grep gitlab-ce /opt/gitlab/version-manifest.txt
}

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
    sudo dnf install -y gitlab-ce-$version

    # Start GitLab service
    sudo gitlab-ctl restart

    # Check GitLab status
    sudo gitlab-ctl status

    # Clean downloaded packages
    sudo dnf clean all
}

# # Iterate through each version passed as argument
# for version in "$@"; do
#     install_gitlab "$version"
# done
upgrade_gitlab(){
# Prompt user for input
echo "Enter the GitLab CE versions you want to install, separated by spaces:"
read -r input_versions

cleaned_versions=$(echo "$input_versions" | tr '=>' ' ')

# Iterate through each version entered by the user
for version in $cleaned_versions; do
    install_gitlab "$version"
done
}

upgrade_git;
check_background_migrations;
check_gitlab_version;
upgrade_gitlab;