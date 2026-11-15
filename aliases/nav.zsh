alias ls='eza --icons --git'
alias ll='eza --icons --git -la'
alias lt='eza --icons --git --tree --level=2'
alias cat='bat --style=plain'
alias find='fd'
alias cd='z'
alias cdi='zi'

# cdf: fzf a file or dir, then cd into its location
#   dir  -> cd into it
#   file -> cd into its parent dir
cdf() {
  local sel
  sel=$(fd --hidden --type f --type d "$@" | fzf --prompt='cd> ')
  [[ -z "$sel" ]] && return 1
  [[ -d "$sel" ]] && cd "$sel" || cd "${sel:h}"
}
