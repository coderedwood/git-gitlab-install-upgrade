#Install Postfix (a gitlab dependency) and devel dependencies (to compile git from source) for GitLab-CE
install_dependecies(){
    echo "Installing Dependencies";
    sudo dnf update
    sudo dnf groupinstall 'Development Tools' -y;
    sudo dnf install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-CPAN perl-devel wget gcc autoconf postfix -y;
    sudo dnf clean all;
    sudo systemctl enable --now postfix;
}

##########This is a script to fetch git from github source via curl on CentOS 8 / RedHat 8 / Oracle Linux Server 8 ##############
fetch_git_curl(){
    TAG=$(curl -s https://api.github.com/repos/git/git/tags | grep -i "name" | awk -F '"' '{print $4}' | head -n 1)
    echo "Fetching the latest Git release"
    curl -L "https://github.com/git/git/archive/refs/tags/${TAG}.tar.gz" -o "git-${TAG}.tar.gz"
    echo "Extracting tar file";
    tar -xzvf "git-${TAG}.tar.gz"
    rm -rf git*tar.gz
}

##########This is a script to fetch git from github source via git clone on CentOS 8 / RedHat 8 / Oracle Linux Server 8 ##############
fetch_git_clone(){
    echo "cloning git project from master repository since base git is installed from dependecnies";
    git clone https://github.com/git/git.git;
}

##########This is a script to install git from the pulled github source on CentOS 8 / RedHat 8 / Oracle Linux Server 8 ##############
install_git(){
    echo "Changing Diractory";
    cd git*/;
    echo "Building from source files";
    make configure;
    ./configure --prefix=/usr/local;
    sudo make all && sudo make install;
}

#Install Gitlab Repositories and Gitlab-ce
install_gitlab(){
    curl -O https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh;
    chmod +x script.rpm.sh;
    os=el dist=8 ./script.rpm.sh;
    sudo dnf install gitlab-ce -y;
}

#Add exceptions to http and https ports
enable_web(){
    sudo firewall-cmd --permanent --add-service=http;
    sudo firewall-cmd --permanent --add-service=https;
    sudo systemctl reload firewalld;
}

#Main script procedure
install_dependecies;
# fetch_git_curl
fetch_git_clone
install_git;
install_gitlab;
enable_web;
echo "Installation complete, please configure the gitlab.rb file manually";