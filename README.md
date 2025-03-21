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

## Reset origin
```
chezmoi cd
git remote rm origin
git remote add origin git@github.com:bringhurst/dotfiles.git
```
