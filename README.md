# satoris-bash-cheats
Bash scripts for working with IDX repositories.

## Setting up your environment (legacy scripts)
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

## The 'idx' Bash command-line tool

`idx-source.sh` is a Bash script that defines CLI tools for a *nix environment to help indexing developers navigate and perform useful functions
relating to the indexing GitHub repositories.

### Dependencies

The following tools are required for this script:

Tool | Description
---- | -----------
java | Java virtual machine
mvn | Maven build tool
git | VCS client with authentication to GitHub
gh | GitHub CLI with authentication to GitHub
xmlstarlet | XML processing tool
docker | Container management
pcre | Perl-compatible regex expression language utilities
bash-completion | Bash command completion utilities

### The WORKDIR environment variable

The "WORKDIR" environment variable tells the 'idx' functions the directory where the indexing GitHub repositories are located. 
By default, if the environment variable is not already specified, the script will define it as `$HOME/github`. If your directory 
differs, add the following to your `~/.bashrc` file:

```
export WORKDIR="<your directory for projects>"
```

### Setting up the script

To setup the script for use in your Bash terminal, add the following to your `~/.bashrc` file:

```
source <path to this project directory>/idx-source.sh
```

See "The WORKDIR environment variable" to customize the working directory used by the script. The "WORKDIR" must be specified before the 'scource ...' command
in your `~/.bashrc` file.

### Getting help

To see the list of commands available execute the following:

```
idx --help
```

The script sets up tab-completion for the commands. Use `idx <tab><tab>` to see the list of available commands. 
