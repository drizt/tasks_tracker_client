#!/usr/bin/env bash

set -euo pipefail

app_name="Tasks Tracker"
executable="tasks_tracker_client.exe"
build_release=1

usage() {
  cat <<EOF
Usage: deploy/install-windows.sh [options]

Build and install the Tasks Tracker Windows desktop app from MSYS2.

Options:
  --no-build                 Install the existing release bundle
  --install-dir DIR          App bundle directory
                             [%LOCALAPPDATA%\\Programs\\$app_name]
  --shortcut-dir DIR         Start Menu shortcut directory
                             [%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs]
  -h, --help                 Show this help
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v cygpath >/dev/null || die 'cygpath is required; run this script from MSYS2'
[[ -n "${LOCALAPPDATA:-}" ]] || die 'LOCALAPPDATA is not set'
[[ -n "${APPDATA:-}" ]] || die 'APPDATA is not set'

install_dir="$(cygpath -u "$LOCALAPPDATA")/Programs/$app_name"
shortcut_dir="$(cygpath -u "$APPDATA")/Microsoft/Windows/Start Menu/Programs"

to_msys_path() {
  local path="$1"

  if [[ "$path" =~ ^[[:alpha:]]:[/\\] ]] || [[ "$path" == \\\\* ]]; then
    cygpath -u "$path"
  else
    printf '%s\n' "$path"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      build_release=0
      shift
      ;;
    --install-dir)
      install_dir="${2:-}"
      [[ -n "$install_dir" ]] || die '--install-dir requires a value'
      install_dir="$(to_msys_path "$install_dir")"
      shift 2
      ;;
    --shortcut-dir)
      shortcut_dir="${2:-}"
      [[ -n "$shortcut_dir" ]] || die '--shortcut-dir requires a value'
      shortcut_dir="$(to_msys_path "$shortcut_dir")"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
bundle_dir="$project_dir/build/windows/x64/runner/Release"

[[ -f "$project_dir/pubspec.yaml" ]] || die 'Run this script from the client checkout'

install_dir_windows="$(cygpath -am "$install_dir")"
if [[ "$install_dir_windows" =~ ^[[:alpha:]]:/*$ ]] ||
  [[ "$install_dir_windows" =~ ^//[^/]+/[^/]+/*$ ]]; then
  die 'Refusing to install to a drive or network-share root'
fi

if command -v powershell.exe >/dev/null; then
  powershell_cmd="powershell.exe"
elif command -v pwsh.exe >/dev/null; then
  powershell_cmd="pwsh.exe"
else
  die 'PowerShell is required to create the Start Menu shortcut'
fi

if [[ $build_release -eq 1 ]]; then
  command -v flutter >/dev/null || die 'flutter is required to build the app'
  (
    cd "$project_dir"
    flutter build windows --release
  )
fi

[[ -f "$bundle_dir/$executable" ]] || die "Missing Windows release bundle: $bundle_dir"

if ! MSYS2_ARG_CONV_EXCL='*' "$powershell_cmd" -NoLogo -NoProfile \
  -NonInteractive -Command \
  'exit [int][bool](Get-Process -Name tasks_tracker_client -ErrorAction SilentlyContinue)'; then
  die 'Close Tasks Tracker before installing'
fi

mkdir -p "$install_dir" "$shortcut_dir"
find "$install_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
cp -a "$bundle_dir/." "$install_dir/"

export TASKS_TRACKER_TARGET="$(cygpath -aw "$install_dir/$executable")"
export TASKS_TRACKER_WORK_DIR="$(cygpath -aw "$install_dir")"
export TASKS_TRACKER_SHORTCUT="$(cygpath -aw "$shortcut_dir/$app_name.lnk")"

MSYS2_ARG_CONV_EXCL='*' "$powershell_cmd" -NoLogo -NoProfile -NonInteractive \
  -Command '
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($env:TASKS_TRACKER_SHORTCUT)
$shortcut.TargetPath = $env:TASKS_TRACKER_TARGET
$shortcut.WorkingDirectory = $env:TASKS_TRACKER_WORK_DIR
$shortcut.Description = "Tasks Tracker"
$shortcut.Save()
'

printf 'Installed Tasks Tracker client to %s\n' "$(cygpath -aw "$install_dir")"
printf 'Start Menu shortcut: %s\n' "$(cygpath -aw "$shortcut_dir/$app_name.lnk")"
