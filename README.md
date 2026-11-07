# Configuration

## .zshrc

- set for root's `.zshrc` file the option `ZSH_TMUX_AUTOSTART` to false 

## .config/zsh/tmux-logging.zsh

- only for non-root user

## .tmux.conf

- only for non-root user

# Features

## Tmux Logging

```
mkdir -p ~/logs/tmux
```

Indicated by a red "[REC]" sign (bottom right)

- start_logging [SUBDIR]: starts tmux logging, directory argument optional
- stop_logging: stops tmux logging
