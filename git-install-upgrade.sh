##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############
# Uncomment and comment accordingly lines 4 & 5 while lines 7 - 11 for version specific download
# Lines 4 & 5 pulls a larger directory vs pulling a release tag
echo "cloning git project from master repository since base git is installed from dependecnies";
git clone https://github.com/git/git.git;
# echo "Fetching the latest git release";
# wget https://github.com/git/git/archive/refs/tags/v2.39.0.tar.gz;
# echo "Extracting tar file";
# tar xzf v*.tar.gz;
# rm -rf v*tar.gz
echo "Changing Diractory";
cd git*/;
echo "Building from source files";
make configure;
./configure --prefix=/usr/local;
make all && make install;