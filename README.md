# git-gitlab-install-upgrade
This is a set of simple scripts for use with CentOS / Oracle Linux /RedHat for building git from source
This was done as part of a project to install a self-managed instance of Gitlab Community edition.

## Indvidual purpose scripts
- dependencies.sh (Installs dependencies for building git from source code)
- git-install-upgrade.sh (Fetches latest git source code, compiles and installs)
- install-gitlab.sh (Installs Gitlab official repository and install Gitlab Community Edition)
- upgrade-gitlab.sh (Upgrades the gitlab installation by taking the versions as arguments separated by spaces)

## Installation solution from scratch (Combines all above steps excluding the upgrade)
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
## Usage

The `upgrade-gitlab.sh` script can be used to perform ordered upgrades of Omnibus GitLab packages. Important safety notes:

- Always create a backup before upgrading. The script will attempt a `gitlab-rake gitlab:backup:create` when run without `--dry-run`.
- Test upgrades in a staging environment first.
- The script supports CentOS/RHEL platforms using `yum` or `dnf`.

Basic usage (requires root for real upgrades):

```
sudo ./upgrade-gitlab.sh <version1> [version2 ...]
```

Example (dry-run, does not require root and is safe to run locally):

```
./upgrade-gitlab.sh --dry-run 10.1.2 11.6.4 12.4.4
```

When run with `--dry-run`, the script will skip platform and `gitlab-ctl` checks and will write logs to `./logs/` so it can be run on machines without GitLab installed.

## Testing

There is a simple smoke test to validate the `--dry-run` path. Run it locally from the repository root:

```bash
chmod +x tests/test-dry-run.sh
./tests/test-dry-run.sh
```

To run this test in CI (recommended):

- Add a job that checks out the repo, makes the test executable, and runs `./tests/test-dry-run.sh`.
- The `--dry-run` mode is designed to be safe to run in CI without root or GitLab installed.

If you'd like, I can add a GitHub Actions workflow that runs this smoke test on pull requests.
