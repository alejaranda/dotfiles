#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

OPT_YES=0
OPT_DRY_RUN=0
OPT_LOG_PATH=""
OPT_CLEAN=1
OPT_ONLY_SECURITY=0
OPT_REBOOT_IF_NEEDED=0

PKG_MGR=""
OS_ID=""
OS_ID_LIKE=""

_setup_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RESET='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    WHITE='\033[0;37m'
  else
    RESET=''; BOLD=''; DIM=''
    RED=''; YELLOW=''; GREEN=''
    CYAN=''; BLUE=''; MAGENTA=''; WHITE=''
  fi
}
_setup_colors

ts() { date +"%H:%M:%S"; }

info()  { printf "${DIM}[$(ts)]${RESET} ${GREEN}✔${RESET}  %s\n"         "$*"; }
warn()  { printf "${DIM}[$(ts)]${RESET} ${YELLOW}⚠${RESET}  %s\n"        "$*" >&2; }
error() { printf "${DIM}[$(ts)]${RESET} ${RED}✖${RESET}  %s\n"           "$*" >&2; }
step()  { printf "\n${BOLD}${CYAN}  ──  %s${RESET}\n"                     "$*"; }
dry()   { printf "${DIM}[$(ts)]${RESET} ${MAGENTA}~${RESET}  ${DIM}%s${RESET}\n" "$*"; }

die() { error "$*"; exit 1; }

has()         { command -v "$1" >/dev/null 2>&1; }
is_abs_path() { [[ "$1" == /* ]]; }

require_cmd() {
  local c
  for c in "$@"; do
    has "$c" || die "Missing required command: $c"
  done
}

run() {
  if (( OPT_DRY_RUN )); then
    dry "would run: $*"
    return 0
  fi
  info "Running: $*"
  "$@"
}

on_exit() {
  local code=$?
  (( code != 0 )) && error "Aborted (exit=$code) — ${BASH_COMMAND}"
}
trap on_exit EXIT

usage() {
  printf "\n"
  printf "  ${BOLD}${WHITE}update.sh${RESET} ${DIM}v${SCRIPT_VERSION}${RESET}\n"
  printf "  ${DIM}Safe, idempotent, multi-distro system updater${RESET}\n"
  printf "\n"
  printf "${BOLD}  Usage${RESET}\n"
  printf "    sudo ./update.sh [OPTIONS]\n"
  printf "\n"
  printf "${BOLD}  Options${RESET}\n"
  printf "    ${CYAN}-y, --yes${RESET}              Auto-confirm prompts\n"
  printf "    ${CYAN}-n, --dry-run${RESET}          Print commands without running them\n"
  printf "    ${CYAN}    --log PATH${RESET}         Append output to log file (absolute path)\n"
  printf "    ${CYAN}    --no-clean${RESET}         Skip autoremove / cache cleanup\n"
  printf "    ${CYAN}    --only-security${RESET}    Security updates only (best-effort)\n"
  printf "    ${CYAN}    --reboot-if-needed${RESET} Reboot automatically if required\n"
  printf "    ${CYAN}-h, --help${RESET}             Show this help and exit\n"
  printf "\n"
  printf "${BOLD}  Examples${RESET}\n"
  printf "    ${DIM}sudo ./update.sh --yes --reboot-if-needed${RESET}\n"
  printf "    ${DIM}sudo ./update.sh --dry-run --log /var/log/update.log${RESET}\n"
  printf "    ${DIM}sudo ./update.sh --only-security --yes${RESET}\n"
  printf "\n"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)             OPT_YES=1 ;;
      -n|--dry-run)         OPT_DRY_RUN=1 ;;
      --no-clean)           OPT_CLEAN=0 ;;
      --only-security)      OPT_ONLY_SECURITY=1 ;;
      --reboot-if-needed)   OPT_REBOOT_IF_NEEDED=1 ;;
      --log)
        shift || die "--log requires a PATH argument"
        [[ -n "${1:-}" ]] || die "--log PATH must not be empty"
        OPT_LOG_PATH="$1"
        ;;
      -h|--help) usage; exit 0 ;;
      --) shift; break ;;
      -*) die "Unknown option: $1  (use --help)" ;;
      *)  die "Unexpected argument: $1  (use --help)" ;;
    esac
    shift
  done
}

ensure_root() {
  (( EUID == 0 )) || die "Run as root — try: sudo ${SCRIPT_NAME}"
}

setup_logging() {
  [[ -z "$OPT_LOG_PATH" ]] && return 0
  is_abs_path "$OPT_LOG_PATH" || die "Log path must be absolute: $OPT_LOG_PATH"

  local log_dir
  log_dir="$(dirname "$OPT_LOG_PATH")"
  [[ -n "$log_dir" && "$log_dir" != "." ]] || die "Invalid log directory: $OPT_LOG_PATH"

  run mkdir -p -- "$log_dir"

  if (( OPT_DRY_RUN )); then
    info "Would append logs to: $OPT_LOG_PATH"
    return 0
  fi

  touch -- "$OPT_LOG_PATH" || die "Cannot write to log file: $OPT_LOG_PATH"
  exec > >(tee -a -- "$OPT_LOG_PATH") 2>&1
  info "Logging to: $OPT_LOG_PATH"
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
  fi
  info "OS: ${OS_ID:-unknown}${OS_ID_LIKE:+ (like: $OS_ID_LIKE)}"
}

detect_pkg_mgr() {
  if   has apt-get; then PKG_MGR="apt"
  elif has dnf;     then PKG_MGR="dnf"
  elif has pacman;  then PKG_MGR="pacman"
  elif has zypper;  then PKG_MGR="zypper"
  elif has apk;     then PKG_MGR="apk"
  else die "No supported package manager found (apt/dnf/pacman/zypper/apk)."
  fi
  info "Package manager: ${BOLD}${PKG_MGR}${RESET}"
}

apt_upgrade() {
  require_cmd apt-get
  export DEBIAN_FRONTEND=noninteractive
  local yflag=(); (( OPT_YES )) && yflag=(-y)

  run apt-get update

  if (( OPT_ONLY_SECURITY )); then
    if has unattended-upgrade; then
      info "Security-only via unattended-upgrade"
      run unattended-upgrade --verbose
    else
      warn "--only-security: unattended-upgrade not found — falling back to full-upgrade"
      run apt-get "${yflag[@]}" full-upgrade
    fi
  else
    run apt-get "${yflag[@]}" full-upgrade
  fi

  if (( OPT_CLEAN )); then
    run apt-get "${yflag[@]}" autoremove --purge
    run apt-get autoclean
  fi

  if has snap; then
    info "Refreshing snaps…"
    run snap refresh
  fi
}

dnf_upgrade() {
  require_cmd dnf
  local yflag=(); (( OPT_YES )) && yflag=(-y)

  if (( OPT_ONLY_SECURITY )); then
    run dnf "${yflag[@]}" upgrade --security --refresh
  else
    run dnf "${yflag[@]}" upgrade --refresh
  fi

  if (( OPT_CLEAN )); then
    run dnf -y autoremove
    run dnf clean packages
  fi
}

pacman_upgrade() {
  require_cmd pacman
  local yflag=(); (( OPT_YES )) && yflag=(--noconfirm)
  (( OPT_ONLY_SECURITY )) && warn "--only-security: pacman has no native security-only mode — doing full -Syu"

  run pacman -Syu "${yflag[@]}"

  if (( OPT_CLEAN )) && has paccache; then
    run paccache -r
  fi
}

zypper_upgrade() {
  require_cmd zypper
  local yflag=(); (( OPT_YES )) && yflag=(-y)

  run zypper --non-interactive refresh

  if (( OPT_ONLY_SECURITY )); then
    run zypper --non-interactive patch "${yflag[@]}" --category security
  else
    run zypper --non-interactive update "${yflag[@]}"
  fi

  if (( OPT_CLEAN )); then
    run zypper clean --all
  fi
}

apk_upgrade() {
  require_cmd apk
  local yflag=(); (( OPT_YES )) && yflag=(--no-interactive)
  (( OPT_ONLY_SECURITY )) && warn "--only-security: apk has no native security-only mode — doing full upgrade"

  run apk update
  run apk upgrade "${yflag[@]}"
}

do_upgrade() {
  case "$PKG_MGR" in
    apt)    apt_upgrade ;;
    dnf)    dnf_upgrade ;;
    pacman) pacman_upgrade ;;
    zypper) zypper_upgrade ;;
    apk)    apk_upgrade ;;
    *)      die "Internal error: unknown PKG_MGR=$PKG_MGR" ;;
  esac
}

needs_reboot_debian() { [[ -f /var/run/reboot-required ]]; }

needs_reboot_fedora() {
  has needs-restarting || return 1
  ! needs-restarting -r >/dev/null 2>&1
}

needs_reboot() { needs_reboot_debian || needs_reboot_fedora; }

handle_reboot() {
  if needs_reboot; then
    warn "A reboot is recommended."
    if (( OPT_REBOOT_IF_NEEDED )); then
      if (( OPT_DRY_RUN )); then
        dry "would reboot now"
        return 0
      fi
      warn "Rebooting in 5 seconds — Ctrl-C to abort"
      sleep 5
      run reboot
    else
      info "Pass --reboot-if-needed to reboot automatically."
    fi
  else
    info "No reboot required."
  fi
}

print_banner() {
  printf "\n"
  printf "  ${BOLD}${BLUE}┌─────────────────────────────────────────┐${RESET}\n"
  printf "  ${BOLD}${BLUE}│${RESET}  ${BOLD}${WHITE}update.sh${RESET}  ${DIM}v${SCRIPT_VERSION}                         ${BOLD}${BLUE}│${RESET}\n"
  printf "  ${BOLD}${BLUE}│${RESET}  ${DIM}multi-distro system updater              ${RESET}${BOLD}${BLUE}│${RESET}\n"
  printf "  ${BOLD}${BLUE}└─────────────────────────────────────────┘${RESET}\n"
  printf "\n"
}

main() {
  parse_args "$@"
  ensure_root
  print_banner
  setup_logging

  step "System detection"
  detect_os
  detect_pkg_mgr

  (( OPT_DRY_RUN ))       && warn "Dry-run mode — no changes will be made"
  (( OPT_ONLY_SECURITY )) && info "Security-only mode enabled"
  (( OPT_CLEAN == 0 ))    && info "Cleanup disabled (--no-clean)"

  step "Running upgrade  [${PKG_MGR}]"
  do_upgrade

  step "Post-upgrade checks"
  handle_reboot

  printf "\n  ${BOLD}${GREEN}Done!${RESET}\n\n"
}

main "$@"