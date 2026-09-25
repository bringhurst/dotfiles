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

### (Linux) Install atuin
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
