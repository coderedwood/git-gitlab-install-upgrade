#Install Postfix dependency for GitLab-CE
install_postfix(){
    $SUDO dnf update
    $SUDO dnf install postfix -y
    $SUDO systemctl enable --now postfix
}

#Install Gitlab
install_gitlab(){
    curl -O https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh
    chmod +x script.rpm.sh
    os=el dist=8 ./script.rpm.sh
    $SUDO dnf install gitlab-ce-${VERSION} -y
}

#Add exceptions to http and https ports
enable_web(){
    $SUDO firewall-cmd --permanent --add-service=http
    $SUDO firewall-cmd --permanent --add-service=https
    $SUDO systemctl reload firewalld
}

# Check if version is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 17.8.2"
    exit 1
fi

VERSION=$1

# Determine if sudo is needed
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

#Main script
install_postfix
install_gitlab
enable_web
echo "Installation complete, please configure the gitlab.rb file manually"