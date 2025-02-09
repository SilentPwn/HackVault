ZSH_THEME="robbyrussell"
DISABLE_AUTO_TITLE="true"
plugins=(git eza zsh-autosuggestions grc sudo colorize zsh-syntax-highlighting tmux)
ZSH_COLORIZE_STYLE="colorful"
ZSH_TMUX_AUTOSTART=true
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
alias nmap="grc nmap"
alias ll="eza -l --color=always --group-directories-first --icons"
alias la="eza -la --color=always --group-directories-first --icons"
lr() { eza -la --color=always --group-directories-first --tree --level="${1:-1}" --icons }
