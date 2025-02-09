ZSH_THEME="robbyrussell"
DISABLE_AUTO_TITLE="true"
plugins=(git eza zsh-autosuggestions grc sudo colorize zsh-syntax-highlighting tmux)
ZSH_COLORIZE_STYLE="colorful"
#set next setting to false for root
ZSH_TMUX_AUTOSTART=true
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
alias nmap="grc nmap"
alias ll="eza -l --color=always --group-directories-first --icons"
alias la="eza -la --color=always --group-directories-first --icons"
lr() { eza -la --color=always --group-directories-first --tree --level="${1:-1}" --icons }
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# alt+c is directory tree with preview in eza
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix"
export FZF_DEFAULT_OPTS="--height 70% --layout=reverse --border --color=hl:#2dd4bf"
# fzf default for tmux, change window size to preference
export FZF_TMUX_OPTS=" -p100%,100% "
# pwd without nano
#export FZF_CTRL_T_OPTS="--preview 'batcat --color=always -n --line-range :500 {}'"
# open with nano, or your editor of choice
export FZF_CTRL_T_OPTS="--preview 'batcat --color=always -n --line-range :500 {}' --bind 'enter:execute(nano {})'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
eval "$(zoxide init zsh)"
