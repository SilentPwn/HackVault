#!/usr/bin/env bash
#
# kskew.sh — align the machine clock to a target DC so Kerberos stops
#            throwing KRB_AP_ERR_SKEW.
#
#            Moves the *system* clock (not just LD_PRELOAD in one shell), so
#            every tmux pane and every tool on the box — sudo/setuid ones
#            included — sees the aligned time. NTP is disabled while active so
#            timesyncd can't drag the clock back; 'unskew' re-enables it.
#
#            Reads the DC time from whichever service answers, in order:
#              1. NTP  / 123   ntpdate         (relative offset)
#              2. SMB  / 445   nmap smb2-time   (UTC)
#              3. LDAP / 389   RootDSE currentTime, anon bind (UTC)
#              4. HTTP / 80,443  Date: header   (if the DC serves web)
#            A DC almost always answers at least one of these even when 123
#            is filtered.
#
# SOURCE it so 'unskew' stays available in your shell:
#     source ./kskew.sh 10.10.206.140      # probe the DC for its time
#     OFFSET=+7h source ./kskew.sh         # or force a known offset
#     unskew                               # NTP on, real time restored
#
# Needs root for the clock/NTP changes (uses sudo automatically if not root).

# --- refuse to run; demand sourcing (bash + zsh) ---------------------------
__kskew_sourced=0
if [ -n "${ZSH_VERSION:-}" ]; then
    case "${ZSH_EVAL_CONTEXT:-}" in *:file*) __kskew_sourced=1 ;; esac
elif [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]}" != "${0}" ] && __kskew_sourced=1
fi
if [ "$__kskew_sourced" -ne 1 ]; then
    echo "[-] kskew.sh must be SOURCED, not run." >&2
    echo "    use:  source ${0##*/} <dc-ip>      (or: OFFSET=+7h source ${0##*/})" >&2
    echo "    use:  unskew                        revert" >&2
    unset __kskew_sourced
    exit 1
fi
unset __kskew_sourced

# turn a 14-digit YYYYMMDDHHMMSS (UTC) into an epoch
__kskew_gt2epoch() {
    local t="$1"
    [ "${#t}" -ge 14 ] || return 1
    date -d "${t:0:4}-${t:4:2}-${t:6:2} ${t:8:2}:${t:10:2}:${t:12:2} UTC" +%s 2>/dev/null
}

__kskew_main() {
    local R=$'\e[31m' G=$'\e[32m' B=$'\e[34m' Y=$'\e[33m' N=$'\e[0m'
    [ -t 1 ] || { R=''; G=''; B=''; Y=''; N=''; }

    # sudo wrapper (empty when already root)
    local SUDO=''
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null || { echo "${R}[-]${N} need root or sudo to change the clock" >&2; return 1; }
        SUDO='sudo'
    fi
    command -v timedatectl >/dev/null || { echo "${R}[-]${N} timedatectl not found (needs systemd)" >&2; return 1; }

    # 1. work out the TARGET epoch (tgt) ------------------------------------
    local tgt='' now; now=$(date +%s)

    if [ -n "${OFFSET:-}" ]; then
        # forced relative offset: +7h / -7h / 90m / 25200s / 25200
        local o="$OFFSET" sign=1 num unit secs
        case "$o" in -*) sign=-1; o=${o#-} ;; +*) o=${o#+} ;; esac
        unit=$(printf '%s' "$o" | tr -dc 'hms')
        num=$(printf '%s' "$o" | tr -dc '0-9.')
        [ -n "$num" ] || { echo "${R}[-]${N} can't parse OFFSET='$OFFSET'" >&2; return 1; }
        case "$unit" in
            h)    secs=$(awk -v n="$num" 'BEGIN{printf "%d", n*3600}') ;;
            m)    secs=$(awk -v n="$num" 'BEGIN{printf "%d", n*60}') ;;
            s|"") secs=$(awk -v n="$num" 'BEGIN{printf "%d", n}') ;;
            *)    echo "${R}[-]${N} bad unit in OFFSET='$OFFSET'" >&2; return 1 ;;
        esac
        [ "$sign" -eq -1 ] && secs=$(( -secs ))
        tgt=$(( now + secs ))
        echo "${B}[*]${N} forced offset: ${secs}s"
    else
        local server="${1:-}"
        [ -n "$server" ] || { echo "${R}[-]${N} usage: source kskew.sh <dc-ip>   (or OFFSET=+7h)" >&2; return 1; }

        # --- try 1: NTP / 123 via ntpdate (relative offset) ---------------
        if [ -z "$tgt" ] && command -v ntpdate >/dev/null; then
            echo "${B}[*]${N} probing $server over NTP/123 ..."
            local raw secs
            raw=$(ntpdate -q "$server" 2>/dev/null | grep -oE '[+-][0-9]+\.[0-9]+' | tail -1)
            if [ -n "$raw" ]; then
                secs=${raw%.*}; case "$secs" in ""|"-"|"+") secs=0 ;; esac
                tgt=$(( now + secs ))
                echo "${G}[+]${N} NTP offset ${raw}s"
            else
                echo "${Y}[!]${N} no NTP reply (123 blocked?)"
            fi
        fi

        # --- try 2: SMB / 445 via nmap smb2-time (UTC) --------------------
        if [ -z "$tgt" ] && command -v nmap >/dev/null; then
            echo "${B}[*]${N} reading $server over SMB/445 ..."
            local dc_utc
            dc_utc=$(nmap -p445 -Pn -T4 --host-timeout 20s --script smb2-time "$server" 2>/dev/null \
                     | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
            if [ -n "$dc_utc" ]; then
                tgt=$(date -d "$dc_utc UTC" +%s 2>/dev/null)
                [ -n "$tgt" ] && echo "${G}[+]${N} SMB time ${dc_utc}Z"
            else
                echo "${Y}[!]${N} no SMB time"
            fi
        fi

        # --- try 3: LDAP / 389 RootDSE currentTime, anon bind (UTC) -------
        if [ -z "$tgt" ] && command -v ldapsearch >/dev/null; then
            echo "${B}[*]${N} reading $server over LDAP/389 ..."
            local gt
            gt=$(timeout 8 ldapsearch -x -o nettimeout=6 -H "ldap://$server" \
                    -b "" -s base -LLL currentTime 2>/dev/null \
                 | grep -oE 'currentTime: [0-9]+' | grep -oE '[0-9]{14}' | head -1)
            if [ -n "$gt" ]; then
                tgt=$(__kskew_gt2epoch "$gt")
                [ -n "$tgt" ] && echo "${G}[+]${N} LDAP currentTime ${gt}Z"
            else
                echo "${Y}[!]${N} no LDAP currentTime"
            fi
        fi

        # --- try 4: HTTP / 80,443 Date: header ---------------------------
        if [ -z "$tgt" ] && command -v curl >/dev/null; then
            echo "${B}[*]${N} reading $server over HTTP Date header ..."
            local http_date p
            for p in "http://$server" "https://$server"; do
                http_date=$(curl -ksI -m 5 "$p" 2>/dev/null | grep -i '^date:' | head -1 | sed 's/^[Dd]ate: *//; s/\r$//')
                [ -n "$http_date" ] && break
            done
            if [ -n "$http_date" ]; then
                tgt=$(date -d "$http_date" +%s 2>/dev/null)
                [ -n "$tgt" ] && echo "${G}[+]${N} HTTP Date: $http_date"
            else
                echo "${Y}[!]${N} no HTTP Date header"
            fi
        fi

        [ -n "$tgt" ] || { echo "${R}[-]${N} couldn't read $server time over NTP, SMB, LDAP or HTTP" >&2; return 1; }
    fi

    # 2. NTP off (so it can't pull the clock back), then jump the clock ------
    local newtime; newtime=$(date -d "@$tgt" '+%Y-%m-%d %H:%M:%S')
    $SUDO timedatectl set-ntp off 2>/dev/null
    if $SUDO timedatectl set-time "$newtime" 2>/dev/null; then
        export KSKEW_ACTIVE=1
        local drift=$(( tgt - now ))
        echo "${G}[+]${N} clock set -> $(date '+%F %T %Z')  (moved ${drift}s, NTP disabled)"
    else
        $SUDO timedatectl set-ntp on 2>/dev/null   # don't leave NTP off on failure
        echo "${R}[-]${N} failed to set clock (need root? set-time refused?) — NTP left on" >&2
        return 1
    fi

    # 3. the off-switch -----------------------------------------------------
    unskew() {
        local SUDO=''
        [ "$(id -u)" -ne 0 ] && SUDO='sudo'
        $SUDO timedatectl set-ntp on 2>/dev/null
        unset KSKEW_ACTIVE
        unset -f unskew
        echo "[+] NTP re-enabled — clock self-corrects in a few seconds: $(date '+%F %T %Z')"
    }

    [ -n "${TMUX:-}" ] && echo "    tmux: every pane in this session now sees the aligned clock."
    echo "    run your tools; 'unskew' to turn off."
}

__kskew_main "$@"
unset -f __kskew_main
unset -f __kskew_gt2epoch 2>/dev/null
