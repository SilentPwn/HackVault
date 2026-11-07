# tmux pane logging
# Source this in ~/.zshrc:
#   source ~/.config/zsh/tmux-logging.zsh
# The [REC] indicator lives in the tmux status bar (status-right in ~/.tmux.conf).

TMUX_LOG_DIR="${TMUX_LOG_DIR:-$HOME/logs/tmux}"

# start_logging [name]
# Logs everything in the current tmux pane to a file.
start_logging() {
  if [[ -z "$TMUX" ]]; then
    echo "[-] Not inside tmux"
    return 1
  fi

  if [[ "$(tmux display -p -t "$TMUX_PANE" '#{pane_pipe}')" == "1" ]]; then
    echo "[!] Already logging to: $(tmux show -pv -t "$TMUX_PANE" @log_file 2>/dev/null)"
    return 1
  fi

  mkdir -p "$TMUX_LOG_DIR"

  local session window pane ts name file
  session=$(tmux display -p -t "$TMUX_PANE" '#S')
  window=$(tmux display -p -t "$TMUX_PANE" '#I')
  pane=$(tmux display -p -t "$TMUX_PANE" '#P')
  ts=$(date +%Y%m%d-%H%M%S)
  name="${1:+${1}_}"
  file="$TMUX_LOG_DIR/${name}${session}-w${window}-p${pane}_${ts}.log"

  {
    echo "===== Logging started: $(date '+%Y-%m-%d %H:%M:%S %Z') ====="
    echo "===== Host: $(hostname)  User: $USER  Pane: ${session}:${window}.${pane} ====="
  } >> "$file"

  tmux pipe-pane -t "$TMUX_PANE" -o "cat >> ${(q)file}"
  tmux set -p -t "$TMUX_PANE" @log_file "$file"
  tmux refresh-client -S

  echo "[+] Logging to: $file"
}

# stop_logging
stop_logging() {
  if [[ -z "$TMUX" ]]; then
    echo "[-] Not inside tmux"
    return 1
  fi

  if [[ "$(tmux display -p -t "$TMUX_PANE" '#{pane_pipe}')" != "1" ]]; then
    echo "[!] Not logging in this pane"
    return 1
  fi

  local file
  file=$(tmux show -pv -t "$TMUX_PANE" @log_file 2>/dev/null)

  tmux pipe-pane -t "$TMUX_PANE"   # no command = close the pipe
  tmux set -pu -t "$TMUX_PANE" @log_file
  tmux refresh-client -S

  [[ -n "$file" ]] && echo "===== Logging stopped: $(date '+%Y-%m-%d %H:%M:%S %Z') =====" >> "$file"
  echo "[+] Logging stopped${file:+: $file}"
}

# logging_status
logging_status() {
  if [[ -n "$TMUX" && "$(tmux display -p -t "$TMUX_PANE" '#{pane_pipe}')" == "1" ]]; then
    echo "[+] Logging ON: $(tmux show -pv -t "$TMUX_PANE" @log_file 2>/dev/null)"
  else
    echo "[-] Logging OFF"
  fi
}

# Strip ANSI color codes from a log for clean reports
# usage: clean_log file.log > file.clean.log
clean_log() {
  sed -r 's/\x1B\[[0-9;?]*[a-zA-Z]//g; s/\x1B\][^\x07]*\x07//g; s/\r//g' "$1"
}
