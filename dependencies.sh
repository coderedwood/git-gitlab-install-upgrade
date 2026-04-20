##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############;
echo "Installing Dependencies";
yum groupinstall 'Development Tools' -y;
yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-CPAN perl-devel wget gcc autoconf -y;
yum clean all;