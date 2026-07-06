#!/usr/bin/env bash

set -euo pipefail

app_id="io.github.drizt.tasks_tracker_client"
executable="tasks_tracker_client"
install_dir="${INSTALL_DIR:-/opt/tasks-tracker-client}"
bin_dir="${BIN_DIR:-/usr/local/bin}"
applications_dir="${APPLICATIONS_DIR:-/usr/local/share/applications}"
icon_dir="${ICON_DIR:-/usr/local/share/icons/hicolor/256x256/apps}"
build_release=1

usage() {
  cat <<EOF
Usage: deploy/install-linux.sh [options]

Build and install the Tasks Tracker Linux desktop app.

Options:
  --no-build                 Install the existing release bundle
  --install-dir DIR          App bundle directory [$install_dir]
  --bin-dir DIR              Symlink directory [$bin_dir]
  --applications-dir DIR     Desktop entry directory [$applications_dir]
  --icon-dir DIR             Icon directory [$icon_dir]
  -h, --help                 Show this help
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
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
      shift 2
      ;;
    --bin-dir)
      bin_dir="${2:-}"
      [[ -n "$bin_dir" ]] || die '--bin-dir requires a value'
      shift 2
      ;;
    --applications-dir)
      applications_dir="${2:-}"
      [[ -n "$applications_dir" ]] || die '--applications-dir requires a value'
      shift 2
      ;;
    --icon-dir)
      icon_dir="${2:-}"
      [[ -n "$icon_dir" ]] || die '--icon-dir requires a value'
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
bundle_dir="$project_dir/build/linux/x64/release/bundle"
desktop_source="$project_dir/linux/runner/resources/$app_id.desktop"
icon_source="$project_dir/linux/runner/resources/app_icon_256.png"

[[ -f "$project_dir/pubspec.yaml" ]] || die 'Run this script from the client checkout'
[[ -f "$desktop_source" ]] || die "Missing desktop entry: $desktop_source"
[[ -f "$icon_source" ]] || die "Missing icon: $icon_source"

if [[ $EUID -eq 0 ]]; then
  sudo_cmd=()
else
  command -v sudo >/dev/null || die 'sudo is required for system install'
  sudo_cmd=(sudo)
fi

if [[ $build_release -eq 1 ]]; then
  (
    cd "$project_dir"
    flutter build linux --release
  )
fi

[[ -x "$bundle_dir/$executable" ]] || die "Missing Linux release bundle: $bundle_dir"

desktop_tmp="$(mktemp)"
trap 'rm -f "$desktop_tmp"' EXIT
sed \
  -e "s|^Exec=.*|Exec=$bin_dir/$executable|" \
  -e "s|^Icon=.*|Icon=$app_id|" \
  "$desktop_source" >"$desktop_tmp"

"${sudo_cmd[@]}" install -d "$install_dir" "$bin_dir" "$applications_dir" "$icon_dir"
"${sudo_cmd[@]}" find "$install_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
"${sudo_cmd[@]}" cp -a "$bundle_dir/." "$install_dir/"
"${sudo_cmd[@]}" ln -sfn "$install_dir/$executable" "$bin_dir/$executable"
"${sudo_cmd[@]}" install -m 0644 "$desktop_tmp" "$applications_dir/$app_id.desktop"
"${sudo_cmd[@]}" install -m 0644 "$icon_source" "$icon_dir/$app_id.png"

if command -v update-desktop-database >/dev/null; then
  "${sudo_cmd[@]}" update-desktop-database "$applications_dir" >/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null; then
  hicolor_dir="$(cd -- "$icon_dir/../../.." && pwd)"
  "${sudo_cmd[@]}" gtk-update-icon-cache -q -t -f "$hicolor_dir" >/dev/null || true
fi

printf 'Installed Tasks Tracker client to %s\n' "$install_dir"
printf 'Launcher: %s/%s\n' "$bin_dir" "$executable"
