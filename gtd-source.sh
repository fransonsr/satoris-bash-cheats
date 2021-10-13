#!/bin/bash

export GTD_SOURCE_VERSION=0.0.2

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# GTD repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR="${WORKDIR:-$HOME/github}"
export SLACK_JAR="${SLACK_JAR:-$HOME/bin/idx-slack-client-0.0.1-SNAPSHOT.jar}"

# Maintain order!
export GTD_PROJECTS="gtd-core gtd-data gtd-aletheia gtd-workflow"
export GTD_ALL=${GTD_PROJECTS}

# Variables used for command completion
export GTD_COMMAND_LAZY="core data aletheia workflow"
export GTD_COMMANDS="$GTD_PROJECTS status update reset-master branch build clone atest versions slack spike $GTD_COMMAND_LAZY"
export GTD_OPTIONS="-h --help"

export GITHUB_BASE="https://github.com"
export GITHUB_FS_BASE="$GITHUB_BASE/fs-eng"

COLOR_LT_BLUE='\e[1;34m'
COLOR_LT_GREEN='\e[1;32m'
COLOR_LT_RED='\e[1;31m'
COLOR_RED='\e[0;31m'
COLOR_NONE='\e[0m'

rootUsage() {
  cat <<-EOF
USAGE: gtd [all] [[-h|--help]] <command>

COMMANDS:
  all                 Recursively execute the command in each of the projects.

  gtd-data            Change the CWD to the project (lazy: 'data').
  gtd-aletheia          "   (lazy: 'aletheia')
  gtd-workflow          "   (lazy: 'workflow')
  gtd-core              "   (lazy: 'core')

  status                Check the git status of the repository.
  update                Update the repository.
  branch                Report on the repository's branches.
  reset-master          Force a reset of the local master branch to the remote branch.
  build                 Build the repository.
  clone                 Clone github repositories.
  atest                 Initiate execution of acceptance tests (from the current project directory;
                        assumes the acceptance test module is running).
  versions              Update the version properties in the Maven pom.xml file.
  slack                 Post to the 'gtd-api-engineers' Slack channel.
  spike                 Create a 'spike' branch and update the root pom to SNAPSHOTs.

OPTIONS:
  -h | --help           Display this help. If a command follows, command-
                        specific help is displayed.

DEPENDENCIES:
  java                  Virtual machine
  git                   git VCS tool with authentication to GitHub
  gh                    GitHub CLI with authentication to GitHub
  xmlstarlet            XML processing tool
  mvn                   Maven build tool
  docker                Container management
  pcre                  Pearl-compatible regex expression language utilities
  bash-completion       Bash command completion utility
  idx-api-slack-client  The generated JAR file for "idx-api-slack-client".

SLACK NOTIFICATION:
  To use Slack notification, the following environment variables must be defined:

  - SLACK_TOKEN         Slack application token for the 'idx-api-pr-notify' Slack app
  - SLACK_JAR           JAR file location (default: ~/bin/dix-slack-client-0.0.1-SNAPSHOT.jar)
  - SLACK_THREAD_ID     Optional Slack thread ID

ERRORS:
  If an error occurs the script will exit with '1' and GTD_ERROR will contain
  detail information as to where in the script the error occurs.

EOF
}

currentBranch() {
  git branch | grep "\*" | cut -d" " -f2
}

cdToProject-usage() {
  cat <<-EOF
USAGE: gtd <project>

Change the current working directory to the root of the project.

OPTIONS: <project>      name of the GitHub project
EOF
}

cdToProject() {
  case "$1" in
    -h | --help)
      cdToProject-usage
      GTD_ERROR="cdToProject - command help"
      return
      ;;
    *)
      ;;
  esac

  PROJECT="$1"
  if [ ! -d "$WORKDIR/$PROJECT" ]; then
    rootUsage
    echo " Error: Project directory for $PROJECT does not exist."
    GTD_ERROR="cdToProject"
    return
  fi
  cd "$WORKDIR/$PROJECT" || {
    GTD_ERROR="cdToProject"
    echo "Failed to 'cd' to $WORKDIR/$PROJECT"
    return 1
  }
}

gtd-status-usage() {
  cat <<-EOF
USAGE: gtd status

Report on the 'git-status' of the repository.
EOF
}

gtd-status() {
  case "$1" in
    -h | --help)
      gtd-status-usage
      GTD_ERROR="gtd-status - command help"
      return
      ;;
    *)
      ;;
  esac

  local result=$(git status)
  local prefix
  local postfix
  if [[ $result != *"master"* ]]; then
    prefix=${COLOR_LT_GREEN}
    postfix=${COLOR_NONE}
  elif [[ $result != *"up-to-date"* ]]; then
    prefix=${COLOR_LT_BLUE}
    postfix=${COLOR_NONE}
  fi
  echo -e "$prefix$result$postfix"
}

gtd-update-usage() {
  cat <<-EOF
USAGE: gtd update [[-c | --clean-merged]]

Updates the 'master' branch of the repository. Checks out the 'master'
branch if it is not currently checked out and performs a 'git pull' request.

OPTIONS:
-c | --clean-merged   removes local tracked branches that have been
                      merged into 'master'.
EOF
}

_gtd-update() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-c --clean-merged" -- "$cur"))
}

gtd-update() {
  local gtd_status_clean_merged=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-update-usage
        GTD_ERROR="gtd-update - command help"
        return
        ;;
      -c | --clean-merged)
        gtd_status_clean_merged=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        gtd-update-usage
        GTD_ERROR="gtd-reset-master - options"
        return
        ;;
    esac
  done

  git checkout master
  git pull

  if $gtd_status_clean_merged ; then
    local merged
    merged="$(git branch --merged | grep -v master)"
    for b in $merged; do
      git branch -d "$b"
    done
  fi
}

gtd-reset-master-usage() {
  cat <<-EOF
USAGE: gtd reset-master

Force a deletion of the local master branch and recreate it from the remote
master branch. Useful if the local master is accidentally modified.
EOF
}

gtd-reset-master() {
  case "$1" in
    -h | --help)
      gtd-reset-master-usage
      GTD_ERROR="gtd-reset-master - command help"
      return
    ;;
  *)
    echo Option \'"$1"\' not recognized.
    gtd-reset-master-usage
    GTD_ERROR="gtd-reset-master - options"
    return
    ;;
  esac

  local modified_count="$(git status --porcelain=2 | wc -l)"
  if [[ "$modified_count" -gt 0 ]]; then
    echo ERROR: Local branch has uncommitted changes! Commit or stash the changes and re-run.
    GTD_ERROR="gtd-reset-master"
    return
  fi

  git fetch origin
  git branch --move --force master killme
  git branch --track master origin/master
  git checkout master
  git branch --delete --force killme
}

gtd-branch-usage() {
  cat <<-EOF
USAGE: gtd branch [[-a | all] [-c | --current] [-m | --merged] [-n | --no-merged]
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

_gtd-branch() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -c --current -m --merged -n --no-merged -r --remotes -f --filter-pr" -- "$cur"))
}

gtd-branch() {
  local current=false
  local filterpr=false
  local options=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-branch-usage
        GTD_ERROR="gtd-reset-master - command help"
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
        gtd-branch-usage
        GTD_ERROR="gtd-reset-master - options"
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

_gtd-clone() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -d --delete" -- "$cur"))
}

gtd-clone-usage() {
  cat <<-EOF
USAGE gtd clone [[-a | --all]] <repo name(s)>

Clone the github repositories specified by the space-delimited list of repository names. 
The new local respoistory will be cloned into the 'WORKDIR' directory.

OPTIONS:
  -a | --all	Clone all GTD repositories.
  -d | --delete	Delete the existing repository before cloning.
EOF
}

gtd-clone-repo() {
  local repo="$1"
  local url="$GITHUB_FS_BASE/$repo.git"
  echo -e Cloning fs-eng repository ${COLOR_RED}$url${COLOR_NONE}
  git clone "$url"
}

gtd-clone() {
  local delete_repo=false
  local repositories

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-clone-usage
        GTD_ERROR="gtd-clone - command help"
        return
        ;;
      -a | --all)
        shift
        repositories="$GTD_ALL"
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
        gtd-clone-repo $repo
      else
        echo -e Skipping exisiting repository ${COLOR_RED}$repo${COLOR_NONE}
      fi
    else
      gtd-clone-repo $repo
    fi
  done

  popd >/dev/null || exit
}

_gtd-versions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k -keep-branch -l --local -q --quiet -s --skip-build -d --draft-pr -t --title" -- "$cur"))
}

gtd-versions-usage() {
  cat <<-EOF
USAGE: gtd versions [[-k | --keep-branch] [-l | --local] [-s | --skip-build] [-q | --quiet] [--t <title> | --title <title>]]

Update the Maven properties for the GTD dependencies (parent pom and core dependencies).
See the Maven pom.xml configuration for the versions plugin.

OPTIONS:
  -k | --keep-branch    Keep the current branch (don't base the change on 'master')
  -l | --local          Make all changes local only (no commit, push, PR, or Slack notification)
  -s | --skip-build     Skip the sanity build
  -q | --quiet          Keep quiet; no Slack notifications
  -d | --draft-pr       Make the PR a draft
  -t | --title          PR title (also prefix to the Slack message; default: "Update versions"

By default, this script will do the following:
  - checkout the master branch
  - update the local branch from the up-stream remote (via 'pull')
  - checkout a new branch
  - update the Maven parent pom version
  - update the Maven property versions
  - do a clean, sanity build
  - commit the changes
  - push the branch to the remote
  - create a PR
  - send a notification to the #indexing-api-engineers Slack channel

EOF
}

isDirectoryClean() {
  git diff-index --quiet HEAD --
}

gtd-versions() {
  ## TODO option to start AT module?
  local keep_branch
  local local_only
  local build
  local quiet
  local draft_pr
  local pr_title

  keep_branch=false
  local_only=false
  build=true
  quiet=false
  draft_pr=false
  pr_title="Update versions"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-versions-usage
        GTD_ERROR="gtd-versions - command help"
        return
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
      -q | --quiet)
        quiet=true
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
        gtd-versions-usage
        GTD_ERROR="gtd-versions - options"
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
      GTD_ERROR="gtd-versions - change to master"
      return 1
    fi
  else
    echo Keeping current branch \["${current_branch}"\].
  fi

  mvn -U versions:update-parent versions:update-properties versions:commit

  if $build; then
    if ! gtd-build; then
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

    if ! $quiet; then
      local pr_url

      pr_url="$(gh pr view | grep url | cut -f2)"
      if [ -n "${pr_url}" ]; then
        if [ -n "${SLACK_THREAD_ID}" ]; then
          gtd-slack -t "${SLACK_THREAD_ID}" "PR (${pr_title}): ${pr_url}"
        else
          gtd-slack "PR (update versions): ${pr_url}"
        fi
      else
        echo No PR URL found. Skipping Slack notifications.
        GTD_ERROR="gtd-versions - no PR URL"
        return 1
      fi
    else
      echo Skipping Slack notifications.
    fi
  else
    echo Skipping git commit and Slack notifications.
  fi
}

gtd-atest-usage() {
  cat <<-EOF
USAGE: gtd atest

Initiate the acceptance test module to run the acceptance tests.
Assumes that the acceptance test module is loaded. (See `gtd build -a`.)

EOF
}

gtd-atest() {
  ## TODO add options to start the acceptance test module; validate the name
  local name="${PWD##*/}"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-atest-usage
        GTD_ERROR="gtd-atest - command help"
        return
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        gtd-atest-usage
        GTD_ERROR="gtd-atest - options"
        return
        ;;
    esac
  done

  pushd acceptance
  mvn -Dacceptance.testing verify
  popd
}

_gtd-build() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k --keep-existing -l --local-m2-repository -a --acceptance-test -s --server" -- "$cur"))
}

gtd-build-usage() {
  cat <<-EOF
USAGE: gtd build [[-k | --keep-existing] [-r | --local-m2-repository]]

Build the local repository. (By default, this will clean the build directory
then perform a 'mvn install' command.

OPTIONS:
  -k | --keep-existing        Keep the existing build files (no Maven 'clean' goal is used).
  -l | --local-m2-repository  Use a local M2 repository ('target/m2-repo').
  -s | --server               Start the server (but not the acceptance test module).
EOF
}

gtd-build() {
  local mvn_clean=true
  local local_m2_repository=false
  local server=false
  local name="${PWD##*/}"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-build-usage
        GTD_ERROR="gtd-build - command help"
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
      -s | --server)
        server=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        gtd-build-usage
        GTD_ERROR="gtd-build - options"
        return
        ;;
    esac
  done

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
      GTD_ERROR="gtd-build"
      return 1
    fi
  else
    GTD_ERROR="gtd-build clean"
    return 1
  fi

  if [[ $server = true && -d server ]]; then
    pushd webapp >/dev/null || exit
    java -jar target/${name}-webapp.jar
    popd >/dev/null || exit
  fi
}

_gtd-slack() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-p --post -t --thread -t --token" -- "$cur"))
}

gtd-slack-usage() {
  cat <<-EOF
USAGE: gtd slack [[-p | --post] [-t <thread id> | --thread <thread id>] [--token <token>]] <message>

Post a message to the 'idx-api-engineeers' Slack channel.

OPTIONS:
  -p | --post     Create a normal post (default).
                  Note: this command will set the SLACK_THREAD_ID environment variable with the ID of the post.
  -t | --thread   Create a post in a thread. The argument "<thread id>" is the thread id of the parent post.
                  Note: use '-t ${SLACK_THREAD_ID}' or '--thread ${SLACK_THREAD_ID}' to post to a previous post.
  --token         Use the specified token. (Defaults to the value of the SLACK_TOKEN environment variable.)

SLACK NOTIFICATION:
  To use Slack notification, the following environment variables must be defined:

  - SLACK_TOKEN         Slack application token for the 'idx-api-pr-notify' Slack app
  - SLACK_JAR           JAR file location (ex, ~/bin/idx-slack-client-0.0.1-SNAPSHOT.jar)
  - SLACK_THREAD_ID     Optional Slack thread ID

EOF
}

gtd-slack() {
  local action
  local thraedid
  local token
  local message

  action=post
  token=${SLACK_TOKEN}

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-slack-usage
        GTD_ERROR="gtd-slack - command help"
        return
        ;;
      -p | --post)
        action=post
        shift
        ;;
      -t | --thread)
        action=thread
        shift
        threadid="$1"
        shift
        ;;
      --token)
        shift
        token="$1"
        shift
        ;;
      *)
        message="$1"
        shift
        ;;
    esac
  done

  if [ -z "${token}" ]; then
    echo ERROR: No Slack application token found!
    GTD_ERROR="gtd-slack - token"
    gtd-slack-usage
    return 1
  fi

  if [[ "thread" == "${action}" && -z "${threadid}" ]]; then
    echo ERROR: No Slack thread id found!
    GTD_ERROR="gtd-slack thread id"
    gtd-slack-usage
    return 1
  fi

  if [ -z "${message}" ]; then
    echo No message provided!
    GTD_ERROR="gtd-slack message"
    gtd-slack-usage
    return 1
  fi

  if [[ -z "${SLACK_JAR}" || ! -a "${SLACK_JAR}" ]]; then
    echo No SLACK_JAR environment variable!
    gtd-slack-usage
    return 1
  fi

  if [ "post" == "${action}" ]; then
    SLACK_THREAD_ID="$(java -jar "${SLACK_JAR}" --token="${token}" --post "${message}")"
    export SLACK_THREAD_ID
  else
    java -jar "${SLACK_JAR}" --token="${token}" --reply --threadId="${threadid}" "${message}" >/dev/null
  fi
}

_gtd-spike() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --abandon" -- "$cur"))
}

gtd-spike-usage() {
  cat <<-EOF
USAGE: gtd spike [-a | --abandon]

Create (or abandon) a 'spike' branch. This updates the versions in the root pom file. It will then perform
a sanity build of the project. To create a 'spike' branch, the current branch must be 'master'.
To abandon a 'spike' branch, the current branch must be 'spike'.

OPTIONS:
  -a | --abandon  Abandon the current 'spike' branch and revert to 'master'
EOF
}

# TODO add option for local M2 directory for build
gtd-spike() {
  local abandon=false
  local current_branch

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-spike-usage
        GTD_ERROR="gtd-spike - command help"
        return
        ;;
      -a | --abandon)
        shift
        abandon=true
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        gtd-build-usage
        GTD_ERROR="gtd-spike - options"
        return
        ;;
    esac
  done

  current_branch="$(currentBranch)"

  if $abandon; then
    if [ "spike" != "$current_branch" ]; then
      echo "INFO: Skipping; current branch must be 'spike'"
      return 0
    else
      git checkout -f
      git clean -fd
      git checkout master
      git branch -D spike
    fi
  else
    if [ 'spike' != "$current_branch" ]; then
      if [ 'master' != "$current_branch" ]; then
        GTD_ERROR="gtd-spike create"
        echo "ERROR: Current branch must be 'master'"
        return 1
      fi

      git checkout -b spike
    fi

# TODO update verions
#    xmlstarlet ed --inplace -P -u "//_:parent[_:artifactId='gtd-api-super-pom']/_:version" -v "1.2-SNAPSHOT" pom.xml
#    xmlstarlet ed -S --inplace -u "//_:gtd-api-core.version" -v "2.2-SNAPSHOT" pom.xml
#    xmlstarlet ed -S --inplace -u "//_:gtd-api-domain.version" -v "2.2-SNAPSHOT" pom.xml

    gtd build

    if [[ $? -gt 0 ]]; then
      GTD_ERROR="gtd-spike"
      return 1
    fi

  fi
}

_gtd-all() {
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
      versions)
        subcommand_index=$i
        break
        ;;
      spike)
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
        _gtd-status
        return
        ;;
      update)
        _gtd-update
        return
        ;;
      branch)
        _gtd-branch
        return
        ;;
      build)
        _gtd-build
        return
        ;;
      versions)
        _gtd-versions
        return
        ;;
      reset-master)
        COMPREPLY=()
        return
        ;;
      clone)
        _gtd-clone
        return
        ;;
      spike)
        _gtd-spike
        return
        ;;
    esac
    (( subcommand_index++ ))
  done

  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-h --help status update branch reset-master build versions spike" -- "$cur"))
}

gtd-all-usage() {
  echo <<-EOF
USAGE: gtd all [-v | --verticals] <command>

Recursively execute <command> on all of the GTD projects.

SUPPORTED COMMANDS:
  status
  update
  branch
  build
  versions
  reset-master
  clone
  spike

OPTIONS:
  -v | --verticals  Execute the command on the verticals (deployable projects) only.
EOF
}

gtd-all() {
  local projects
  projects="$GTD_ALL"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        gtd-all-usage
        GTD_ERROR="gtd-all - command help"
        return
        ;;
      -v | --verticals)
        projects="$GTD_V1_PROJECTS $GTD_V2_VERTICALS"
        shift
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
      GTD_ERROR="gtd-all"
      echo "Failed to 'cd' to $WORKDIR/$PROJECT"
      return 1
    }
    gtd "$@"
    if [ -n "$GTD_ERROR" ]; then
      break
    fi
  done
  popd >/dev/null || {
    GTD_ERROR="gtd-all"
    echo "Failed to return to starting directory"
    return 1
  }

}

gtd() {
  local project
  local helpargs
  unset -v GTD_ERROR

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
      gtd-all "$@"
      break
      ;;
    gtd-core | core)
      project=${project:-gtd-core}
      ;&
    gtd-aletheia | aletheia)
      project=${project:-gtd-aletheia}
      ;&
    gtd-workflow | workflow)
      project=${project:-gtd-workflow}
      ;&
    gtd-data | data)
      project=${project:-gtd-data}
      # if a lazy option is not used, use the first argument
      local argOne=${project:-$1}
      # regardless, shift the argument list
      shift
      cdToProject ${helpargs:+"$helpargs"} "$argOne" "$@"
      break
      ;;
    status)
      shift
      gtd-status ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    update)
      shift
      gtd-update ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    reset-master)
      shift
      gtd-reset-master ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    branch)
      shift
      gtd-branch ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    build)
      shift
      gtd-build ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    clone)
      shift
      gtd-clone ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    atest)
      shift
      gtd-atest ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    versions)
      shift
      gtd-versions ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    slack)
      shift
      gtd-slack ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    spike)
      shift
      gtd-spike ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    --) # end of all options
      shift
      ;;
    *) # no more options
      rootUsage
      echo " Error: no command found."
      GTD_ERROR="gtd"
      break
      ;;
    esac
  done

  if [ -n "$GTD_ERROR" ]; then
    return 1
  else
    return 0
  fi
}

_gtd() {
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
    # 'gtd'
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "all $GTD_COMMANDS $GTD_OPTIONS" -- "${cur}"))
    return
  fi

  case "$cmd" in
    all)
      _gtd-all
      return 0
      ;;
    update)
      _gtd-update
      return 0
      ;;
    branch)
      _gtd-branch
      return 0
      ;;
    build)
      _gtd-build
      return 0
      ;;
    clone)
      _gtd-clone
      return 0
      ;;
    versions)
      _gtd-versions
      return 0
      ;;
    slack)
      _gtd-slack
      return 0
      ;;
    spike)
      _gtd-spike
      return 0
      ;;
    *)
    ;;
  esac

}

# Register the completion function
complete -F _gtd gtd
