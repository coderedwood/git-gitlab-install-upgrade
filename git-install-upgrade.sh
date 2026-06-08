#!/usr/bin/env bash
##########This is a script to install git from source on CentOS 7 / RedHat 7 ##############
# Uncomment and comment accordingly lines 30-31 or lines 32 for version specific source
# Line 32 pulls a larger directory vs pulling a release tag via lines 30-31
####################### Get Git via release tag via http #########################################
fetch_git_version(){
TAG=$(curl -s https://api.github.com/repos/git/git/tags | grep -i "name" | awk -F '"' '{print $4}' | head -n 1)
TARBALL="git-${TAG}.tar.gz"
SRCDIR=""

resolve_srctree(){
    if [ -n "$SRCDIR" ] && [ -d "$SRCDIR" ]; then
        return 0
    fi

    if [ -d "git-${TAG}" ]; then
        SRCDIR="git-${TAG}"
        return 0
    fi

    if [[ "$TAG" == v* ]] && [ -d "git-${TAG#v}" ]; then
        SRCDIR="git-${TAG#v}"
        return 0
    fi

    if [ -f "$TARBALL" ]; then
        local candidate
        candidate=$(tar -tzf "$TARBALL" 2>/dev/null | head -n1 | cut -d/ -f1)
        if [ -n "$candidate" ] && [ -d "$candidate" ]; then
            SRCDIR="$candidate"
            return 0
        fi
    fi

    if [[ "$TAG" == v* ]]; then
        local bare_tag="${TAG#v}"
        for candidate in "git-$bare_tag" git-*"$bare_tag"*; do
            if [ -d "$candidate" ]; then
                SRCDIR="$candidate"
                return 0
            fi
        done
    fi

    SRCDIR="git-${TAG}"
}
}

download_git(){
    echo "Fetching the latest Git release: ${TAG}"
    resolve_srctree
    if [ -n "$SRCDIR" ] && [ -d "$SRCDIR" ]; then
        echo "Source directory $SRCDIR already exists. Skipping download."
        return 0
    fi

    if [ -f "$TARBALL" ]; then
        echo "Git tarball $TARBALL already downloaded."
        return 0
    fi

    curl -L "https://github.com/git/git/archive/refs/tags/${TAG}.tar.gz" -o "$TARBALL"
}

extract_git(){
    echo "Extracting tar file"
    resolve_srctree
    if [ -n "$SRCDIR" ] && [ -d "$SRCDIR" ]; then
        echo "Source directory $SRCDIR already exists; skipping extraction"
        return 0
    fi

    tar -xzf "$TARBALL"
    resolve_srctree
}

####################### Build Git from Source Section ############################################
clone_git(){
    echo "cloning git project from master repository since base git is installed from dependencies"
    git clone https://github.com/git/git.git
}

install_git(){
    echo "Changing Directory"
    cd "$SRCDIR" || { echo "Source directory $SRCDIR not found"; exit 1; }
    echo "Building from source files"
    make configure
    ./configure --prefix=/usr/local

    if ${SUDO:+$SUDO }make all && ${SUDO:+$SUDO }make install; then
        echo "Git installed successfully. Cleaning up extracted source directory $SRCDIR and tarball $TARBALL"
        cd ..
        rm -rf "$SRCDIR"
        rm -f "$TARBALL"
    else
        echo "Git installation failed. Preserving source directory $SRCDIR and tarball $TARBALL for debugging."
        return 1
    fi
}

# Determine whether sudo is needed and available
SUDO=''
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO='sudo'
    else
        echo "Warning: sudo not found; continuing without sudo. Ensure you have permissions for /usr/local."
    fi
fi

#Main routine
fetch_git_version;
download_git;
extract_git;
# clone_git;
install_git;
