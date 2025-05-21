alias ar="php artisan"
# alias bat="batcat"
alias man="batman"
alias c="clear"
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'
alias clipboard='xclip -sel clip'
alias cd='z'
alias open='xdg-open'

# eval "$(gh copilot alias -- bash)"
#
zz() {
  theme=$(gsettings get org.gnome.desktop.interface color-scheme)
  if [[ $theme == *"prefer-dark"* ]]; then
    zellij options --theme gruvbox-dark
  else
    zellij options --theme gruvbox-light
  fi
}

cat() {
  theme=$(gsettings get org.gnome.desktop.interface color-scheme)
  if [[ $theme == *"prefer-dark"* ]]; then
    bat --theme gruvbox-dark "$1"
  else
    bat --theme gruvbox-light "$1"
  fi
}
