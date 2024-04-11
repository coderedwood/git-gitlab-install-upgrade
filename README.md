# git-install-upgrade
This is a set of simple scripts for use with CentOS / Oracle Linux /RedHat for building git from source
This was done as part of a project to install a self-managed instance of Gitlab Community edition.

## Indvidual purpose scripts
- dependencies.sh (Installs dependencies for building git from source code)
- git-install-upgrade.sh (Fetches latest git source code, compiles and installs)
- install-gitlab.sh (Installs Gitlab official repository and install Gitlab Community Edition)

## Installation solution from scratch (Combines all above steps)
- optimised_install.sh (Installs Dependencies, Git and Gitlab)

## Post installation steps for Gitlab
See GitLab documentation
[Omnibus Installation](https://docs.gitlab.com/omnibus/)
[Gitlab Next Steps](https://docs.gitlab.com/ee/install/next_steps.html)