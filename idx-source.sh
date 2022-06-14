#!/bin/bash

export IDX_SOURCE_VERSION=0.2.4

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# IDX repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR="${WORKDIR:-$HOME/github}"
export SLACK_JAR="${SLACK_JAR:-$HOME/bin/idx-slack-client-0.0.1-SNAPSHOT.jar}"

# Maintain order!
export IDX_V1_PROJECTS="idx-api-app idx-admin-app idx-template-app idx-swing-apps"
export IDX_V2_SUPER_POM="idx-api-super-pom"
export IDX_V2_LIBS="idx-api-core idx-api-domain"
export IDX_V2_FLYWAY="idx-db-migration cmp-db-migration"
export IDX_V2_VERTICALS="idx-discovery idx-metric idx-orchestration idx-project idx-statistic idx-template idx-user idx-workflow cmp-mailbox"
export IDX_V2_PROJECTS="$IDX_API_IDX_V2_SUPER_POM $IDX_V2_LIBS $IDX_V2_FLYWAY $IDX_V2_VERTICALS"
export IDX_V2_SPIKE="$IDX_V2_LIBS $IDX_V2_FLYWAY $IDX_V2_VERTICALS"
export IDX_PROJECTS="$IDX_V2_PROJECTS $IDX_V1_PROJECTS"
export IDX_ALL="$IDX_V2_SUPER_POM $IDX_PROJECTS"

# Variables used for command completion
export IDX_COMMAND_LAZY="api admin template-app swing super core domain migration discovery metric orchestration project statistic template user workflow mailbox"
export IDX_COMMANDS="$IDX_ALL status update reset-master branch build clone atest versions slack spike $IDX_COMMAND_LAZY"
export IDX_OPTIONS="-h --help"

export GITHUB_BASE="https://github.com"
export GITHUB_FS_BASE="$GITHUB_BASE/fs-eng"

COLOR_LT_BLUE='\e[1;34m'
COLOR_LT_GREEN='\e[1;32m'
COLOR_LT_RED='\e[1;31m'
COLOR_RED='\e[0;31m'
COLOR_NONE='\e[0m'

idxRootUsage() {
  cat <<-EOF
USAGE: idx [all] [[-h|--help]] <command>

COMMANDS:
  all                 Recursively execute the command in each of the projects.

  idx-api-super-pom   Change the CWD to the project (lazy: 'super').
  idx-api-core          "   (lazy: 'core')
  idx-api-domain        "   (lazy: 'domain')
  idx-discovery         "   (lazy: 'discovery')
  idx-metric            "   (lazy: 'metric')
  idx-orchestration     "   (lazy: 'orchestration')
  idx-project           "   (lazy: 'project')
  idx-statistic         "   (lazy: 'statistic')
  idx-template          "   (lazy: 'template')
  idx-user              "   (lazy: 'user')
  idx-workflow          "   (lazy: 'workflow')
  idx-api-app           "   (lazy: 'api')
  idx-admin-app         "   (lazy: 'admin')
  idx-template-app      "   (lazy: 'template-app')
  idx-swing-apps        "   (lazy: 'swing')
  cmp-mailbox           "   (lazy: 'mailbox')
  idx-db-migration      "   (lazy: 'migration')
  cmp-db-migration      "   (lazy: <none>)

  status                Check the git status of the repository.
  update                Update the repository.
  branch                Report on the repository's branches.
  reset-master          Force a reset of the local master branch to the remote branch.
  build                 Build the repository.
  clone                 Clone github repositories.
  atest                 Initiate execution of acceptance tests (from the current project directory;
                        assumes the acceptance test module is running).
  versions              Update the version properties in the Maven pom.xml file.
  slack                 Post to the 'idx-api-engineers' Slack channel.
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
  - SLACK_JAR           JAR file location (default: ~/bin/idx-slack-client-0.0.1-SNAPSHOT.jar)
  - SLACK_THREAD_ID     Optional Slack thread ID

ERRORS:
  If an error occurs the script will exit with '1' and IDX_ERROR will contain
  detail information as to where in the script the error occurs.

EOF
}

currentBranch() {
  git branch | grep "\*" | cut -d" " -f2
}

cdToProject-usage() {
  cat <<-EOF
USAGE: idx <project>

Change the current working directory to the root of the project.

OPTIONS: <project>      name of the GitHub project
EOF
}

cdToProject() {
  case "$1" in
    -h | --help)
      cdToProject-usage
      IDX_ERROR="cdToProject - command help"
      return
      ;;
    *)
      ;;
  esac

  PROJECT="$1"
  if [ ! -d "$WORKDIR/$PROJECT" ]; then
    idxRootUsage
    echo " Error: Project directory for $PROJECT does not exist."
    IDX_ERROR="cdToProject"
    return
  fi
  cd "$WORKDIR/$PROJECT" || {
    IDX_ERROR="cdToProject"
    echo "Failed to 'cd' to $WORKDIR/$PROJECT"
    return 1
  }
}

idx-status-usage() {
  cat <<-EOF
USAGE: idx status

Report on the 'git-status' of the repository.
EOF
}

idx-status() {
  case "$1" in
    -h | --help)
      idx-status-usage
      IDX_ERROR="idx-status - command help"
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

idx-update-usage() {
  cat <<-EOF
USAGE: idx update [[-c | --clean-merged]]

Updates the 'master' branch of the repository. Checks out the 'master'
branch if it is not currently checked out and performs a 'git pull' request.

OPTIONS:
-c | --clean-merged   removes local tracked branches that have been
                      merged into 'master'.
EOF
}

_idx-update() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-c --clean-merged" -- "$cur"))
}

idx-update() {
  local idx_status_clean_merged=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-update-usage
        IDX_ERROR="idx-update - command help"
        return
        ;;
      -c | --clean-merged)
        idx_status_clean_merged=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        idx-update-usage
        IDX_ERROR="idx-update - options"
        return
        ;;
    esac
  done

  git checkout master
  git pull

  if $idx_status_clean_merged ; then
    local merged
    merged="$(git branch --merged | grep -v master)"
    for b in $merged; do
      git branch -d "$b"
    done
  fi
}

idx-reset-master-usage() {
  cat <<-EOF
USAGE: idx reset-master

Force a deletion of the local master branch and recreate it from the remote
master branch. Useful if the local master is accidentally modified.
EOF
}

idx-reset-master() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-reset-master-usage
        IDX_ERROR="idx-reset-master - command help"
        return
      ;;
    *)
      echo Option \'"$1"\' not recognized.
      idx-reset-master-usage
      IDX_ERROR="idx-reset-master - options"
      return
      ;;
    esac
  done

  local modified_count="$(git status --porcelain=2 | wc -l)"
  if [[ "$modified_count" -gt 0 ]]; then
    echo ERROR: Local branch has uncommitted changes! Commit or stash the changes and re-run.
    IDX_ERROR="idx-reset-master"
    return
  fi

  git fetch origin
  git branch --move --force master killme
  git branch --track master origin/master
  git checkout master
  git branch --delete --force killme
}

idx-branch-usage() {
  cat <<-EOF
USAGE: idx branch [[-a | all] [-c | --current] [-m | --merged] [-n | --no-merged]
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

_idx-branch() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -c --current -m --merged -n --no-merged -r --remotes -f --filter-pr" -- "$cur"))
}

idx-branch() {
  local current=false
  local filterpr=false
  local options=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-branch-usage
        IDX_ERROR="idx-reset-master - command help"
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
        idx-branch-usage
        IDX_ERROR="idx-reset-master - options"
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

_idx-clone() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --all -d --delete" -- "$cur"))
}

idx-clone-usage() {
  cat <<-EOF
USAGE idx clone [[-a | --all]] <repo name(s)>

Clone the github repositories specified by the space-delimited list of repository names.
The new local respoistory will be cloned into the 'WORKDIR' directory.

OPTIONS:
  -a | --all	Clone all IDX repositories.
  -d | --delete	Delete the existing repository before cloning.
EOF
}

idx-clone-repo() {
  local repo="$1"
  local url="$GITHUB_FS_BASE/$repo.git"
  echo -e Cloning fs-eng repository ${COLOR_RED}$url${COLOR_NONE}
  git clone "$url"
}

idx-clone() {
  local delete_repo=false
  local repositories

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-clone-usage
        IDX_ERROR="idx-clone - command help"
        return
        ;;
      -a | --all)
        shift
        repositories="$IDX_ALL"
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
        idx-clone-repo $repo
      else
        echo -e Skipping exisiting repository ${COLOR_RED}$repo${COLOR_NONE}
      fi
    else
      idx-clone-repo $repo
    fi
  done

  popd >/dev/null || exit
}

_idx-versions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k -keep-branch -l --local -q --quiet -s --skip-build -d --draft-pr -t --title" -- "$cur"))
}

idx-versions-usage() {
  cat <<-EOF
USAGE: idx versions [[-k | --keep-branch] [-l | --local] [-s | --skip-build] [-q | --quiet] [--t <title> | --title <title>]]

Update the Maven properties for the IDX dependencies (parent pom and core dependencies).
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

idx-versions() {
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
        idx-versions-usage
        IDX_ERROR="idx-versions - command help"
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
        idx-versions-usage
        IDX_ERROR="idx-versions - options"
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
      IDX_ERROR="idx-versions - change to master"
      return 1
    fi
  else
    echo Keeping current branch \["${current_branch}"\].
  fi

  mvn -U versions:update-parent versions:update-properties versions:commit

  if isDirectoryClean; then
    echo No modifications to the branch.
    git checkout master
    git branch -d "${branch_name}"
    return 0
  fi

  if $build; then
    if ! idx-build; then
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
          idx-slack -t "${SLACK_THREAD_ID}" "PR (${pr_title}): ${pr_url}"
        else
          idx-slack "PR (update versions): ${pr_url}"
        fi
      else
        echo No PR URL found. Skipping Slack notifications.
        IDX_ERROR="idx-versions - no PR URL"
        return 1
      fi
    else
      echo Skipping Slack notifications.
    fi
  else
    echo Skipping git commit and Slack notifications.
  fi
}

idx-atest-usage() {
  cat <<-EOF
USAGE: idx atest

Initiate the acceptance test module to run the acceptance tests.
Assumes that the acceptance test module is loaded. (See `idx build -a`.)

EOF
}

idx-atest() {
  ## TODO add options to start the acceptance test module; validate the name
  local name="${PWD##*/}"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-atest-usage
        IDX_ERROR="idx-atest - command help"
        return
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        idx-atest-usage
        IDX_ERROR="idx-atest - options"
        return
        ;;
    esac
  done

  curl -X POST http://localhost:8080/test?url=http://localhost:8080/"${name}"\&config=testng-local.xml
  echo "Test started; waiting for report..."
  while [ "RUNNING" == `curl -s http://localhost:8080/test` ]
  do
          echo -n .
          sleep 1
  done
  curl http://localhost:8080/report
}

_idx-build() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-k --keep-existing -l --local-m2-repository -a --acceptance-test -s --server" -- "$cur"))
}

idx-build-usage() {
  cat <<-EOF
USAGE: idx build [[-k | --keep-existing] [-r | --local-m2-repository]]

Build the local repository. (By default, this will clean the build directory
then perform a 'mvn install' command.

OPTIONS:
  -k | --keep-existing        Keep the existing build files (no Maven 'clean' goal is used).
  -l | --local-m2-repository  Use a local M2 repository ('target/m2-repo').
  -a | --acceptance-test      Start the server and acceptance test module.
  -s | --server               Start the server (but not the acceptance test module).
EOF
}

idx-build() {
  local mvn_clean=true
  local local_m2_repository=false
  local acceptance=false
  local server=false

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-build-usage
        IDX_ERROR="idx-build - command help"
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
      -a | --acceptance-test)
        shift
        acceptance=true
        ;;
      -s | --server)
        server=true
        shift
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        idx-build-usage
        IDX_ERROR="idx-build - options"
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
      IDX_ERROR="idx-build"
      return 1
    fi
  else
    IDX_ERROR="idx-build clean"
    return 1
  fi

  if [[ $acceptance = true && -d acceptance ]]; then
    pushd acceptance >/dev/null || exit
    mvn cargo:run
    popd >/dev/null || exit
  fi

  if [[ $server = true && -d server ]]; then
    pushd server >/dev/null || exit
    mvn cargo:run
    popd >/dev/null || exit
  fi
}

_idx-slack() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-p --post -t --thread -t --token" -- "$cur"))
}

idx-slack-usage() {
  cat <<-EOF
USAGE: idx slack [[-p | --post] [-t <thread id> | --thread <thread id>] [--token <token>]] <message>

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

idx-slack() {
  local action
  local thraedid
  local token
  local message

  action=post
  token=${SLACK_TOKEN}

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-slack-usage
        IDX_ERROR="idx-slack - command help"
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
    IDX_ERROR="idx-slack - token"
    idx-slack-usage
    return 1
  fi

  if [[ "thread" == "${action}" && -z "${threadid}" ]]; then
    echo ERROR: No Slack thread id found!
    IDX_ERROR="idx-slack thread id"
    idx-slack-usage
    return 1
  fi

  if [ -z "${message}" ]; then
    echo No message provided!
    IDX_ERROR="idx-slack message"
    idx-slack-usage
    return 1
  fi

  if [[ -z "${SLACK_JAR}" || ! -a "${SLACK_JAR}" ]]; then
    echo No SLACK_JAR environment variable!
    idx-slack-usage
    return 1
  fi

  if [ "post" == "${action}" ]; then
    SLACK_THREAD_ID="$(java -jar "${SLACK_JAR}" --token="${token}" --post "${message}")"
    export SLACK_THREAD_ID
  else
    java -jar "${SLACK_JAR}" --token="${token}" --reply --threadId="${threadid}" "${message}" >/dev/null
  fi
}

_idx-spike() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-a --abandon" -- "$cur"))
}

idx-spike-usage() {
  cat <<-EOF
USAGE: idx spike [-a | --abandon]

Create (or abandon) a 'spike' branch. This updates the root pom file with SNAPSHOT versions
of the idx-api-super-pom, idx-api-core and idx-api-domain versions. It will then perform
a sanity build of the project. To create a 'spike' branch, the current branch must be 'master'.
To abandon a 'spike' branch, the current branch must be 'spike'.

OPTIONS:
  -a | --abandon  Abandon the current 'spike' branch and revert to 'master'
EOF
}

# TODO add option for local M2 directory for build
idx-spike() {
  local abandon=false
  local current_branch

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-spike-usage
        IDX_ERROR="idx-spike - command help"
        return
        ;;
      -a | --abandon)
        shift
        abandon=true
        ;;
      *)
        echo Option \'"$1"\' not recognized.
        idx-build-usage
        IDX_ERROR="idx-spike - options"
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
        IDX_ERROR="idx-spike create"
        echo "ERROR: Current branch must be 'master'"
        return 1
      fi

      git checkout -b spike
    fi

    xmlstarlet ed --inplace -P -u "//_:parent[_:artifactId='idx-api-super-pom']/_:version" -v "1.2-SNAPSHOT" pom.xml
    xmlstarlet ed -S --inplace -u "//_:idx-api-core.version" -v "2.2-SNAPSHOT" pom.xml
    xmlstarlet ed -S --inplace -u "//_:idx-api-domain.version" -v "2.2-SNAPSHOT" pom.xml

    idx build

    if [[ $? -gt 0 ]]; then
      IDX_ERROR="idx-spike"
      return 1
    fi

  fi
}

_idx-all() {
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
        _idx-status
        return
        ;;
      update)
        _idx-update
        return
        ;;
      branch)
        _idx-branch
        return
        ;;
      build)
        _idx-build
        return
        ;;
      versions)
        _idx-versions
        return
        ;;
      reset-master)
        COMPREPLY=()
        return
        ;;
      clone)
        _idx-clone
        return
        ;;
      spike)
        _idx-spike
        return
        ;;
    esac
    (( subcommand_index++ ))
  done

  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-h --help status update branch reset-master build versions spike" -- "$cur"))
}

idx-all-usage() {
  echo <<-EOF
USAGE: idx all [-v | --verticals] <command>

Recursively execute <command> on all of the IDX projects.

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

idx-all() {
  local projects
  projects="$IDX_ALL"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        idx-all-usage
        IDX_ERROR="idx-all - command help"
        return
        ;;
      -v | --verticals)
        projects="$IDX_V1_PROJECTS $IDX_V2_VERTICALS"
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
      IDX_ERROR="idx-all"
      echo "Failed to 'cd' to $WORKDIR/$PROJECT"
      return 1
    }
    idx "$@"
    if [ -n "$IDX_ERROR" ]; then
      break
    fi
  done
  popd >/dev/null || {
    IDX_ERROR="idx-all"
    echo "Failed to return to starting directory"
    return 1
  }

}

idx() {
  local project
  local helpargs
  unset -v IDX_ERROR

  # validate there is a valid WORKDIR
  if [ ! -d "$WORKDIR" ]; then
    idxRootUsage
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
      idx-all "$@"
      break
      ;;
    idx-api-super-pom | super)
      project=${project:-idx-api-super-pom}
      ;&
    idx-api-core | core)
      project=${project:-idx-api-core}
      ;&
    idx-api-domain | domain)
      project=${project:-idx-api-domain}
      ;&
    idx-discovery | discovery)
      project=${project:-idx-discovery}
      ;&
    idx-metric | metric)
      project=${project:-idx-metric}
      ;&
    idx-orchestration | orchestration)
      project=${project:-idx-orchestration}
      ;&
    idx-project | project)
      project=${project:-idx-project}
      ;&
    idx-statistic | statistic)
      project=${project:-idx-statistic}
      ;&
    idx-template | template)
      project=${project:-idx-template}
      ;&
    idx-user | user)
      project=${project:-idx-user}
      ;&
    idx-workflow | workflow)
      project=${project:-idx-workflow}
      ;&
    idx-api-app | api)
      project=${project:-idx-api-app}
      ;&
    idx-admin-app | admin)
      project=${project:-idx-admin-app}
      ;&
    idx-template-app | template-app)
      project=${project:-idx-template-app}
      ;&
    idx-swing-apps | swing)
      project=${project:-idx-swing-apps}
      ;&
    cmp-mailbox | mailbox)
      project=${project:-cmp-mailbox}
      ;&
    idx-db-migration | migration)
      project=${project:-idx-db-migration}
      ;&
    cmp-db-migration)
      project=${project:cmp-db-migration}
      # if a lazy option is not used, use the first argument
      local argOne=${project:-$1}
      # regardless, shift the argument list
      shift
      cdToProject ${helpargs:+"$helpargs"} "$argOne" "$@"
      break
      ;;
    status)
      shift
      idx-status ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    update)
      shift
      idx-update ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    reset-master)
      shift
      idx-reset-master ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    branch)
      shift
      idx-branch ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    build)
      shift
      idx-build ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    clone)
      shift
      idx-clone ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    atest)
      shift
      idx-atest ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    versions)
      shift
      idx-versions ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    slack)
      shift
      idx-slack ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    spike)
      shift
      idx-spike ${helpargs:+"$helpargs"} "$@"
      break
      ;;
    --) # end of all options
      shift
      ;;
    *) # no more options
      idxRootUsage
      echo " Error: no command found."
      IDX_ERROR="idx"
      break
      ;;
    esac
  done

  if [ -n "$IDX_ERROR" ]; then
    return 1
  else
    return 0
  fi
}

_idx() {
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
    # 'idx'
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "all $IDX_COMMANDS $IDX_OPTIONS" -- "${cur}"))
    return
  fi

  case "$cmd" in
    all)
      _idx-all
      return 0
      ;;
    update)
      _idx-update
      return 0
      ;;
    branch)
      _idx-branch
      return 0
      ;;
    build)
      _idx-build
      return 0
      ;;
    clone)
      _idx-clone
      return 0
      ;;
    versions)
      _idx-versions
      return 0
      ;;
    slack)
      _idx-slack
      return 0
      ;;
    spike)
      _idx-spike
      return 0
      ;;
    *)
    ;;
  esac

}

# Register the completion function
complete -F _idx idx
