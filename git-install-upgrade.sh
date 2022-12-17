##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############
echo "Installing Dependencies";
yum groupinstall 'Development Tools' -y;
yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-CPAN perl-devel wget -y;

echo "Fetching the latest git release"
wget https://github.com/git/git/archive/refs/tags/v2.39.0.tar.gz;

echo "Extracting tar file";
tar xzf v*.tar.gz;

echo "Changing Diractory";
rm -rf v*tar.gz
cd git*;

echo "Building from source files";
make configure;
./configure --prefix=usr/local;
make all;
make install;