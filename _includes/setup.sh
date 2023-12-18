#!/bin/bash

# Install from local Brewfile if the one specified exists
BREWFILE="${HOMEBREW_BREWFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/brewfile/Brewfile}"

# Log activity to this file
LOG_FILE=${LOG_FILE:-"$HOME/.setup.log"}

# Storage engine for `mackup`. This does nothing unless mackup installed or in the brewfile.
MACKUP_ENGINE=${MACKUP_ENGINE:-"icloud"}

# Update schedule in cron syntax
SCHEDULE=${SCHEDULE:-"0 12 * * *"}

# Sync this repo unless $BREWFILE exists.
REPO=${REPO:-"erlend/brewfile"}

test -n "$DEBUG" && set -x

# Allow cancelling with ctrl-c
trap - SIGINT

# Add all possible brew paths
PATH="$HOME/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:$PATH"

# shellcheck disable=SC2034
use_touch_id_for_sudo_name="Enable TouchID for sudo"
use_touch_id_for_sudo() {
  if [ -f /etc/pam.d/sudo_local ]; then
    log "Found existing /etc/pam.d/sudo_local"
    current_status=FOUND
    return 0
  fi

  sed -E 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local
}

# shellcheck disable=SC2034
macos_command_line_tools_name="Install Command Line Tools"
macos_command_line_tools() {
  if xcode-select --print-path 2>/dev/null; then
    log "Found existing command line tools"
    current_status="FOUND"
    return 0
  fi

  log "Installing command line tools"
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  softwareupdate --install --all
  rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
}

# shellcheck disable=SC2034
macos_rosetta_name="Install Rosetta"
macos_rosetta() {
  if [ "$(arch)" != "arm64" ]; then
    log "Rosetta is not supported on $(arch)"
    current_status="UNSUPPORTED"
    return 0
  fi

  if arch -x86_64 true &>/dev/null; then
    log "Found existing Rosetta installation"
    current_status="FOUND"
    return 0
  fi

  log "Installing Rosetta"
  softwareupdate --install-rosetta --agree-to-license
}

# shellcheck disable=SC2034
apt_install_homebrew_dependencies_name="Install dependencies with apt"
apt_install_homebrew_dependencies() {
  log "Updating apt sources"
  sudo apt-get update -q || log "apt-get update failed"

  log "Installing dependencies with apt"
  # python3 is required for brew-file and might not be installed on all systems
  sudo apt-get install -y build-essential procps curl file git python3
}

# shellcheck disable=SC2034
yum_install_homebrew_dependencies_name="Install dependencies with yum"
yum_install_homebrew_dependencies() {
  log "Installing developement tools with yum"
  sudo yum groupinstall -y 'Development Tools' || return 1

  log "Installing additional dependencies with yum"
  sudo yum install -y procps-ng curl file git
}

# shellcheck disable=SC2034
install_homebrew_name="Install Homebrew"
install_homebrew() {
  if command -v brew >/dev/null; then
    log "Found existing Homebrew installation"
    current_status="FOUND"
    return 0
  fi

  log "Downloading and installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# shellcheck disable=SC2034
install_brew_file_name="Install brew-file"
install_brew_file() {
  if command -v brew-file >/dev/null; then
    log "Found existing brew-file installation"
    current_status="FOUND"
    return 0
  fi

  log "Downloading and installing brew-file"
  brew install rcmdnk/file/brew-file
}

# shellcheck disable=SC2034
install_from_brewfile_name="Install from Brewfile"
install_from_brewfile() {
  if has_local_brewfile; then
    log "Installing from local brewfile"
  elif has_repo_access; then
    log "Installing from git repo $REPO"
    brew file set_repo -r "$REPO"
  else
    current_error="Could not access git repository $REPO."
    log "$current_error"
    return 1
  fi

  log "Install from Brewfile"
  brew file install
}

# shellcheck disable=SC2034
create_brew_file_cronjob_name="Create cronjob"
create_brew_file_cronjob() {
  if command -v crontab &>/dev/null; then
    log "Updating crontab"
    (crontab -l 2>/dev/null; echo "$SCHEDULE $(command -v brew) file update") | uniq | crontab -
  else
    current_error="Missing executable \"crontab\""
    log "$current_error"
  fi
}

# shellcheck disable=SC2034
mackup_restore_name="Restore mackup"
mackup_restore() {
  if ! command -v mackup &>/dev/null; then
    log "Mackup is not installed"
    current_status="MISSING"
    return 0
  fi

  log Configuring mackup
  local config="$HOME/.mackup.cfg"
  test -f "$config" || printf "[storage]\nengine = %s" "$MACKUP_ENGINE" > "$config"

  log mackup restore
  mackup restore
}

red() {
  printf "\e[31m%s\e[0m" "$*"
}

green() {
  printf "\e[32m%s\e[0m" "$*"
}

blue() {
  printf "\e[34m%s\e[0m" "$*"
}

purple() {
  printf "\e[35m%s\e[0m" "$*"
}

linux_release() {
  awk -F\" "/^$1=/ { print \$2 }" /etc/os-release
}

has_local_brewfile() {
  log "Checking for local Brewfile in $BREWFILE"
  test -e "$BREWFILE"
}

has_repo_access() {
  log "Checking if $REPO_URL is accessible"
  timeout 5 git ls-remote --heads --exit-code "$REPO_URL" &>/dev/null
}

read_key() {
  read -rsn1 </dev/tty
  printf "%s" "$REPLY"
}

timestamp() {
  date +%Y-%m-%dT%H:%M:%S%z
}

debug() {
  test -n "$DEBUG" && log "$@"
}

log() {
  echo "$(timestamp) $*" >> "$LOG_FILE"
}

error_dialog() {
  responses="(A)bort / (R)etry / (S)kip"
  printf "\n%s\n%s " "$(red "ERROR: $*")" "$responses"

  while true; do
    case $(read_key) in
      A|a)
        draw_row "$(red ABORTED)" "Provisioning cancelled"
        echo
        exit 1
        ;;

      R|r)
        draw_row "$(purple RETRYING)" "$task_name"
        echo
        break
        ;;

      S|s)
        draw_row "$(purple SKIPPED)" "$task_name"
        skip_task
        break
        ;;
    esac
  done
}

draw_row() {
  printf "\r%-20s %s" "[$1]" "${*:2} "
}

task_name() {
  local task_id=$1

  if [[ "$1" =~ ^[0-9]+$ ]]; then
    task_id="${pending_tasks[$1]}"
  fi

  local var_name="${task_id}_name"
  local var_value="${!var_name}"
  printf "%s" "$var_value"
}

time_since() {
  local T=$(($(date +%s) - $1))
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( D > 0 )) && printf '%d days ' $D
  (( H > 0 )) && printf '%d hours ' $H
  (( M > 0 )) && printf '%d minutes ' $M
  (( D > 0 || H > 0 || M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

ask() {
  printf "\n%s (Y)es / (N)o " "$1"
}

answer() {
  printf "\r%s %-12s\n" "$1" "$2"
}

next_task() {
  ((current_task++))
  echo
}

skip_task() {
  ((current_task++))
  ((failures++))
  echo
}

start_setup_for() {
  cat > "$LOG_FILE" << EOF
$(timestamp)  Setup started for ${@}
BREWFILE="$BREWFILE"
LOG_FILE="$LOG_FILE"
MACKUP_ENGINE="$MACKUP_ENGINE"
SCHEDULE="$SCHEDULE"
REPO="$REPO"
EOF

  blue "Provisioning for $*"

  local confirmation="Are you sure you want to continue?"
  ask "$confirmation"

  while true; do
    case $(read_key) in
      Y|y)
        setup_started_at=$(date +%s)
        answer "$confirmation" "Yes"
        break
        ;;
      N|n)
        answer "$confirmation" "No"
        exit
        ;;
    esac
  done
}

if [[ "$UID" -eq 0 ]]; then
  red "Do not run this script as a root user\n"
  exit 1
fi

OS=$(uname)
REPO_URL=$(echo "$REPO" | awk '{ print ($0 ~ /@|:/ ? $0 : sprintf("git@github.com:%s.git", $0)) }')

declare -a pending_tasks

case $OS in
  Darwin)
    pending_tasks=(use_touch_id_for_sudo macos_command_line_tools macos_rosetta)
    start_setup_for macOS
    ;;
  Linux)
    distro_name=$(linux_release NAME)
    if command -v apt >/dev/null; then
      pending_tasks=(apt_install_homebrew_dependencies)
      start_setup_for "$distro_name $(linux_release VERSION)"
    elif command -v yum >/dev/null; then
      pending_tasks=(yum_install_homebrew_dependencies)
      start_setup_for "$distro_name $(linux_release VERSION_ID)"
    else
      start_setup_for "$(red 'unsupported Linux distribution')"
    fi
    ;;
  *)
    red "Unsupported Operating System\n"
    exit 1
    ;;
esac

pending_tasks+=(install_homebrew install_brew_file install_from_brewfile create_brew_file_cronjob mackup_restore)
failures=0
current_task=0

while [[ "$current_task" -lt "${#pending_tasks[@]}" ]]; do
  task_command=${pending_tasks[$current_task]}
  task_name=$(task_name "$task_command")
  log "$task_name"
  draw_row "$(blue RUNNING)" "$task_name"

  current_error="" # remove previous error message
  current_status=""
  started_at=$(date +%s)

  if "$task_command" &> "$LOG_FILE"; then
    draw_row "$(green "${current_status:-SUCCESS}")" "$task_name completed in $(time_since "$started_at")"
    next_task
  else
    draw_row "$(red FAILED)" "$task_name failed after $(time_since "$started_at")"
    error_dialog "${current_error:-"See the log file to find out more."}"
  fi
done

if [[ "$failures" -gt 0 ]]; then
  setup_status=$(red "with $failures failures")
else
  setup_status=$(green "without failures")
fi

draw_row "$(blue "FINISHED")" "Provisioned $setup_status" "in $(time_since "$setup_started_at")"
echo
