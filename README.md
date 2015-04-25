# satoris-bash-cheats
Bash scripts for working with IDX repositories.

## Setting up your environment
The script `git-env` will set environment variables; specifically:
* WORKDIR - the location of the local git repositories
* IDX_V1_PROJECTS - list of IDX V1 repositories
* IDX_V2_VERTICALS - list of IDX V2 verticals (applications only)
* IDX_V2_PROJECTS - list of IDX V2 repos (including shared library repos)
* IDX_PROJECTS - list of V1 and V2 verticals (applications only)
* IDX_ALL - list of all IDX repos (including shared library repos)

To use the script, copy it to `~/bin/git-env` and edit the WORKDIR to point to the desired work directory. Add the following to your `~/.bashrc` file:
```
. ~/bin/git-env
```
With the environment variables set, you can clone the repositories via the `git-clone-idx` script:
```
git-clone-idx [[-h|--help]] | [--https|-ssh] [--v2]]
```
