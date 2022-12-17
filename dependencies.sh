##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############
echo "Installing Dependencies";
yum groupinstall 'Development Tools' -y;
yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-CPAN perl-devel wget -y;

echo "Installing libraries for compiler-enforced C99 requirements";
yum install centos-release-scl -y;
yum install devtoolset-7-gcc* -y;
yum clean all -y
scl enable devtoolset-7 bash;