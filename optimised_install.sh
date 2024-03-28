#Install Postfix dependency for GitLab-CE
##########This is a script to install git from source on CentOS 8 / RedHat 8/ Oracle Linux Server 8 ##############;

install_dependecies(){
    echo "Installing Dependencies";
    sudo dnf update
    sudo dnf groupinstall 'Development Tools' -y;
    sudo dnf install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-CPAN perl-devel wget gcc autoconf postfix -y;
    sudo dnf clean all;
    sudo systemctl enable --now postfix;
}

##########This is a script to install git from source on CentOS 8 / RedHat 8 / Oracle Linux Server 8 ##############
install_git(){
    echo "cloning git project from master repository since base git is installed from dependecnies";
    git clone https://github.com/git/git.git;
    echo "Changing Diractory";
    cd git*/;
    echo "Building from source files";
    make configure;
    ./configure --prefix=/usr/local;
    make all && make install;
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
install_git;
install_gitlab;
enable_web;
echo "Installation complete, please configure the gitlab.rb file manually";