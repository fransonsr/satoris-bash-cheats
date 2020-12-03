#!/bin/bash

#
# Sets environment variables for other scripts. Principally,
# WORKDIR which is the root directory for all git projects
# and the set of subdirectories that constitute the set of
# IDX repositories.
#

# If WORKDIR is already set, use that value; otherwise you get this default
export WORKDIR=${workdir:-/cygdrive/c/dev/github}

export IDX_V1_PROJECTS="idx-api-app idx-admin-app idx-template-app idx-swing-apps"
export IDX_V2_LIBS="idx-api-super-pom idx-api-core idx-api-domain"
export IDX_V2_FLYWAY="idx-db-migration cmp-db-migration"
export IDX_V2_VERTICALS="idx-discovery idx-metric idx-orchestration idx-project idx-statistic idx-template idx-user idx-workflow cmp-mailbox"
export IDX_V2_PROJECTS="$IDX_V2_FLYWAY $IDX_V2_LIBS $IDX_V2_VERTICALS"
export IDX_PROJECTS="$IDX_V2_PROJECTS $IDX_V1_PROJECTS"
export IDX_ALL="$IDX_PROJECTS"

# Variables used for command completion
export IDX_COMMAND_LAZY="api admin template-app swing super core domain db-migration discovery metric orchestration project statistic template user workflow mailbox"
export IDX_COMMANDS="$IDX_ALL status update $IDX_COMMAND_LAZY"
export IDX_OPTIONS="-h --help"
export IDX_UPDATE_OPTIONS="-c --clean-merged"

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

ERRORS:
  If an error occurs the script will exit with '1' and IDX_ERROR will contain
  detail information as to where in the script the error occurs.

EOF
}

cdToProject() {
  case "$1" in
    -h | --help)
      rootUsage
      cat <<-EOF
  ========================================================================
  USAGE: idx <project>

  Change the current working directory to the root of the project.

  OPTIONS: <project>      name of the GitHub project
EOF
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
  cd "$WORKDIR/$PROJECT" || { IDX_ERROR="cdToProject"; echo "Failed to 'cd' to $WORKDIR/$PROJECT"; return 1;}
}

idx-status() {
    case "$1" in
    -h | --help)
      rootUsage
      cat <<-EOF
  ========================================================================
  USAGE: idx status

  Report on the 'git-status' of the repository.
EOF
      IDX_ERROR="idx-status - command help"
      return
      ;;
    *)
      ;;
  esac

  RESULT=$(git status)
  PREFIX=
  POSTFIX=
  if [[ $RESULT != *"master"* ]]
  then
          PREFIX='\e[1;33m'
          POSTFIX='\e[0m'
  elif [[ $RESULT != *"up-to-date"* ]]
  then
          PREFIX='\e[1;34m'
          POSTFIX='\e[0m'
  fi
  echo -e "$PREFIX$RESULT$POSTFIX"
}

idx-update() {
  local idx_status_clean_merged

  case "$1" in
    -h | --help)
      rootUsage
      cat <<-EOF
  ===========================================================================
  USAGE: idx update [[-c | --clean-merged]]

  Updates the 'master' branch of the repository. Checks out the 'master'
  branch if it is not currently checked out and performs a 'git pull' request.

  OPTIONS:
  -c | --clean-merged   removes local tracked branches that have been
                        merged into 'master'.
EOF
      IDX_ERROR="idx-update - command help"
      return
      ;;
    -c | --clean-merged)
      idx_status_clean_merged=true
      shift
      ;;
    *)
      ;;
  esac

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

idx-all() {
    case "$1" in
    -h | --help)
      idx "$@"
      return
      ;;
    *)
      ;;
  esac

  pushd . >/dev/null
  for DIR in $IDX_ALL
  do
    echo ========================
    echo PROJECT - "$DIR"
    cd "$WORKDIR/$DIR" || { IDX_ERROR="idx-all"; echo "Failed to 'cd' to $WORKDIR/$PROJECT"; return 1;}
    idx "$@"
  done
  popd >/dev/null || { IDX_ERROR="idx-all"; echo "Failed to return to starting directory"; return 1;}

}

idx() {
  local project
  unset -v IDX_ERROR
  unset -v HELPARGS

  # validate there is a valid WORKDIR
  if [ ! -d "$WORKDIR" ]; then
    rootUsage
    echo " Error: WORKDIR does not exist or is not a directory."
    return 1
  fi

  while [ $# -ge 0 ]; do
    case "$1" in
    -h | --help)
      HELPARGS+="$1"
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
      cdToProject ${HELPARGS:+"$HELPARGS"} "$argOne" "$@"
      break;
      ;;
    status)
      shift
      idx-status ${HELPARGS:+"$HELPARGS"} "$@"
      break;
      ;;
    update)
      shift
      idx-update ${HELPARGS:+"$HELPARGS"} "$@"
      break;
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
  local cur prev opts allopts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  opts="$IDX_COMMANDS $IDX_OPTIONS"
  allopts="all ${opts}"

  #
  #  Complete the arguments to some of the basic commands.
  #
  case "${prev}" in
    all)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
      return 0;
      ;;
    update)
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "${IDX_UPDATE_OPTIONS}" -- ${cur}) )
      return 0;
      ;;
    *)
    ;;
  esac

  # shellcheck disable=SC2207
  COMPREPLY=($(compgen -W "${allopts}" -- ${cur}))
  return 0
}

# Register the completion function
complete -F _idx idx
