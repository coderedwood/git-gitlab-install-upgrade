# git-install-upgrade
This is a set of simple scripts for use with CentOS / Oracle Linux /RedHat for building git from source
This was done as part of a project to install a self-managed instance of Gitlab Community edition.

## Indvidual purpose scripts
- dependencies.sh (Installs dependencies for building git from source code)
- git-install-upgrade.sh (Fetches latest git source code, compiles and installs)
- install-gitlab.sh (Installs Gitlab official repository and install Gitlab Community Edition)

## Installation solution from scratch (Combines all above steps)
- optimised_install.sh (Installs Dependencies, Git and Gitlab)

## Upgrading your gitlab installation
### Before upgrading please see the documentation on upgrading gitlab for the pre-upgrade steps.

To upgrade existing gitlab installations for the most optimised paths please use the [Gitlab Upgrade Path Toolbox](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/).

After entering your currently installed gitlab version and selecting the appropriate options, make a note of the versions in order.

After that you may execute the script with all the versions separated by a single space. See example below for a 3 version upgrade. You can enter all the required versions for your specific path.

```
sudo .\upgrade-gitlab.sh 10.1.2 11.6.4 12.4.4  
```

## Post installation steps for Gitlab
See GitLab documentation
[Omnibus Installation](https://docs.gitlab.com/omnibus/)
[Gitlab Next Steps](https://docs.gitlab.com/ee/install/next_steps.html)