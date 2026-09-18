# tmux-harbor

A harbor for your repos. Every repo directory and git worktree docks here;
pick one with fzf, then choose how to set sail: a session, a window, or a split.

## Requirements

tmux 3.2+ (for `display-popup`), fzf, git.

## Install

With [tpm](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'ddzero2c/tmux-harbor'
set -g @harbor-key 'o'
```

Press `prefix + I` to install.

## Usage

`prefix + <@harbor-key>` opens the picker. No key is bound unless you set
`@harbor-key`. You can also bind the launcher yourself, e.g. without the prefix:

```tmux
bind -n M-o run-shell "~/.tmux/plugins/tmux-harbor/scripts/launch.sh '#{q:client_name}' '#{session_id}' '#{pane_id}'"
```

Default keys inside the picker (each is configurable, see Options):

| Key      | Action                                                   |
| -------- | -------------------------------------------------------- |
| `enter`  | open (or attach to) a session named after the directory  |
| `ctrl-t` | new window in the current session at that directory      |
| `ctrl-s` | horizontal split (below the current pane)                |
| `ctrl-v` | vertical split (right of the current pane)               |
| `ctrl-n` | create a git worktree in the selected repo (asks for a branch name) and open a session for it |
| `ctrl-x` | if the entry is a worktree: remove it, its branch and session (asks first) |

Session names are the directory basename with `.` and `:` replaced by `_`.

### CLI

`scripts/harbor.sh` also works from a shell, e.g. from other scripts:

```bash
harbor.sh open ~/repo/foo            # open/attach session for the dir
harbor.sh open ~/repo/foo 'claude'   # ...and type a command into the new session
harbor.sh list                       # print candidate directories
```

## Options

```tmux
set -g @harbor-key 'o'                      # prefix key (unset = no binding)
set -g @harbor-paths '~/repo ~/work'        # dirs whose children are listed (default: ~)
set -g @harbor-worktrees-dir '.claude/worktrees' # worktree dir under each repo
set -g @harbor-worktree-cmd 'claude'          # typed into a new worktree's session
set -g @harbor-worktree-copy '.env'           # find -name pattern copied into new worktrees
set -g @harbor-worktree-copy-depth '2'        # directory levels to search, e.g. packages/app/.env
set -g @harbor-popup-width '80%'
set -g @harbor-popup-height '80%'
set -g @harbor-fzf-key-window 'ctrl-t'           # fzf keys, in fzf key syntax: new window
set -g @harbor-fzf-key-split 'ctrl-s'            # horizontal split
set -g @harbor-fzf-key-vsplit 'ctrl-v'           # vertical split
set -g @harbor-fzf-key-worktree 'ctrl-n'          # new worktree
set -g @harbor-fzf-key-remove-worktree 'ctrl-x'   # remove worktree
```

`@harbor-paths` takes space separated values. For each `<path>`, every
`<path>/*` is listed, plus every `<path>/*/<@harbor-worktrees-dir>/*`. Entries
under the worktrees dir are the ones `ctrl-x` can remove. Set
`@harbor-worktrees-dir ''` to disable worktree listing and creation.

### Worktrees

`ctrl-n` on a repo (or on one of its worktrees) asks for a branch name and
creates `<repo>/<@harbor-worktrees-dir>/<branch>` (with `/` replaced by `-`).
An existing local branch is checked out; otherwise the branch is created from
`origin/<branch>` when it exists, else from origin's default branch. Files
matching `@harbor-worktree-copy` (searched `@harbor-worktree-copy-depth` directory
levels below the main checkout, so `packages/app/.env` is included by default) are copied over, then a session opens for the new
worktree and `@harbor-worktree-cmd`, when set, is typed into it.

## Credits

Inspired by [ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer).
The original idea of "fzf a directory, jump to a tmux session named after it"
is his; this plugin builds on it with worktree listing, window/split actions
and tpm packaging. Thanks, Prime.
