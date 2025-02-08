#!/usr/bin/env bash

# Check if script is run interactively
if [[ ! -t 0 ]]; then
  exit 1
fi

# check if script is run's as root or with sudo
if [[ $(id -u) -ne 0 ]]; then
  echo "Run $0 as root or with sudo"
  exit 1
fi

echo "Welcome stranger!"

# PS3 is the prompt for 'select' loops
PS3='~Select an option my friend: '

# Define the menu options 
options=(
  "Display system metrics"  # 1)calls monitor.sh
  "Show last 5 backup logs" # 2)calls backup.sh show-logs shows last 5 logs
  "Perform a manual backup" # 3)calls backup.sh
  "Perform a disk cleanup"  # 4)calls cleanup.sh
  "Display total processes" # 5)simple count of running processes
  "Quit"                    # 6)exit
)
get_process_count() {
  # ps auxh shows all processes in user-friendly format
  # wc -l counts lines
  total_procs=$(ps auxh | wc -l)
  # subtract 2 for the ps+wc overhead
  ((total_procs -= 2))
  echo "$total_procs"
}

# Use 'select' to display the numbered menu
select option in "${options[@]}"; do
  case "$option" in
    "${options[0]}")
      # calls the monitor.sh script
      /usr/local/bin/monitor.sh
      ;;
    "${options[1]}")
      # calls backup.sh with show-logs argument
      /usr/local/bin/backup.sh show-logs
      ;;
    "${options[2]}")
      # calls backup.sh directly
      /usr/local/bin/backup.sh
      ;;
    "${options[3]}")
      # calls cleanup.sh script
      /usr/local/bin/cleanup.sh
      ;;
    "${options[4]}")
      # simple count function of running processes
      echo "Total running processes right now: $(get_process_count)."
      ;;
    "${options[5]}")
      echo "Goodbye!"
      exit 0
      ;;
    *)
      echo "Invalid selection. Please try again."
      ;;
  esac
done
