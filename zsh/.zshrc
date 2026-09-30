HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
autoload -Uz compinit
compinit -d "$HOME/.zcompdump"
eval "$(starship init zsh)"

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
