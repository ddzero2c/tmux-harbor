#!/usr/bin/env bash
# Shared helpers for tmux-harbor.

# get_tmux_option <option-name> <default>
# Echoes the global tmux option value, or the default when unset/empty.
get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$2"
  fi
}

# expand_tilde <path>
# Turns a leading ~ into $HOME so values from tmux options (which tmux does
# not expand) behave like shell paths.
expand_tilde() {
  case $1 in
    '~') printf '%s' "$HOME" ;;
    '~/'*) printf '%s%s' "$HOME" "${1#\~}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# session_name_for <path>
# tmux rejects '.' and ':' in session names.
session_name_for() {
  basename "$1" | tr '.:' '__'
}
