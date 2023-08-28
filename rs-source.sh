#!/bin/bash

export RS_SOURCE_VERSION=0.1.1

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# Records Storage repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR="${WORKDIR:-$HOME/github}"

# Maintain order!
export RS_INTERFACE_PROJECTS="cds-browser cds-export cds-publish-dates cds-spark-ami cds-ui-web sls-bulk-export sls-contextual-treatments slsdata-convert slsdata-gedcomx slsdata-treatments sls-spark-jobs"
export RS_TEMPLATES_PROJECTS="sls-client-utils slsdata-gedcomx-lite sls-fixup-worker sls-model sls-templates sls-template-store sls-test-utils"
export RS_INTERNALS_PROJECTS="sls-dlq-worker sls-internal-messaging sls-internal-workers sls-reconcile sls-sqs-worker sls-web-app"
export RS_PERSISTENCE_PROJECTS="cds2-root gedcomx-builder recapi sls-consumers sls-persistence"
export RS_PROJECTS="${RS_INTERFACE_PROJECTS} ${RS_TEMPLATES_PROJECTS} ${RS_INTERNALS_PROJECTS} $RS_PERSISTENCE_PROJECTS"

# Variables used for command completion
export RS_COMMAND_LAZY="root consumers persistence"
export RS_COMMANDS="$RS_PROJECTS status update reset-master branch build clone $RS_COMMAND_LAZY"
export RS_OPTIONS="-h --help"

export GITHUB_BASE="https://github.com"
export GITHUB_FS_BASE="$GITHUB_BASE/fs-eng"

COLOR_LT_BLUE='\e[1;34m'
COLOR_LT_GREEN='\e[1;32m'
COLOR_LT_RED='\e[1;31m'
COLOR_RED='\e[0;31m'
COLOR_NONE='\e[0m'

rsRootUsage() {
  cat <<-EOF
USAGE: rs [all] [[-h|--help]] <command>

COMMANDS:
  all                 Recursively execute the command in each of the projects

  cds-browser              Change the CWD to the project (Interface)
  cds-export                  "
  cds-publish-dates           "
  cds-spark-ami               "
  cds-ui-web                  "
  sls-bulk-export             "
  sls-contextual-treatments   "
  slsdata-convert             "
  slsdata-gedcomx             "
  slsdata-treatments          "
  sls-spark-jobs              "

  sls-client-utils        Change the CWD to the project (Templates)
  slsdata-gedcomx-lite        "
  sls-fixup-worker            "
  sls-model                   "
  sls-templates               "
  sls-template-store          "
  sls-test-utils              "

  sls-dlq-worker          Change the CWD to the project (Internals)
  sls-internal-messaging      "
  sls-internal-workers        "
  sls-reconcile               "
  sls-sqs-worker              "
  sls-web-app                 "

  cds2-root               Change the CWD to the project (Persistence; lazy: "root")
  gedcomx-builder             "
  recapi                      "
  sls-consumers               " (lazy: "consumers")
  sls-persistence             " (lazy: "persistence")

  status                Check the git status of the repository.
  update                Update the repository.
  branch                Report on the repository's branches.
  reset-master          Force a reset of the local master branch to the remote branch.
  build                 Build the repository.
  clone                 Clone github repositories.

OPTIONS:
  -h | --help           Display this help. If a command follows, command-
                        specific help is displayed.
DEPENDENCIES:
  java                  Virtual machine
  git                   git VCS tool with authentication to GitHub
  gh                    GitHub CLI with authentication to GitHub
  xmlstarlet            XML processing tool
  mvn                   Maven build tool
  pcre                  Pearl-compatible regex expression language utilities
  bash-completion       Bash command completion utility

ERRORS:
  If an error occurs the script will exit with '1' and RS_ERROR will contain
  detail information as to where in the script the error occurs.

EOF
}

currentBranch() {
  git branch | grep "\*" | cut -d" " -f2
}

cdToProject-usage() {
  cat <<-EOF
USAGE: rs <project>

Change the current working directory to the root of the project.

OPTIONS: <project>      name of the GitHub project
EOF
}

cdToProject() {
  case "$1" in
    -h | --help)
      cdToProject-usage
      RS_ERROR="cdToProject - command help"
      return
      ;;
    *)
      ;;
  esac

  PROJECT="$1"

  if [ ! -d "$WORKDIR/$PROJECT" ]; then
    rsRootUsage
    echo " Error: Project directory for $PROJECT does not exist."
    RS_ERROR="cdToProject"
    return
  fi
  cd "$WORKDIR/$PROJECT" || {
    RS_ERROR="cdToProject"
    echo "Failed to 'cd' to $WORKDIR/$PROJECT"
    return 1
  }
}

rs-status-usage() {
  cat <<-EOF
USAGE: rs status

Report on the 'git-status' of the repository.
EOF
}

rs-status() {
  case "$1" in
    -h | --help)
      rs-status-usage
      RS_ERROR="rs-status - command help"
      return
      ;;
    *)
      ;;
  esac

  local result
  local prefix
  local postfix

  result=$(git status)

  if [[ $result != *"master"* ]]; then
    prefix=${COLOR_LT_GREEN}
    postfix=${COLOR_NONE}
  elif [[ $result != *"up-to-date"* ]]; then
    prefix=${COLOR_LT_BLUE}
    postfix=${COLOR_NONE}
  fi
  echo -e "$prefix$result$postfix"
}

rs-update-usage() {
  cat <<-EOF
USAGE: rs update [[-c | --clean-merged]]

Updates the 'master' branch of the repository. Checks out the 'master'
branch if it is not currently checked out and performs a 'git pull' request.

OPTIONS:
-c | --clean-merged   removes local tracked branches that have been
                      merged into 'master'.
EOF
}

_rs-update() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-c --clean-merged" -- "$cur"))
}

rs-update() {
  local rs_status_clean_merged=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-update-usage
        RS_ERROR="rs-update - command help"
        return
        ;;
      -c | --clean-merged)
        rs_status_clean_merged=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        rs-update-usage
        RS_ERROR="rs-reset-master - options"
        return
        ;;
    esac
  done

  git checkout master
  git pull

  if $rs_status_clean_merged ; then
    local merged
    merged="$(git branch --merged | grep -v master)"
    for b in $merged; do
      git branch -d "$b"
    done
  fi
}

rs-reset-master-usage() {
  cat <<-EOF
USAGE: rs reset-master

Force a deletion of the local master branch and recreate it from the remote
master branch. Useful if the local master is accidentally modified.
EOF
}

rs-reset-master() {
  case "$1" in
    -h | --help)
      rs-reset-master-usage
      RS_ERROR="rs-reset-master - command help"
      return
    ;;
  *)
    ;;
  esac

  local modified_count

  modified_count="$(git status --porcelain=2 | wc -l)"

  if [[ "$modified_count" -gt 0 ]]; then
    echo ERROR: Local branch has uncommitted changes! Commit or stash the changes and re-run.
    RS_ERROR="rs-reset-master"
    return
  fi

  git fetch origin
  git branch --move --force master killme
  git branch --track master origin/master
  git checkout master
  git branch --delete --force killme
}

rs-branch-usage() {
  cat <<-EOF
USAGE: rs branch [[-a | all] [-c | --current] [-m | --merged] [-n | --no-merged]
                   [-r | --remotes] [-f | --filter-pr]]

Report on the repository's branches.

OPTIONS:
  -a | --all          Report on all branches (local and remote).
  -c | --current      Report on the current branch only.
  -m | --merged       Report on branches merged into the current branch only.
  -n | --no-merged    Report on branches not merged into the current branch only.
  -r | --remotes      Report on remote branches.
  -f | --filter-pr    Filter out local and remote 'pr' branches.
EOF
}

_rs-branch() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -c --current -m --merged -n --no-merged -r --remotes -f --filter-pr" -- "$cur"))
}

rs-branch() {
  local current=false
  local filterpr=false
  local options=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-branch-usage
        RS_ERROR="rs-reset-master - command help"
        return
        ;;
      -a | --all)
        options+=("--all")
        shift
        ;;
      -c | --current)
        current=true
        shift
        ;;
      -m | --merged)
        options+=("--merged")
        shift
        ;;
      -n | --no-merged)
        options+=("--no-merged")
        shift
        ;;
      -r | --remotes)
        options+=("--remotes")
        shift
        ;;
      -f | --filter-pr)
        filterpr=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        rs-branch-usage
        RS_ERROR="rs-reset-master - options"
        return
        ;;
    esac
  done

  if $current; then
    local prefix
    local postfix
    local current_branch

    current_branch="$(currentBranch)"

    if [[ "$current_branch" == "master" ]]; then
      prefix=${COLOR_LT_GREEN}
      postfix=${COLOR_NONE}
    else
      prefix=${COLOR_LT_RED}
      postfix=${COLOR_NONE}
    fi
    echo -e $prefix$current_branch$postfix
  elif $filterpr; then
    git -P branch "${options[@]}" | grep -v -P -e "^\s*((remotes/)?origin/)?pr/\d+"
  else
    git -P branch "${options[@]}"
  fi
}

_rs-clone() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -d --delete" -- "$cur"))
}

rs-clone-usage() {
  cat <<-EOF
USAGE rs clone [[-a | --all] | [-d | --delete] | [--interface] | [--internals] | [--templates] | [--persistence]] <repo name(s)>

Clone the github repositories specified by the space-delimited list of repository names.
The new local repository will be cloned into the 'WORKDIR' directory.

OPTIONS:
  -a | --all	  Clone all rs repositories.
  -d | --delete	Delete the existing repository before cloning.
  --interface   Clone all Interface repositories
  --internals   Clone all Internals repositories
  --templates   Clone all Templates repositories
  --persistence Clone all Persistence repositories
EOF
}

rs-clone-repo() {
  local repo="$1"
  local url="$GITHUB_FS_BASE/$repo.git"
  echo -e Cloning fs-eng repository ${COLOR_RED}$url${COLOR_NONE}
  git clone "$url"
}

rs-clone() {
  local delete_repo=false
  local repositories

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-clone-usage
        RS_ERROR="rs-clone - command help"
        return
        ;;
      -a | --all)
        shift
        repositories="$RS_PROJECTS"
        ;;
      -d | --delete)
        shift
        delete_repo=true
        ;;
      --interface)
        repositories="$RS_INTERFACE_PROJECTS"
        shift
        ;;
      --internals)
        repositories="$RS_INTERNALS_PROJECTS"
        shift
        ;;
      --templates)
        repositories="$RS_TEMPLATES_PROJECTS"
        shift
        ;;
      --persistence)
        repositories="$RS_PERSISTENCE_PROJECTS"
        shift
        ;;
      *)
        repositories="$repositories $1"
        shift
        ;;
    esac
  done

  pushd $WORKDIR >/dev/null || exit

  for repo in $repositories; do
    if [[ -d $repo ]]; then
      if $delete_repo; then
        echo -e Deleting ${COLOR_RED}$repo${COLOR_NONE}...
        rm -rf $repo
        rs-clone-repo $repo
      else
        echo -e Skipping exisiting repository ${COLOR_RED}$repo${COLOR_NONE}
      fi
    else
      rs-clone-repo $repo
    fi
  done

  popd >/dev/null || exit
}

isDirectoryClean() {
  git diff-index --quiet HEAD --
}

_rs-build() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k --keep-existing -l --local-m2-repository -a --acceptance-test -s --server" -- "$cur"))
}

rs-build-usage() {
  cat <<-EOF
USAGE: rs build [[-k | --keep-existing] [-r | --local-m2-repository]]

Build the local repository. (By default, this will clean the build directory
then perform a 'mvn install' command.

OPTIONS:
  -k | --keep-existing        Keep the existing build files (no Maven 'clean' goal is used).
  -l | --local-m2-repository  Use a local M2 repository ('target/m2-repo').
EOF
}

rs-build() {
  local mvn_clean=true
  local local_m2_repository=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-build-usage
        RS_ERROR="rs-build - command help"
        return
        ;;
      -k | --keep-existing)
        shift
        mvn_clean=false
        ;;
      -l | --local-m2-repository)
        shift
        local_m2_repository=true
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        rs-build-usage
        RS_ERROR="rs-build - options"
        return
        ;;
    esac
  done

  if [[ -f pom.xml ]]; then
    if $mvn_clean; then
      mvn clean
    fi

    if [[ $? -eq 0 ]]; then
      local options="install"
      if [[ $local_m2_repository == true ]]; then
        options="-Dmaven.repo.local=target/m2-repo $options"
      fi
      mvn $options

      if [[ $? -gt 0 ]]; then
        RS_ERROR="rs-build"
        return 1
      fi
    else
      RS_ERROR="rs-build clean"
      return 1
    fi
  fi
}

_rs-all() {
  local i=1 subcommand_index

  while [[ $i -lt $COMP_CWORD ]]; do
    local s="${COMP_WORDS[i]}"
    case "$s" in
      -h | --help)
        subcommand_index=$i
        break
        ;;
      status)
        subcommand_index=$i
        break
        ;;
      update)
        subcommand_index=$i
        break
        ;;
      branch)
        subcommand_index=$i
        break
        ;;
      reset-master)
        subcommand_index=$i
        break
        ;;
      build)
        subcommand_index=$i
        break
        ;;
    esac
    (( i++ ))
  done

  while [[ $subcommand_index -lt $COMP_CWORD ]]; do
    local s="${COMP_WORDS[subcommand_index]}"
    case "$s" in
      -h | --help)
        COMPREPLY=()
        return
        ;;
      status)
        _rs-status
        return
        ;;
      update)
        _rs-update
        return
        ;;
      branch)
        _rs-branch
        return
        ;;
      build)
        _rs-build
        return
        ;;
      reset-master)
        COMPREPLY=()
        return
        ;;
    esac
    (( subcommand_index++ ))
  done

  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-h --help status update branch reset-master build " -- "$cur"))
}

rs-all-usage() {
  cat <<-EOF
USAGE: rs all [[--interface] | [--internals] | [--templates] | [--persistence]] <command>

Recursively execute <command> on all of the rs projects.

OPTIONS:
  --interface     Execute command against Interface repositories
  --internals     Execute command against Internals repositories
  --templates     Execute command against Templates repositories
  --persistence   Execute command against Persistence repositories

SUPPORTED COMMANDS:
  status
  update
  branch
  build
  reset-master

EOF
}

rs-all() {
  local projects
  projects="$RS_PROJECTS"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-all-usage
        RS_ERROR="rs-all - command help"
        return
        ;;
      --interface)
        projects="$RS_INTERFACE_PROJECTS"
        shift
        break
        ;;
      --internals)
        projects="$RS_INTERNALS_PROJECTS"
        shift
        break
        ;;
      --templates)
        projects="$RS_TEMPLATES_PROJECTS"
        shift
        break
        ;;
      --persistence)
        projects="$RS_PERSISTENCE_PROJECTS"
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  pushd . >/dev/null

  for dir in $projects; do
    echo ========================
    echo PROJECT - "$dir"
    cd "$WORKDIR/$dir" || {
      RS_ERROR="rs-all"
      echo "Failed to 'cd' to $WORKDIR/$PROJECT"
      return 1
    }
    rs "$@"
    if [ -n "$RS_ERROR" ]; then
      break
    fi
  done
  popd >/dev/null || {
    RS_ERROR="rs-all"
    echo "Failed to return to starting directory"
    return 1
  }

}

rs() {
  local project
  local helpargs
  unset -v RS_ERROR

  # validate there is a valid WORKDIR
  if [ ! -d "$WORKDIR" ]; then
    rsRootUsage
    echo " Error: WORKDIR does not exist or is not a directory."
    return 1
  fi

  while [ $# -ge 0 ]; do
    case "$1" in
    -h | --help)
      helpargs+="$1"
      shift
      ;;
    all)
      shift
      rs-all "$@"
      break
      ;;
    # lazy project names
    cds2-root | root)
      project=${project:-cds2-root}
      ;&
    sls-consumers | consumers)
      project=${project:-sls-consumers}
      ;&
    sls-persistence | persistence)
     project=${project:-sls-persistence}
      # if a lazy option is not used, use the first argument
      local argOne=${project:-$1}
      # regardless, shift the argument list
      shift
      cdToProject ${helpargs:+"$helpargs"} "$argOne" "$@"
      break
      ;;
    status)
      shift
      rs-status ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    update)
      shift
      rs-update ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    reset-master)
      shift
      rs-reset-master ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    branch)
      shift
      rs-branch ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    build)
      shift
      rs-build ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    clone)
      shift
      rs-clone ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    --) # end of all options
      shift
      ;;
    *)
      if [[ "$#" -gt 1 && "$RS_PROJECTS" == *"$1"* ]]; then
        project="$1"
        shift
        cdToProject ${helpargs:+"$helpargs"} "$project" "$@"
      else
        rsRootUsage
        echo " Error: no command found."
        RS_ERROR="rs"
      fi
      break
      ;;
    esac
  done

  if [ -n "$RS_ERROR" ]; then
    return 1
  else
    return 0
  fi
}

_rs() {
  # https://tylerthrailkill.com/2019-01-19/writing-bash-completion-script-with-subcommands/
  local i cmd
  i=1

  # find previous command (rather than option)
  while [[ "$i" -lt "$COMP_CWORD" ]]; do
    local s
    s="${COMP_WORDS[i]}"
    case "$s" in
      -*)
        ;;
      *)
        cmd="$s"
        break
        ;;
    esac
    (( i++ ))
  done

  if [[ "$i" -eq "$COMP_CWORD" ]]; then
    # 'rs'
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "all $RS_COMMANDS $RS_OPTIONS" -- "${cur}"))
    return
  fi

  case "$cmd" in
    all)
      _rs-all
      return 0
      ;;
    update)
      _rs-update
      return 0
      ;;
    branch)
      _rs-branch
      return 0
      ;;
    build)
      _rs-build
      return 0
      ;;
    clone)
      _rs-clone
      return 0
      ;;
    *)
    ;;
  esac

}

# Register the completion function
complete -F _rs rs
