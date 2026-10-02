# Personal dotfiles

Just my personal dotfiles.

## Install

### (Linux) Install bitwarden:
```
# If on debian
# sudo apt-get install unzip

mkdir -p ~/bin
wget -P ~/bin -O ~/bin/bw "https://bitwarden.com/download/?app=cli&platform=linux"
unzip -o ~/bin/bw -d ~/bin
chmod 0755 ~/bin/bw
export PATH="~/bin:$PATH"
```

### (Linux, personal hosts only) Install atuin

**Do not install or initialize Atuin on LinkedIn hosts.** Use McFly below instead.

```
# If on debian
# sudo apt-get install curl

curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
export PATH="~/.atuin/bin:$PATH"
hash -r
atuin login
atuin sync
```

### (Mac) Install bitwarden
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install bitwarden-cli
```

### Install:
```
hash -r
bw login
export BW_SESSION=$(bw unlock --raw)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply bringhurst
```

## Local shell history

`~/.config/shell/history.sh` configures both Bash and Zsh:

- Hosts ending in `linkedin.biz` or `linkedin.com` use **McFly**, never Atuin.
  McFly stores its search index in local SQLite; there is no cloud sync,
  telemetry, account, or background service. Ctrl-R searches across terminals
  and across Bash/Zsh. Results use fuzzy matching, sorted by most recent use.
- Other hosts keep Atuin. Native history and the archive below work on all hosts,
  even when neither search tool is installed.
- Native history files remain `~/.bash_history` and `~/.zsh_history`. Both append
  without overwriting other sessions. Zsh shares entries live, using file locking;
  Bash keeps arrow-key recall session-local, with other sessions available through
  Ctrl-R or on startup. This avoids Bash 3.2's incremental-import problems.
- Bash has no on-disk history-size limit. Zsh keeps 100,000 saved commands and
  200,000 in memory; Bash keeps 100,000 in memory. **These are recall caches, not
  the permanent archive.** macOS Terminal's expiring per-window history is disabled.

### Install and enable

On macOS (or Linux with Homebrew):

```sh
brew install mcfly
```

The macOS chezmoi package script also chooses McFly instead of Atuin on LinkedIn
hosts. It does not uninstall an existing Atuin installation or delete its data.
On Linux without Homebrew, install an approved McFly release into `~/bin`, or,
with Rust installed, run `cargo install --locked mcfly`. See
[McFly's installation instructions](https://github.com/cantino/mcfly#installation).

Apply only the shell files, without triggering unrelated package/secret setup:

```sh
chezmoi apply --exclude scripts ~/.config/shell/history.sh ~/.bashrc ~/.zshrc
```

Then open new terminals, or run `source ~/.zshrc` / `source ~/.bashrc` in **each
existing terminal**. Old shells retain their old history limits until reloaded.
The configuration is safe to source repeatedly. McFly automatically imports the
native history of the first shell to initialize its database; existing history
from both shells is also preserved in the native files and archive snapshots.

### Storage and retention

All history is runtime data, not managed by chezmoi or committed to this repo:

| Data | Location | Retention |
| --- | --- | --- |
| McFly SQLite search index | `~/.mcfly/history.db` | No automatic pruning or search-history limit |
| Complete command archive | `${XDG_STATE_HOME:-~/.local/state}/shell-history/*.log.*` | Append-only; no rotation or deletion |
| Original native history snapshots | Same directory, `bash.before.history` / `zsh.before.history` | Created once, never replaced |

The archive has one file per shell session, so terminals cannot overwrite one
another. Each submitted command is written **before execution**, including
commands followed by `exec`, `exit`, or a killed terminal. Each line contains a
Unix timestamp, a shell-escaped working directory, and a shell-escaped command,
separated by tabs. Multiline commands, repeated commands, and leading whitespace
are preserved. Search it as text; **do not source/evaluate archive files**:

```sh
rg -- 'trigger-build' "${XDG_STATE_HOME:-$HOME/.local/state}/shell-history"
```

McFly intentionally skips some commands (including `ls`, `pwd`, and consecutive
duplicates). It indexes completed commands at the next prompt. The archive is
therefore the complete record, including anything McFly skips or cannot index.
Our hooks pass complete commands to McFly instead of using its lossy stock
last-line recorder. New entries may take a second to appear in search. McFly's
UI can still have limitations when editing multiline
entries; consult the archive for the original command.

**Privacy:** the archive deliberately records everything, including commands
starting with spaces and commands containing secrets. History directories are
owner-only (700), and new archive/database files are 600. Deleting an entry from
McFly does **not** erase it from the independent archive or existing backups.
Avoid putting credentials in command arguments.

No retention limit is not a guarantee against disk failure, a full disk, or power
loss before a write reaches storage. Use approved local/offline backups for both
the archive and SQLite database. Make a consistent database backup using SQLite,
not by copying a live database file:

```sh
sqlite3 "$HOME/.mcfly/history.db" ".backup '$HOME/.mcfly/history-backup.db'"
```

Copy that backup and the archive to your approved backup storage. Nothing in
this setup uploads or synchronizes work history.

### Verify changes

From the chezmoi source directory, run `python3 -m unittest discover -s tests -v`.
The tests use temporary homes and real interactive terminals, exercise Bash 3.2,
modern Bash, and Zsh when installed, and never invoke the real Atuin or SSH agent.

## Directory-specific GitHub accounts

The `.envrc` files in `~/code/li` and `~/code/gh` use direnv to select the
`jbringhu_LinkedIn` and `bringhurst` GitHub accounts, respectively. Both Bash and
Zsh already have direnv hooks configured. This requires `direnv`, `gh`, and both
accounts to be logged in with `gh auth login --hostname github.com`.

Apply the files and approve them locally (approval is not stored in this repo):

```sh
chezmoi apply --exclude scripts ~/code/li/.envrc ~/code/gh/.envrc
direnv allow ~/code/li
direnv allow ~/code/gh
```

Tokens are retrieved from gh's saved credentials at runtime, not stored in these
files. `GH_TOKEN` is inherited by commands such as `trigger-build` and the HTTPS
Git credential helper, without changing gh's globally active account. Direnv
restores the previous environment when leaving either directory tree. Existing
Git settings still handle commit identity and SSH key selection.

Verify the accounts, or run a command from a noninteractive shell:

```sh
direnv exec ~/code/li gh api user --jq .login  # jbringhu_LinkedIn
direnv exec ~/code/gh gh api user --jq .login  # bringhurst
direnv exec ~/code/li trigger-build -p northguard-buildenv
```

A repository with its own `.envrc` must call `source_up` to load the parent
account settings. After changing any `.envrc`, review it and run `direnv allow`
again. If saved credentials change, run `direnv reload` in the affected tree.

## Reset origin
```
chezmoi cd
git remote rm origin
git remote add origin git@github.com:bringhurst/dotfiles.git
```
