pacman -S zsh gh lolcat figlet ripgrep eza neovim tmux zoxide figlet lolcat ttf-jetbrains-mono-nerd wl-clipboard ghostty 

pacman -S starship 

sudo pacman -S git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

if [ ! -d "~/dev/yay" ]; then
  echo "Cloning yay into ~/dev..."
  git clone https://aur.archlinux.org/yay.git ~/dev/yay
  makepkg -si -C ~/dev/yay
fi

yay -Ss neovim-git
