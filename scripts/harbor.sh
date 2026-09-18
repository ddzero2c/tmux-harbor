#!/usr/bin/env bash
# tmux-harbor core.
#
#   harbor.sh pick [client] [session_id] [pane_id]   fzf picker (default)
#   harbor.sh open <dir> [init_cmd]                   open/attach session for <dir>
#   harbor.sh window <session_id> <dir>               new window in <session_id>
#   harbor.sh hsplit <pane_id> <dir>                  split below <pane_id>
#   harbor.sh vsplit <pane_id> <dir>                  split right of <pane_id>
#   harbor.sh remove <dir>                            delete the worktree at <dir>
#   harbor.sh worktree <repo-or-worktree> <branch>     create a worktree for <branch> and open it
#   harbor.sh list                                    print candidate dirs
#
# Picker keys (defaults; override with @harbor-fzf-key-<action>):
#   enter   open (or attach to) a session named after the directory
#   ctrl-t  new window in the current session            (@harbor-fzf-key-window)
#   ctrl-s  horizontal split (below) in the current pane (@harbor-fzf-key-split)
#   ctrl-v  vertical split (right) in the current pane   (@harbor-fzf-key-vsplit)
#   ctrl-x  delete the selected worktree, branch, session (@harbor-fzf-key-remove-worktree)
#   ctrl-w  create a worktree in the selected repo        (@harbor-fzf-key-new-worktree)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$CURRENT_DIR/helpers.sh"

SELF="$CURRENT_DIR/harbor.sh"

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------

search_paths() {
  local raw p
  raw="$(get_tmux_option @harbor-paths '~')"
  for p in $raw; do
    expand_tilde "$p"
    echo
  done
}

worktrees_dir() {
  get_tmux_option @harbor-worktrees-dir '.claude/worktrees'
}

# ----------------------------------------------------------------------------
# Listing
# ----------------------------------------------------------------------------

# Absolute candidate directories: every direct child of each search path,
# followed by every direct child of <child>/<worktree-subdir>.
candidates() {
  local root sub
  sub="$(worktrees_dir)"
  while IFS= read -r root; do
    [ -d "$root" ] || continue
    find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
    [ -n "$sub" ] && find "$root"/*/"$sub" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  done < <(search_paths)
}

# Same list with $HOME shown as ~ so entries stay short in fzf.
list() {
  candidates | sed "s|^$HOME/|~/|" | sort
}

# ----------------------------------------------------------------------------
# Worktree detection / removal
# ----------------------------------------------------------------------------

# worktree_root <dir>
# Prints the main repo path when <dir> sits at <repo>/<worktrees-dir>/<name>;
# prints nothing (and fails) otherwise.
worktree_root() {
  local dir=$1 sub parent
  sub="$(worktrees_dir)"
  [ -n "$sub" ] || return 1
  parent="$(dirname "$dir")"
  if [ "${parent%/"$sub"}" != "$parent" ]; then
    printf '%s' "${parent%/"$sub"}"
    return 0
  fi
  return 1
}

# worktree_branch <dir>
# Branch checked out in <dir>; empty when HEAD is detached. Asked of the
# worktree itself: `git worktree list --porcelain` octal-escapes non-ASCII
# paths, which makes matching on them unreliable.
worktree_branch() {
  git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null
}

remove() {
  local dir repo branch answer
  dir="$(expand_tilde "$1")"
  [ -n "$dir" ] || return 0

  if ! repo="$(worktree_root "$dir")"; then
    echo "Not a worktree: $dir"
    echo "Press any key to continue."
    read -rn 1
    return 0
  fi

  branch="$(worktree_branch "$dir")"
  echo "Remove worktree $dir"
  [ -n "$branch" ] && echo "  and delete branch $branch"
  printf 'Continue? [y/N] '
  read -r answer
  case $answer in
    y | Y) ;;
    *) return 0 ;;
  esac

  git -C "$repo" worktree remove --force "$dir" 2>/dev/null || true
  git -C "$repo" worktree prune
  [ -d "$dir" ] && rm -rf "$dir"
  [ -n "$branch" ] && git -C "$repo" branch -D "$branch" 2>/dev/null
  tmux kill-session -t "=$(session_name_for "$dir")" 2>/dev/null
  return 0
}

# ----------------------------------------------------------------------------
# Worktree creation
# ----------------------------------------------------------------------------

branch_exists() {
  git -C "$1" show-ref --verify --quiet "$2"
}

default_branch() {
  local branch
  branch="$(git -C "$1" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
  printf '%s' "${branch:-main}"
}

# create_worktree <repo> <branch> <path>
# Checks out an existing local branch, otherwise branches off origin/<branch>
# when it exists, else off origin's default branch.
create_worktree() {
  local repo=$1 branch=$2 path=$3 start

  if branch_exists "$repo" "refs/heads/$branch"; then
    echo "Checking out existing branch $branch..."
    git -C "$repo" worktree add "$path" "$branch"
    return
  fi

  if branch_exists "$repo" "refs/remotes/origin/$branch"; then
    start="origin/$branch"
  else
    start="origin/$(default_branch "$repo")"
  fi
  echo "Creating branch $branch from $start..."
  git -C "$repo" worktree add "$path" -b "$branch" "$start"
  git -C "$repo" branch --unset-upstream "$branch" 2>/dev/null || true
}

# copy_untracked <repo> <dest>
# Copies files matching @harbor-worktree-copy (a find -name pattern, default
# .env) from the main checkout into the new worktree. @harbor-worktree-copy-depth
# is how many directory levels below the repo root to search: 2 (the default)
# finds ./.env, ./app/.env and ./packages/app/.env, so monorepos are covered.
copy_untracked() {
  local repo=$1 dest=$2 pattern depth f
  pattern="$(get_tmux_option @harbor-worktree-copy '.env')"
  depth="$(get_tmux_option @harbor-worktree-copy-depth '2')"
  [ -n "$pattern" ] || return 0
  (cd "$repo" && find . -maxdepth "$((depth + 1))" -name "$pattern" -type f -not -path './.git/*' -not -path "./$(worktrees_dir)/*") |
    while IFS= read -r f; do
      mkdir -p "$dest/$(dirname "$f")"
      cp "$repo/$f" "$dest/$f"
    done
}

# worktree <repo-or-worktree> <branch> [client]
# Creates <repo>/<worktrees-dir>/<branch with / replaced by -> and opens a
# session for it, typing @harbor-worktree-cmd into it when set.
worktree() {
  local base repo branch=$2 client=$3 sub path
  base="$(expand_tilde "$1")"
  [ -n "$base" ] && [ -n "$branch" ] || return 0

  repo="$(worktree_root "$base")" || repo="$base"
  sub="$(worktrees_dir)"
  if [ -z "$sub" ]; then
    echo "@harbor-worktrees-dir is empty; cannot create worktrees"
    return 1
  fi
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not a git repository: $repo"
    return 1
  fi

  path="$repo/$sub/$(printf '%s' "$branch" | tr '/' '-')"
  if [ ! -d "$path" ]; then
    create_worktree "$repo" "$branch" "$path" || return 1
    copy_untracked "$repo" "$path"
  fi
  open "$path" "$(get_tmux_option @harbor-worktree-cmd '')" "$client"
}

# ----------------------------------------------------------------------------
# Actions
# ----------------------------------------------------------------------------

has_session() {
  tmux has-session -t "=$1" 2>/dev/null
}

# open <dir> [init_cmd] [client]
open() {
  local dir name
  dir="$(expand_tilde "$1")"
  [ -n "$dir" ] || return 0
  name="$(session_name_for "$dir")"

  if ! has_session "$name"; then
    tmux new-session -ds "$name" -c "$dir"
    # "=name" is exact-match only for session targets; pane targets need "=name:".
    [ -n "$2" ] && tmux send-keys -t "=$name:" "$2" Enter
  fi

  if [ -n "$3" ]; then
    tmux switch-client -c "$3" -t "=$name"
  elif [ -z "$TMUX" ]; then
    tmux attach-session -t "=$name"
  else
    tmux switch-client -t "=$name"
  fi
}

window() {
  tmux new-window -t "$1:" -c "$(expand_tilde "$2")"
}

hsplit() {
  tmux split-window -v -t "$1" -c "$(expand_tilde "$2")"
}

vsplit() {
  tmux split-window -h -t "$1" -c "$(expand_tilde "$2")"
}

# ----------------------------------------------------------------------------
# Picker
# ----------------------------------------------------------------------------

pick() {
  local client=$1 session=$2 pane=$3
  local k_window k_split k_vsplit k_remove k_worktree out key selected branch

  for dep in tmux fzf; do
    command -v "$dep" >/dev/null 2>&1 || { echo "$dep is not installed"; exit 1; }
  done

  k_window="$(get_tmux_option @harbor-fzf-key-window 'ctrl-t')"
  k_split="$(get_tmux_option @harbor-fzf-key-split 'ctrl-s')"
  k_vsplit="$(get_tmux_option @harbor-fzf-key-vsplit 'ctrl-v')"
  k_remove="$(get_tmux_option @harbor-fzf-key-remove-worktree 'ctrl-x')"
  k_worktree="$(get_tmux_option @harbor-fzf-key-new-worktree 'ctrl-w')"

  # ctrl-s is XOFF on most ttys; without this fzf never sees it.
  stty -ixon 2>/dev/null

  out="$(
    list | fzf \
      --expect="$k_window,$k_split,$k_vsplit,$k_worktree" \
      --bind "$k_remove:execute($SELF remove {})+reload($SELF list)" \
      --header "enter:session  $k_window:window  $k_split:split  $k_vsplit:vsplit  $k_worktree:new worktree  $k_remove:remove worktree"
  )" || return 0

  key="$(printf '%s\n' "$out" | sed -n 1p)"
  selected="$(printf '%s\n' "$out" | sed -n 2p)"
  [ -n "$selected" ] || return 0

  # The window/split actions need an origin; outside a binding (plain CLI
  # use) fall back to the current session/pane.
  if [ -n "$TMUX" ]; then
    [ -n "$session" ] || session="$(tmux display-message -p '#{session_id}')"
    [ -n "$pane" ] || pane="$(tmux display-message -p '#{pane_id}')"
  fi

  case $key in
    "$k_window") window "$session" "$selected" ;;
    "$k_split") hsplit "$pane" "$selected" ;;
    "$k_vsplit") vsplit "$pane" "$selected" ;;
    "$k_worktree")
      printf 'Branch name: '
      read -r branch
      [ -n "$branch" ] || return 0
      if ! worktree "$selected" "$branch" "$client"; then
        echo "Press any key to close."
        read -rn 1
      fi
      ;;
    *) open "$selected" '' "$client" ;;
  esac
}

# ----------------------------------------------------------------------------
# Entry
# ----------------------------------------------------------------------------

case ${1:-pick} in
  pick) pick "$2" "$3" "$4" ;;
  list) list ;;
  open) open "$2" "$3" ;;
  window) window "$2" "$3" ;;
  hsplit) hsplit "$2" "$3" ;;
  vsplit) vsplit "$2" "$3" ;;
  remove) remove "$2" ;;
  worktree) worktree "$2" "$3" ;;
  -*) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  *) open "$1" "$2" ;;   # legacy: harbor.sh <dir> [init_cmd]
esac
