#!/bin/bash

export IDX_SOURCE_VERSION=0.1.1

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# IDX repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR=${WORKDIR:-/cygdrive/c/dev/github}

export IDX_V1_PROJECTS="idx-api-app idx-admin-app idx-template-app idx-swing-apps"
export IDX_V2_LIBS="idx-api-super-pom idx-api-core idx-api-domain"
export IDX_V2_FLYWAY="idx-db-migration cmp-db-migration"
export IDX_V2_VERTICALS="idx-discovery idx-metric idx-orchestration idx-project idx-statistic idx-template idx-user idx-workflow cmp-mailbox"
export IDX_V2_PROJECTS="$IDX_V2_FLYWAY $IDX_V2_LIBS $IDX_V2_VERTICALS"
export IDX_PROJECTS="$IDX_V2_PROJECTS $IDX_V1_PROJECTS"
export IDX_ALL="$IDX_PROJECTS"

# Variables used for command completion
export IDX_COMMAND_LAZY="api admin template-app swing super core domain db-migration discovery metric orchestration project statistic template user workflow mailbox"
export IDX_COMMANDS="$IDX_ALL status update reset-master branch $IDX_COMMAND_LAZY"
export IDX_OPTIONS="-h --help"

rootUsage() {
  cat <<-EOF
USAGE: idx [all] [[-h|--help]] <command>

COMMANDS:
  all                 recursively execute the command in each of the projects

  idx-api-super-pom   change the CWD to the project (lazy: 'super')
  idx-api-core          "   (lazy: 'core')
  idx-api-domain        "   (lazy: 'domain')
  idx-discovery         "   (lazy: 'discovery')
  idx-metric            "   (lazy: 'metric)
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

  status                check the git status of the repository
  update                update the repository
  branch                report on the repository's branches
  reset-master          force a reset of the local master branch to the remote branch

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
  pcre                  Pearl-compatible expression language utilities

ERRORS:
  If an error occurs the script will exit with '1' and IDX_ERROR will contain
  detail information as to where in the script the error occurs.

EOF
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
    rootUsage
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
  local postfix=
  if [[ $result != *"master"* ]]; then
    prefix='\e[1;33m'
    postfix='\e[0m'
  elif [[ $result != *"up-to-date"* ]]; then
    prefix='\e[1;34m'
    postfix='\e[0m'
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
  local idx_status_clean_merged

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
      IDX_ERROR="idx-reset-master - options"
      return
      ;;
    esac
  done

  git checkout master
  git pull

  if [ -n "$idx_status_clean_merged" ]; then
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
    
    current_branch="$(git branch | grep "\*" | cut -d" " -f2)"
    if [[ "$current_branch" == "master" ]]; then
      prefix='\e[1;32m'
      postfix='\e[0m'
    else
      prefix='\e[1;31m'
      postfix='\e[0m'
    fi
    echo -e $prefix$current_branch$postfix
  elif $filterpr; then
    git -P branch "${options[@]}" | grep -v -P -e "^\s*((remotes/)?origin/)?pr/\d+"
  else
    git -P branch "${options[@]}"
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
      reset-master)
        COMPREPLY=()
        return
        ;;
    esac
    (( subcommand_index++ ))
  done

  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "-h --help status update branch reset-master" -- "$cur"))
}

idx-all() {
  case "$1" in
    -h | --help)
      idx "$@"
      shift
      return
      ;;
    *)
      ;;
  esac

  pushd . >/dev/null
  for dir in $IDX_ALL; do
    echo ========================
    echo PROJECT - "$dir"
    cd "$WORKDIR/$dir" || {
      IDX_ERROR="idx-all"
      echo "Failed to 'cd' to $WORKDIR/$PROJECT"
      return 1
    }
    idx "$@"
    if [ ! -z "$IDX_ERROR" ]; then
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
      idx-all "$@"
      break
      ;;
    super)
      project=${project:=idx-api-super-pom}
      ;&
    idx-api-super-pom)
      ;&
    core)
      project=${project:=idx-api-core}
      ;&
    idx-api-core)
      ;&
    domain)
      project=${project:=idx-api-domain}
      ;&
    idx-api-domain)
      ;&
    discovery)
      project=${project:=idx-discovery}
      ;&
    idx-discovery)
      ;&
    metric)
      project=${project:=idx-metric}
      ;&
    idx-metric)
      ;&
    orchestration)
      project=${project:=idx-orchestration}
      ;&
    idx-orchestration)
      ;&
    project)
      project=${project:=idx-project}
      ;&
    idx-project)
      ;&
    statistic)
      project=${project:=idx-statistic}
      ;&
    idx-statistic)
      ;&
    template)
      project=${project:=idx-template}
      ;&
    idx-template)
      ;&
    user)
      project=${project:=idx-user}
      ;&
    idx-user)
      ;&
    workflow)
      project=${project:=idx-workflow}
      ;&
    idx-workflow)
      ;&
    api)
      project=${project:=idx-api-app}
      ;&
    idx-api-app)
      ;&
    admin)
      project=${project:=idx-admin-app}
      ;&
    idx-admin-app)
      ;&
    template-app)
      project=${project:=idx-template-app}
      ;&
    idx-template-app)
      ;&
    swing)
      project=${project:=idx-swing-apps}
      ;&
    idx-swing-apps)
      ;&
    mailbox)
      project=${project:=cmp-mailbox}
      ;&
    cmp-mailbox)
      ;&
    migration)
      project=${project:=idx-db-migration}
      ;&
    idx-db-migration)
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
    --) # end of all options
      shift
      ;;
    *) # no more options
      rootUsage
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
    *)
    ;;
  esac

}

# Register the completion function
complete -F _idx idx
