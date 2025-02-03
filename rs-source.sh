#!/bin/bash

export RS_SOURCE_VERSION=0.5.2

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# Records Storage repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR="${WORKDIR:-$HOME/github}"

# Maintain order!
export RS_COMMON_PROJECTS="records-storage-cds-core records-storage-df records-storage-eol records-storage-fsicds records-storage-gedcomx records-storage-model records-storage-ram"
export RS_LIB_PROJECTS="sls-model slsdata-gedcomx sls-reconcile slsdata-convert sls-persistence slsdata-gedcomx-lite sls-internal-messaging"
export RS_APP_PROJECTS="cds2-root recapi cds-journal-worker sls-internal-workers sls-consumers sls-bulk-export sls-data-lake sls-dlq-worker sls-web-app sls-sqs-worker sls-record-completion records-storage-counting records-storage-synchronization"
export RD_LIB_PROJECTS="sls-templates sls-test-utils sls-client-utils slsdata-treatments sls-template-logic"
export RS_PROJECTS="records-storage ${RS_COMMON_PROJECTS} ${RS_LIB_PROJECTS} ${RS_APP_PROJECTS}"

# Variables used for command completion
export RS_COMMANDS="${RS_PROJECTS} ${RD_LIB_PROJECTS} status update reset-master branch build build-status clone jakarta-migrate"
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

  records-storage           Change the CWD to the project

  records-storage-cds-core  Change the CWD to the project (RS_COMMON_PROJECTS)
  records-storage-eol             "
  records-storage-df              "
  records-storage-fsicds          "
  records-storage-gedcomx         "
  records-storage-ram             "

  sls-model                 Change the CWD to the project (RS_LIB_PROJECTS)
  slsdata-gedcomx                 "
  sls-reconcile                   "
  slsdata-convert                 "
  sls-persistence                 "
  slsdata-gedcomx-lite            "
  sls-internal-messaging          "

  cds2-root                 Change the CWD to the project (RS_APP_PROJECTS)
  recapi                          "
  cds-journal-worker              "
  sls-internal-workers            "
  sls-consumers                   "
  sls-bulk-export                 "
  sls-dlq-worker                  "
  sls-data-lake                   "
  sls-web-app                     "
  sls-sqs-worker                  "
  sls-record-completion           "
  records-storage-counting        "
  records-storage-synchronization "

  sls-templates           Change the CWD to the project (RD_LIB_PROJECTS)
  sls-test-utils                  "
  sls-client-utils                "
  slsdata-treatments              "
  sls-template-logic              "

  branch                Report on the repository's branches.
  build                 Build the repository.
  build-status          Report the status of GitHub Action builds.
  clean                 Perform a Maven clean of the project.
  clone                 Clone github repositories.
  graph                 Create dependency graphs.
  dep-tree              Generate the dependency tree for the project's artifacts.
  reset-master          Force a reset of the local master branch to the remote branch.
  status                Check the git status of the repository.
  update                Update the repository.
  versions              Update the version properties in the Maven pom.xml file.

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
USAGE rs clone [[-a | --all] | [-d | --delete] | [--common] | [--lib] | [--apps] | [--rd-lib]] <repo name(s)>

Clone the github repositories specified by the space-delimited list of repository names.
The new local repository will be cloned into the 'WORKDIR' directory.

OPTIONS:
  -a | --all	  Clone all rs repositories.
  -d | --delete	Delete the existing repository before cloning.
  --common      Clone all common repositories
  --lib         Clone all library repositories
  --app         Clone all application repositories
  --rd-lib      Clone all RD library repositories
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
      --common)
        repositories+="$RS_COMMON_PROJECTS"
        shift
        ;;
      --lib)
        repositories+="$RS_LIB_PROJECTS"
        shift
        ;;
      --app)
        repositories+="$RS_APP_PROJECTS"
        shift
        ;;
      --rd-lib)
        repositories+="$RD_LIB_PROJECTS"
        shift
        ;;
      *)
        repositories="$repositories $1"
        shift
        ;;
    esac
  done

  if [ -z "$repositories" ]; then
    repositories="$RS_PROJECTS"
  fi

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

rs-build-status() {
  gh run list --limit 5
}

rs-graph-usage() {
  cat <<-EOF
  USAGE: rs graph [[-d | --duplicates] | [-v | --versions]]

  Generate dependency graph for the project's artifacts.

  OPTIONS:
    -d | --duplicates           Include duplicate paths to artifacts.
    -v | --versions             Include artifact versions.
EOF
}

_rs-graph() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-d --duplicates -v --versions" -- "$cur"))
}

rs-graph() {
  local args
  args=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-graph-usage
        RS_ERROR="rs-graph - command help"
        return
        ;;
      -d | --duplicates)
        shift
        args="${args} -DshowDuplicates"
        ;;
      -v | --versions)
        args="${args} -DshowVersions"
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        rs-build-usage
        RS_ERROR="rs-build - options"
        return
        ;;
    esac
  done

  mvn depgraph:graph ${args}

}

rs-dep-tree() {
  mkdir -p target
  mvn dependency:tree > target/dependency-tree.txt
}

rs-clean() {
  mvn clean
}

_rs-versions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k -keep-branch -l --local -s --skip-build -d --draft-pr -p --parent -t --title" -- "$cur"))
}

rs-versions-usage() {
  cat <<-EOF
USAGE: rs versions [[-p | --parent] [-k | --keep-branch] [-l | --local] [-s | --skip-build] [-t <title> | --title <title>]]

Update the Maven properties for the rs dependencies (parent pom and core dependencies).
See the Maven pom.xml configuration for the versions plugin.

OPTIONS:
  -p | --parent         Update parent pom version
  -k | --keep-branch    Keep the current branch (don't base the change on 'master')
  -l | --local          Make all changes local only (no commit, push, or PR)
  -s | --skip-build     Skip the sanity build
  -d | --draft-pr       Make the PR a draft
  -t | --title          PR title (default: "Update versions")

By default, this script will do the following:
  - checkout the master branch
  - update the local branch from the up-stream remote (via 'pull')
  - checkout a new branch
  - update the Maven parent pom version (if selected)
  - update the Maven property versions
  - do a clean, sanity build
  - commit the changes
  - push the branch to the remote
  - create a PR

EOF
}

rs-versions() {
  local parent_pom
  local keep_branch
  local local_only
  local build
  local quiet
  local draft_pr
  local pr_title

  keep_branch=false
  local_only=false
  build=true
  draft_pr=false
  pr_title="Update versions"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-versions-usage
        RS_ERROR="rs-versions - command help"
        return
        ;;
      -p | --parent)
        parent_pom=true
        shift
        ;;
      -k | --keep-branch)
        keep_branch=true
        shift
        ;;
      -l | --local)
        local_only=true
        shift
        ;;
      -s | --skip-build)
        build=false
        shift
        ;;
      -d | --draft-pr)
        draft_pr=true
        shift
        ;;
      -t | --title)
        shift
        pr_title="$1"
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        rs-versions-usage
        RS_ERROR="rs-versions - options"
        return 1
        ;;
    esac
  done

  local current_branch
  current_branch="$(currentBranch)"

  if ! $keep_branch; then
    local branch_name

    branch_name="versions-${RANDOM}"

    if isDirectoryClean; then
      if [[ "$current_branch" != "master" ]]; then
        git checkout master
      fi

      git pull
      git checkout -b "${branch_name}"
      current_branch="${branch_name}"
    else
      echo Unclean git working directory.
      RS_ERROR="rs-versions - change to master"
      return 1
    fi
  else
    echo Keeping current branch \["${current_branch}"\].
  fi

  local mvn_goals
  mvn_goals="versions:update-properties versions:commit"
  if $parent_pom; then
    mvn_goals="versions:update-parent ${mvn_goals}"
  fi

  mvn -U ${mvn_goals}

  if isDirectoryClean; then
    echo No modifications to the branch.
    git checkout master
    git branch -d "${branch_name}"
    return 0
  fi

  if $build; then
    if ! rs-build; then
      echo Build failed!
      return 1
    fi
  else
    echo Skipping sanity build.
  fi

  if ! $local_only; then
    git commit -am "Update versions"
    git push -u origin "${current_branch}"

    local gh_options

    if $draft_pr; then
      gh_options="--draft"
    fi
    gh pr create ${gh_options} --body "" --title "${pr_title}"

  else
    echo Skipping git commit.
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
      clean)
        subcommand_index=$i
        break
        ;;
      versions)
        subcommand_index=$i
        break
        ;;
      dep-tree)
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
      clean)
        _rs-clean
        return
        ;;
      reset-master)
        COMPREPLY=()
        return
        ;;
      versions)
        _rs-versions
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
USAGE: rs all [[--common] | [--lib] | [--app] | [--rd-lib] | [-f <repo> | --from <repo>]] <command>

Recursively execute <command> on all of the rs projects.

OPTIONS:
  --common                    Execute command against common (records-*) lib repositories
  --lib                       Execute command against all library repositories
  --app                       Execute command against all application repositories
  --rd-lib                    Execute command against all RD library repositories
  -f <repo> | --from <repo>   Begin execution with '<repo>'

The default is '--common --lib --app'.

SUPPORTED COMMANDS:
  status
  update
  branch
  build
  build-status
  reset-master
  versions
  dep-tree

EOF
}

rs-all() {
  local projects
  projects=""
  from_project=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        rs-all-usage
        RS_ERROR="rs-all - command help"
        return
        ;;
      --common)
        projects+=" $RS_COMMON_PROJECTS"
        shift
        ;;
      --lib)
        projects+=" $RS_LIB_PROJECTS"
        shift
        ;;
      --app)
        projects+=" $RS_APP_PROJECTS"
        shift
        ;;
      --rd-lib)
        projects=" $RD_LIB_PROJECTS"
        shift
        ;;
      -f | --from)
        shift
        from_project="$1"
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  if [ -z "$projects" ]; then
    projects="$RS_PROJECTS"
  fi

  pushd . >/dev/null

  for dir in $projects; do
    if [[ ("$from_project" != "") && ("$dir" != "$from_project") ]];
    then
      echo "Skipping project $dir"
      continue
    fi
    from_project=""
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
    build-status)
      shift
      rs-build-status ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    clone)
      shift
      rs-clone ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    clean)
      shift
      rs-clean ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    graph)
      shift
      rs-graph ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    versions)
      shift
      rs-versions ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    dep-tree)
      shift
      rs-dep-tree ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    --) # end of all options
      shift
      ;;
    *)
      if [[ "$#" -ge 1 && "$RS_PROJECTS" == *"$1"* ]]; then
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
    graph)
      _rs-graph
      return 0
      ;;
    versions)
      _idx-versions
      return 0
      ;;
    *)
    ;;
  esac

}

# Register the completion function
complete -F _rs rs
