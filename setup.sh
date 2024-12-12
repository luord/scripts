#!/usr/bin/env bash
set -ex -o pipefail

CONFIG_DIR=${CONFIG_DIR:-$HOME/Documentos/config}

sudo systemctl mask \
  sleep.target suspend.target hibernate.target hybrid-sleep.target

sudo sed -i 's/trixie/testing/g' /etc/apt/sources.list
sudo apt update
sudo apt dist-upgrade -y

sudo apt install --no-install-recommends \
  gdm3 gnome-session gnome-shell gnome-terminal gnome-music totem

sudo apt install \
  gnome-shell-extension-prefs transmission-gtk rclone curl \
  python3-venv nodejs neovim git make shellcheck

_tailscale () {
  if command -v tailscale; then
    printf "already installed\n"
  else
    wget -O - https://tailscale.com/install.sh | sh
    sudo tailscale up
  fi
}

_tailscale

_nvim () {
  if [[ -d ~/.config/nvim/pack/github/start/copilot.vim ]]; then
    printf "already set up\n"
  else
    git clone https://github.com/github/copilot.vim.git ~/.config/nvim/pack/github/start/copilot.vim
    nvim --headless +"Copilot setup" +q
  fi
}

_nvim

_chrome () {
  if command -v google-chrome; then
    printf "already installed\n"
  else
    curl -fSsL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg >> /dev/null
    echo deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main | sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt update
    sudo apt install google-chrome-stable 
  fi
}

_chrome

_nft () {
  sudo cp "$CONFIG_DIR/nftables.conf" /etc/nftables.conf
  sudo systemctl enable nftables
  printf "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/95-IPv4-forwarding.conf
  sudo sysctl -p /etc/sysctl.d/95-IPv4-forwarding.conf
}

_nft

_rclone () {
  if [[ -f ~/.config/rclone/rclone.conf ]]; then
    printf "already set up\n"
  else
    mkdir -p ~/.config/rclone
    cp "$CONFIG_DIR/rclone.conf" ~/.config/rclone/rclone.conf
    rclone --filter "- .**" bisync ~/Música remote:Music --resync --remove-empty-dirs
    rclone --filter "- .**" bisync ~/Vídeos remote:Videos --resync --remove-empty-dirs
    rclone --filter "- .**" bisync ~/Imágenes remote:Pictures --resync --remove-empty-dirs
    rclone --filter "- .**" bisync ~/Documentos remote:Documents --resync --remove-empty-dirs
  fi
}

_rclone

_cron () {
  if crontab -l >/dev/null 2>&1; then
    printf "already set up\n"
  else
    crontab "$CONFIG_DIR/crontab.txt"
  fi
}

_cron

_docker () {
  if command -v docker; then
    printf "already installed\n"
  else
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      bookworm stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install docker-ce uidmap
    sudo systemctl disable --now docker.service docker.socket
    sudo rm /var/run/docker.sock
    dockerd-rootless-setuptool.sh install
    systemctl --user enable docker
  fi
}

_docker

printf "done!\n"

read -n 1 -s -r -p "Press y to reboot: " reply
[[ $reply == "y" ]] && sudo reboot
