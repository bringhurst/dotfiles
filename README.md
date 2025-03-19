# Personal dotfiles

Just my personal dotfiles.

## Install

### (Linux) Install bitwarden:
```
wget -P ~/bin -O ~/bin/bw "https://bitwarden.com/download/?app=cli&platform=linux"
unzip -o ~/bin/bw -d ~/bin
chmod 0755 ~/bin/bw
export PATH="~/bin:$PATH"
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
