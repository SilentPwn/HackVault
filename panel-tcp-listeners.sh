#!/bin/bash
# XFCE genmon: show listening TCP ports in the panel.
# Panel text = unique-port count (+ ⚠ if a port has multiple listeners).
# Tooltip = header + listener list (port, pid, application/container name).
# Name = the listener's own process name, or the Docker container for docker-proxy.

SS=/usr/bin/ss
DOCKER=/usr/bin/docker

list=$(sudo -n "$SS" -H -tlnp 2>/dev/null)

# Rows: "port proc pid"
rows=$(printf '%s\n' "$list" | awk '
NF {
  n = split($4, a, ":"); port = a[n]
  proc = "-"; pid = "?"
  if (match($0, /"[^"]+"/))   proc = substr($0, RSTART+1, RLENGTH-2)
  if (match($0, /pid=[0-9]+/)) pid  = substr($0, RSTART+4, RLENGTH-4)
  print port, proc, pid
}')

# Map published host port -> container name (absolute path, panel-safe)
declare -A ctr
if [ -x "$DOCKER" ]; then
  for id in $(sudo -n "$DOCKER" ps -q 2>/dev/null); do
    name=$(sudo -n "$DOCKER" inspect -f '{{.Name}}' "$id" 2>/dev/null | sed 's#^/##')
    [ -z "$name" ] && continue
    while read -r hp; do
      [ -n "$hp" ] && ctr[$hp]=$name
    done < <(sudo -n "$DOCKER" port "$id" 2>/dev/null | grep -oE ':[0-9]+$' | tr -d ':')
  done
fi

# Unique listening ports
count=$(printf '%s\n' "$rows" | awk 'NF{print $1}' | sort -nu | grep -c .)

# Ports bound by more than one process
dups=$(printf '%s\n' "$rows" | awk 'NF{print $1}' | sort -n | uniq -d)
dupcount=$(printf '%s\n' "$dups" | grep -c .)

# Tooltip: header, then every listener sorted by port.
header=$(printf "%-8s %-6s %s\n%-8s %-6s %s" \
  "Ports" "PID" "application name" \
  "-------" "-----" "----------------------")

body=$(printf '%s\n' "$rows" | sort -n | while read -r port proc pid; do
  [ -z "$port" ] && continue
  if [ "$proc" = "docker-proxy" ] && [ -n "${ctr[$port]:-}" ]; then
    owner="${ctr[$port]}"
  else
    owner="$proc"
  fi
  printf "%-8s %-6s %s\n" "$port" "$pid" "$owner"
done)

tip="${header}
${body}"

if [ "$dupcount" -gt 0 ]; then
  tip="${tip}

⚠ Port(s) with multiple listeners:
$(printf '%s\n' "$dups" | sed 's/^/  /')"
fi

# Label + panel text
if [ "$count" -eq 1 ]; then label="Port"; else label="Ports"; fi

if [ "$dupcount" -gt 0 ]; then
  echo "<txt> <span foreground='#ff5555'>⚠</span> ${count} ${label} </txt>"
else
  echo "<txt> ${count} ${label} </txt>"
fi
echo "<tool><span font='monospace'>${tip}</span></tool>"
