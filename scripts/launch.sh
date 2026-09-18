#!/usr/bin/env bash
# launch.sh <client> <session_id> <pane_id>
# Opens the picker in a popup attached to <client> (or in a new window when
# @harbor-popup is off), forwarding the origin pane so window/split
# actions land in the right place.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$CURRENT_DIR/helpers.sh"

client=$1 session=$2 pane=$3
picker="$CURRENT_DIR/harbor.sh"

cmd="$(printf '%q pick %q %q %q' "$picker" "$client" "$session" "$pane")"

if [ "$(get_tmux_option @harbor-popup 'on')" = 'on' ]; then
  tmux display-popup -E -c "$client" \
    -w "$(get_tmux_option @harbor-popup-width '80%')" \
    -h "$(get_tmux_option @harbor-popup-height '80%')" \
    "$cmd"
else
  tmux new-window -t "$session:" -n harbor "$cmd"
fi
