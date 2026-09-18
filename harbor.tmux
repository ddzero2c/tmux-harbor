#!/usr/bin/env bash
# tmux-harbor
#
# A harbor for your repos: every repo directory and git worktree docks here.
# Pick one with fzf and choose how to set sail: session, window or split.
# tpm runs this file on tmux startup; it reads user options and installs
# the key binding.
#
# Options (set -g @harbor-<name> '<value>' before running tpm):
#   @harbor-key          prefix key that opens the picker      (default: none)
#   @harbor-paths        dirs to list, space separated          (default: ~/repo)
#   @harbor-worktrees    worktree subdirs under each listed dir (default: .claude/worktrees)
#   @harbor-popup        on = display-popup, off = new window   (default: on)
#   @harbor-popup-width  popup width                            (default: 80%)
#   @harbor-popup-height popup height                           (default: 80%)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

key="$(get_tmux_option @harbor-key '')"

# No key is bound unless the user sets @harbor-key.
[ -n "$key" ] || exit 0

# #{client_name} / #{session_id} / #{pane_id} are expanded by run-shell when
# the binding fires, so the picker knows exactly which pane to split even
# though it runs in a popup (or a throwaway window) of its own.
tmux bind-key "$key" \
  run-shell "$CURRENT_DIR/scripts/launch.sh '#{q:client_name}' '#{session_id}' '#{pane_id}'"
