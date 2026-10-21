#!/bin/bash
# XFCE genmon: show listening TCP ports in the panel.
# Panel text = unique-port count (+ ⚠ if a port has multiple listeners).
# Tooltip = full listener list, duplicates distinguished by PID and flagged.

list=$(sudo /usr/bin/ss -H -tlnp 2>/dev/null)

# Rows: "port proc pid"
rows=$(printf '%s\n' "$list" | awk '
NF {
  n = split($4, a, ":"); port = a[n]
  proc = "-"; pid = "?"
  if (match($0, /"[^"]+"/))   proc = substr($0, RSTART+1, RLENGTH-2)
  if (match($0, /pid=[0-9]+/)) pid  = substr($0, RSTART+4, RLENGTH-4)
  print port, proc, pid
}')

# Unique listening ports
count=$(printf '%s\n' "$rows" | awk 'NF{print $1}' | sort -nu | grep -c .)

# Ports bound by more than one process
dups=$(printf '%s\n' "$rows" | awk 'NF{print $1}' | sort -n | uniq -d)
dupcount=$(printf '%s\n' "$dups" | grep -c .)

# Tooltip: every listener, sorted by port (no dedup — PIDs make them distinct)
tip=$(printf '%s\n' "$rows" | sort -n | awk 'NF{printf "%-7s %-15s pid=%s\n",$1,$2,$3}')

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
echo "<tool>${tip}</tool>"
