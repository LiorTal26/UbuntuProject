#!/usr/bin/env bash
LOG_FILE="/var/log/monitor.log"

# check if script is running interactively or by cron(auto)
if [[ -t 0 ]]; then
    IS_INTERACTIVE=true
else
    IS_INTERACTIVE=false
fi


# check if script is run's as root or with sudo
if [[ $(id -u) -ne 0 ]]; then
    echo "Run $0 as root or with sudo"
    exit 1
fi


# Get CPU usage in %
# Using vmstat to get idle, then 100 - idle
# We run vmstat twice with 1-second delay; 

idle_index='-3'
read -ra vmstat_second_line <<<"$(vmstat | sed -n 2p)"
if [[ "${vmstat_second_line[-1]}" = "gu" ]]; then
idle_index='-4'
fi
read -r -a cpu_usage_a <<<"$(vmstat 1 2 | tail -1)"
CPU_USAGE="${cpu_usage_a[$idle_index]}"
CPU_USAGE=$((100 - CPU_USAGE))


# Get Memory usage in %
# free -b provides memory values in bytes
read -r MEM_TOTAL MEM_USED <<<"$(free -b | sed -n '2p' |  awk '{print $2, $3}')"

# Calculate percentage with awk:
MEM_USAGE=$(awk -v used="$MEM_USED" -v total="$MEM_TOTAL" 'BEGIN {
  if (total == 0) { print 0 }
  else { printf "%.1f", (used / total) * 100 }
}')

RX_BYTES=0
TX_BYTES=0
# Get RX/TX bytes from all physical interface
for NET_INTERFACE_PATH in /sys/class/net/*; do
    #Get only the file name with basename
    INTERFACE_NAME="$(basename "$NET_INTERFACE_PATH")"

        #check if the interface is physical and not in virtual
        if [[ -d "/sys/class/net/$INTERFACE_NAME/device" ]]; then
            RX_CURR=$(cat /sys/class/net/"$INTERFACE_NAME"/statistics/rx_bytes 2>/dev/null)
            TX_CURR=$(cat /sys/class/net/"$INTERFACE_NAME"/statistics/tx_bytes 2>/dev/null)
            RX_BYTES=$((RX_BYTES + RX_CURR))
            TX_BYTES=$((TX_BYTES + TX_CURR))
        fi
done

if [[ "$IS_INTERACTIVE" == false ]]; then
    # For log line /var/log/monitor.log
    CURRENT_TIME="$(date)"
    # Format:     [date]         cpu%       mem%        rx       tx
    LOG_LINE="[$CURRENT_TIME] $CPU_USAGE $MEM_USAGE $RX_BYTES $TX_BYTES"
    echo "$LOG_LINE" >> "$LOG_FILE"
fi

#[Sun 12 Jan 2025 19:21:36 IST] 1 23.2 672117313 2724579

# If interactive, show current measurement and compare with previous
if [[ "$IS_INTERACTIVE" == true ]]; then

      if [[ ! -s "$LOG_FILE" ]]; then
        # Display trend info if the log is empty
        echo "Current system metrics:"
        echo "CPU usage: current - ${CPU_USAGE}%"
        echo "Memory usage: current - ${MEM_USAGE}%"
        echo "Tx/Rx bytes: $TX_BYTES/$RX_BYTES"
        exit 0
    fi
    
    # taking the last line of the log file and splitting it into an array
    read -r -a LAST_LOG_LINE <<<"$(tail -1 "$LOG_FILE" | cut -d ']' -f 2)"
    #last cpu usage
    PREV_CPU="${LAST_LOG_LINE[0]}"
    #last memory usage
    PREV_MEM="${LAST_LOG_LINE[1]}"

    # Compare CPU usage
    CPU_DIFF=$(awk -v curr="$CPU_USAGE" -v prev="$PREV_CPU" 'BEGIN { printf "%.1f", curr - prev }')
    if (( $(echo "$CPU_DIFF > 0" | bc -l) )); then
        CPU_TREND="increased by $CPU_DIFF"
    elif (( $(echo "$CPU_DIFF < 0" | bc -l) )); then
        CPU_TREND="decreased by ${CPU_DIFF#-}"
    else
        CPU_TREND="no change"
    fi

    # Compare Memory usage
    MEM_DIFF=$(awk -v curr="$MEM_USAGE" -v prev="$PREV_MEM" 'BEGIN { printf "%.1f", curr - prev }')
    if (( $(echo "$MEM_DIFF > 0" | bc -l) )); then
        MEM_TREND="increased by $MEM_DIFF"
    elif (( $(echo "$MEM_DIFF < 0" | bc -l) )); then
        MEM_TREND="decreased by ${MEM_DIFF#-}"
    else
        MEM_TREND="no change"
    fi

    # Display trend info
    echo "Current system metrics:"
    echo "CPU usage: current - ${CPU_USAGE}% trend - $CPU_TREND"
    echo "Memory usage: current - ${MEM_USAGE}% trend - $MEM_TREND"
    echo "Tx/Rx bytes: $TX_BYTES/$RX_BYTES"
fi

exit 0
