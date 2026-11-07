# tmux logging: start_logging [dir] / stop_logging
# Logs every pane in the current session, including new panes and windows.
#   start_logging            -> ~/logs/tmux/
#   start_logging htb-box    -> ~/logs/tmux/htb-box/
#   start_logging /some/path -> /some/path/

TMUX_LOG_DIR="${TMUX_LOG_DIR:-$HOME/logs/tmux}"

start_logging() {
  [[ -z "$TMUX" ]] && { echo "[-] Not inside tmux"; return 1; }

  local s=$(tmux display -p '#S') p n=0
  if [[ "$(tmux show -v -t "$s" @logging 2>/dev/null)" == "1" ]]; then
    echo "[!] Already logging session '$s'"
    return 1
  fi

  # optional argument: folder name (inside $TMUX_LOG_DIR) or an absolute path
  local dir="$TMUX_LOG_DIR"
  if [[ -n "$1" ]]; then
    [[ "$1" == /* ]] && dir="$1" || dir="$TMUX_LOG_DIR/$1"
  fi

  mkdir -p "$dir" || return 1
  local cmd="cat >> ${(q)dir}/window_#{window_index}-pane_#{pane_index}_\$(date +%Y%m%d-%H:%M:%S).log"

  for p in $(tmux list-panes -s -t "$s" -F '#{pane_id}'); do
    tmux pipe-pane -t "$p" -o "$cmd" && (( n++ ))
  done
  tmux set-hook -t "$s" after-split-window "pipe-pane -o \"$cmd\""
  tmux set-hook -t "$s" after-new-window   "pipe-pane -o \"$cmd\""
  tmux set -t "$s" @logging 1

  tmux refresh-client -S
  echo "[+] Logging $n pane(s) in session '$s' to $dir"
}

stop_logging() {
  [[ -z "$TMUX" ]] && { echo "[-] Not inside tmux"; return 1; }

  local s=$(tmux display -p '#S') p n=0
  if [[ "$(tmux show -v -t "$s" @logging 2>/dev/null)" != "1" ]]; then
    echo "[!] Not logging session '$s'"
    return 1
  fi

  tmux set-hook -u -t "$s" after-split-window
  tmux set-hook -u -t "$s" after-new-window
  tmux set -u -t "$s" @logging

  for p in $(tmux list-panes -s -t "$s" -F '#{pane_id} #{pane_pipe}' | awk '$2==1{print $1}'); do
    tmux pipe-pane -t "$p" && (( n++ ))
  done

  tmux refresh-client -S
  echo "[+] Stopped logging $n pane(s) in session '$s'"
}
