#!/bin/bash

export JS_SOURCE_VERSION=0.1.1

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# Java Stack repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR="${WORKDIR:-$HOME/github}"

# Maintain order!
export JS_PROJECTS="java-stack java-stack-assertj java-stack-identity java-stack-initializer java-stack-issues java-stack-jdbc java-stack-secrets java-stack-testapp"

# Variables used for command completion
export JS_COMMAND_LAZY="stack assertj identity initializer issues jdbc secrets testapp"
export JS_COMMANDS="$JS_PROJECTS status update reset-master branch build clone $JS_COMMAND_LAZY"
export JS_OPTIONS="-h --help"

export GITHUB_BASE="https://github.com"
export GITHUB_FS_BASE="$GITHUB_BASE/fs-eng"

COLOR_LT_BLUE='\e[1;34m'
COLOR_LT_GREEN='\e[1;32m'
COLOR_LT_RED='\e[1;31m'
COLOR_RED='\e[0;31m'
COLOR_NONE='\e[0m'

rootUsage() {
  cat <<-EOF
USAGE: js [all] [[-h|--help]] <command>

COMMANDS:
  all                 Recursively execute the command in each of the project
  
  java-stack                Change the CWD to the project (lazy: 'stack').
  java-stack-assertj          "  (lazy: 'assertj').
  java-stack-identity         "  (lazy: 'identity').
  java-stack-initializer      "  (lazy: 'initializer').
  java-stack-issues           "  (lazy: 'issues').
  java-stack-jdbc             "  (lazy: 'jdbc').
  java-stack-secrets          "  (lazy: 'secrets').
  java-stack-testapp          "  (lazy: 'testapp').

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
  If an error occurs the script will exit with '1' and JS_ERROR will contain
  detail information as to where in the script the error occurs.

EOF
}

currentBranch() {
  git branch | grep "\*" | cut -d" " -f2
}

cdToProject-usage() {
  cat <<-EOF
USAGE: js <project>

Change the current working directory to the root of the project.

OPTIONS: <project>      name of the GitHub project
EOF
}

cdToProject() {
  case "$1" in
    -h | --help)
      cdToProject-usage
      JS_ERROR="cdToProject - command help"
      return
      ;;
    *)
      ;;
  esac

  PROJECT="$1"

  if [ ! -d "$WORKDIR/$PROJECT" ]; then
    rootUsage
    echo " Error: Project directory for $PROJECT does not exist."
    JS_ERROR="cdToProject"
    return
  fi
  cd "$WORKDIR/$PROJECT" || {
    JS_ERROR="cdToProject"
    echo "Failed to 'cd' to $WORKDIR/$PROJECT"
    return 1
  }
}

js-status-usage() {
  cat <<-EOF
USAGE: js status

Report on the 'git-status' of the repository.
EOF
}

js-status() {
  case "$1" in
    -h | --help)
      js-status-usage
      JS_ERROR="js-status - command help"
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

js-update-usage() {
  cat <<-EOF
USAGE: js update [[-c | --clean-merged]]

Updates the 'master' branch of the repository. Checks out the 'master'
branch if it is not currently checked out and performs a 'git pull' request.

OPTIONS:
-c | --clean-merged   removes local tracked branches that have been
                      merged into 'master'.
EOF
}

_js-update() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-c --clean-merged" -- "$cur"))
}

js-update() {
  local js_status_clean_merged=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        js-update-usage
        JS_ERROR="js-update - command help"
        return
        ;;
      -c | --clean-merged)
        js_status_clean_merged=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        js-update-usage
        JS_ERROR="js-reset-master - options"
        return
        ;;
    esac
  done

  git checkout master
  git pull

  if $js_status_clean_merged ; then
    local merged
    merged="$(git branch --merged | grep -v master)"
    for b in $merged; do
      git branch -d "$b"
    done
  fi
}

js-reset-master-usage() {
  cat <<-EOF
USAGE: js reset-master

Force a deletion of the local master branch and recreate it from the remote
master branch. Useful if the local master is accidentally modified.
EOF
}

js-reset-master() {
  case "$1" in
    -h | --help)
      js-reset-master-usage
      JS_ERROR="js-reset-master - command help"
      return
    ;;
  *)
    ;;
  esac

  local modified_count

  modified_count="$(git status --porcelain=2 | wc -l)"

  if [[ "$modified_count" -gt 0 ]]; then
    echo ERROR: Local branch has uncommitted changes! Commit or stash the changes and re-run.
    JS_ERROR="js-reset-master"
    return
  fi

  git fetch origin
  git branch --move --force master killme
  git branch --track master origin/master
  git checkout master
  git branch --delete --force killme
}

js-branch-usage() {
  cat <<-EOF
USAGE: js branch [[-a | all] [-c | --current] [-m | --merged] [-n | --no-merged]
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

_js-branch() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -c --current -m --merged -n --no-merged -r --remotes -f --filter-pr" -- "$cur"))
}

js-branch() {
  local current=false
  local filterpr=false
  local options=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        js-branch-usage
        JS_ERROR="js-reset-master - command help"
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
        js-branch-usage
        JS_ERROR="js-reset-master - options"
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

_js-clone() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -d --delete" -- "$cur"))
}

js-clone-usage() {
  cat <<-EOF
USAGE js clone [[-a | --all] | [-d | --delete]] <repo name(s)>

Clone the github repositories specified by the space-delimited list of repository names. 
The new local repository will be cloned into the 'WORKDIR' directory.

OPTIONS:
  -a | --all	Clone all js repositories.
  -d | --delete	Delete the existing repository before cloning.
EOF
}

js-clone-repo() {
  local repo="$1"
  local url="$GITHUB_FS_BASE/$repo.git"
  echo -e Cloning fs-eng repository ${COLOR_RED}$url${COLOR_NONE}
  git clone "$url"
}

js-clone() {
  local delete_repo=false
  local repositories

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        js-clone-usage
        JS_ERROR="js-clone - command help"
        return
        ;;
      -a | --all)
        shift
        repositories="$JS_PROJECTS"
        ;;
      -d | --delete)
        shift
        delete_repo=true
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
        js-clone-repo $repo
      else
        echo -e Skipping exisiting repository ${COLOR_RED}$repo${COLOR_NONE}
      fi
    else
      js-clone-repo $repo
    fi
  done

  popd >/dev/null || exit
}

isDirectoryClean() {
  git diff-index --quiet HEAD --
}

_js-build() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k --keep-existing -l --local-m2-repository -a --acceptance-test -s --server" -- "$cur"))
}

js-build-usage() {
  cat <<-EOF
USAGE: js build [[-k | --keep-existing] [-r | --local-m2-repository]]

Build the local repository. (By default, this will clean the build directory
then perform a 'mvn install' command.

OPTIONS:
  -k | --keep-existing        Keep the existing build files (no Maven 'clean' goal is used).
  -l | --local-m2-repository  Use a local M2 repository ('target/m2-repo').
EOF
}

js-build() {
  local mvn_clean=true
  local local_m2_repository=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        js-build-usage
        JS_ERROR="js-build - command help"
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
        js-build-usage
        JS_ERROR="js-build - options"
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
        JS_ERROR="js-build"
        return 1
      fi
    else
      JS_ERROR="js-build clean"
      return 1
    fi
  fi
}

_js-all() {
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
        _js-status
        return
        ;;
      update)
        _js-update
        return
        ;;
      branch)
        _js-branch
        return
        ;;
      build)
        _js-build
        return
        ;;
      reset-master)
        COMPREPLY=()
        return
        ;;
      clone)
        _js-clone
        return
        ;;
    esac
    (( subcommand_index++ ))
  done

  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-h --help status update branch reset-master build " -- "$cur"))
}

js-all-usage() {
  cat <<-EOF
USAGE: js all <command>

Recursively execute <command> on all of the js projects.

SUPPORTED COMMANDS:
  status
  update
  branch
  build
  reset-master
  clone

EOF
}

js-all() {
  local projects
  projects="$JS_PROJECTS"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        js-all-usage
        JS_ERROR="js-all - command help"
        return
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
      JS_ERROR="js-all"
      echo "Failed to 'cd' to $WORKDIR/$PROJECT"
      return 1
    }
    js "$@"
    if [ -n "$JS_ERROR" ]; then
      break
    fi
  done
  popd >/dev/null || {
    JS_ERROR="js-all"
    echo "Failed to return to starting directory"
    return 1
  }

}

js() {
  local project
  local helpargs
  unset -v JS_ERROR

  # validate there is a valid WORKDIR
  if [ ! -d "$WORKDIR" ]; then
    rootUsage
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
      js-all "$@"
      break
      ;;
    java-stack | stack)
      project=${project:-java-stack}
      ;&
    java-stack-assertj | assertj)
      project=${project:-java-stack-assertj}
      ;&
    java-stack-identity | identity)
      project=${project:-java-stack-identity}
      ;&
    java-stack-initializer | initializer)
      project=${project:-java-stack-initializer}
      ;&
    java-stack-issues | issues)
      project=${project:-java-stack-issues}
      ;&
    java-stack-jdbc | jdbc)
      project=${project:-java-stack-jdbc}
      ;&
    java-stack-secrets | secrets)
      project=${project:-java-stack-secrets}
      ;&
    java-stack-testapp | testapp)
      project=${project:-java-stack-testapp}
      # if a lazy option is not used, use the first argument
      local argOne=${project:-$1}
      # regardless, shift the argument list
      shift
      cdToProject ${helpargs:+"$helpargs"} "$argOne" "$@"
      break
      ;;
    status)
      shift
      js-status ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    update)
      shift
      js-update ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    reset-master)
      shift
      js-reset-master ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    branch)
      shift
      js-branch ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    build)
      shift
      js-build ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    clone)
      shift
      js-clone ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    --) # end of all options
      shift
      ;;
    *) # no more options
      rootUsage
      echo " Error: no command found."
      JS_ERROR="js"
      break
      ;;
    esac
  done

  if [ -n "$JS_ERROR" ]; then
    return 1
  else
    return 0
  fi
}

_js() {
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
    # 'js'
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "all $JS_COMMANDS $JS_OPTIONS" -- "${cur}"))
    return
  fi

  case "$cmd" in
    all)
      _js-all
      return 0
      ;;
    update)
      _js-update
      return 0
      ;;
    branch)
      _js-branch
      return 0
      ;;
    build)
      _js-build
      return 0
      ;;
    clone)
      _js-clone
      return 0
      ;;
    *)
    ;;
  esac

}

# Register the completion function
complete -F _js js
