##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############
# Uncomment and comment accordingly lines 30-31 or lines 32 for version specific source
# Line 32 pulls a larger directory vs pulling a release tag via lines 30-31
####################### Get Git via release tag via http #########################################
TAG=$(curl -s https://api.github.com/repos/git/git/tags | grep -i "name" | awk -F '"' '{print $4}' | head -n 1)
download_git(){
echo "Fetching the latest Git release"
curl -L "https://github.com/git/git/archive/refs/tags/${TAG}.tar.gz" -o "git-${TAG}.tar.gz"
}
extract_git(){
echo "Extracting tar file";
tar -xzvf "git-${TAG}.tar.gz"
rm -rf git*tar.gz
}
####################### Build Git from Source Section ############################################
clone_git(){
echo "cloning git project from master repository since base git is installed from dependecnies";
git clone https://github.com/git/git.git;
}
install_git(){
echo "Changing Diractory";
cd git*/;
echo "Building from source files";
make configure;
./configure --prefix=/usr/local;
sudo make all && sudo make install;
}

#Main routine
download_git;
extract_git;
#clone_git;
install_git;