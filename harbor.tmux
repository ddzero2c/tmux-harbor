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
#   @harbor-paths        dirs to list, space separated          (default: ~)
#   @harbor-worktrees-dir  worktree dir under each repo         (default: .claude/worktrees)
#   @harbor-worktree-cmd   command typed into a new worktree session (default: none)
#   @harbor-worktree-copy  find -name pattern copied into new worktrees (default: .env)
#   @harbor-worktree-copy-depth  how deep to look for those files (default: 2)
#   @harbor-popup-width  popup width                            (default: 80%)
#   @harbor-popup-height popup height                           (default: 80%)
#   @harbor-fzf-key-window           fzf key: new window        (default: ctrl-t)
#   @harbor-fzf-key-split            fzf key: horizontal split  (default: ctrl-s)
#   @harbor-fzf-key-vsplit           fzf key: vertical split    (default: ctrl-v)
#   @harbor-fzf-key-new-worktree     fzf key: new worktree      (default: ctrl-w)
#   @harbor-fzf-key-remove-worktree  fzf key: remove worktree   (default: ctrl-x)

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
