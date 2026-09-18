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
set -g @harbor-worktrees '.claude/worktrees' # worktree subdirs under each child
set -g @harbor-popup-width '80%'
set -g @harbor-popup-height '80%'
set -g @harbor-key-window 'ctrl-t'           # fzf keys, in fzf key syntax: new window
set -g @harbor-key-split 'ctrl-s'            # horizontal split
set -g @harbor-key-vsplit 'ctrl-v'           # vertical split
set -g @harbor-key-remove 'ctrl-x'           # remove worktree
```

`@harbor-paths` and `@harbor-worktrees` take space separated values.
For each `<path>` in `@harbor-paths`, every `<path>/*` is listed, plus
every `<path>/*/<sub>/*` for each `<sub>` in `@harbor-worktrees`. Entries
under a worktree subdir are the ones `ctrl-x` can remove. Set
`@harbor-worktrees ''` to disable worktree listing.

## Credits

Inspired by [ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer).
The original idea of "fzf a directory, jump to a tmux session named after it"
is his; this plugin builds on it with worktree listing, window/split actions
and tpm packaging. Thanks, Prime.
