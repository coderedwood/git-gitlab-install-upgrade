##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############
# Uncomment and comment accordingly lines 4 & 5 while lines 7 - 11 for version specific download
# Line 13 pulls a larger directory vs pulling a release tag via lines 5-7
####################### Get Git via release tag via http #########################################
# TAG=$(curl -s https://api.github.com/repos/git/git/tags | grep -i "name" | awk -F '"' '{print $4}' | head -n 1)
# echo "Fetching the latest git release"
# curl -OJL "https://github.com/git/git/archive/refs/tags/${TAG}.tar.gz"
# echo "Extracting tar file";
# tar xzfv v*.tar.gz;
# rm -rf v*tar.gz
####################### Build Git from Source Section ############################################
echo "cloning git project from master repository since base git is installed from dependecnies";
git clone https://github.com/git/git.git;
echo "Changing Diractory";
cd git*/;
echo "Building from source files";
make configure;
./configure --prefix=/usr/local;
make all && make install;