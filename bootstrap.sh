#!/usr/bin/env bash
# Check if running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "Run $0 as root or with sudo"
  exit 1
fi


# Define paths
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"  # folder of bootstrap.sh
BIN_DIR="/usr/local/bin"

MENU_SCRIPT="menu.sh"
MONITOR_SCRIPT="monitor.sh"
BACKUP_SCRIPT="backup.sh"
CLEANUP_SCRIPT="cleanup.sh"


#  copying the scripts to /usr/local/bin
echo "Copying scripts to $BIN_DIR..."
for script in "$MENU_SCRIPT" "$MONITOR_SCRIPT" "$BACKUP_SCRIPT" "$CLEANUP_SCRIPT"; do
  if [[ -f "$SRC_DIR/$script" ]]; then
    cp -f "$SRC_DIR/$script" "$BIN_DIR/$script"
    chmod +x "$BIN_DIR/$script"
    echo "  -> Installed: $script"
  else
    echo "Warning: $script not found in $SRC_DIR. Skipping."
  fi
done


# Add new lines to the bottom of the crontab
{
  # print existing crontab
  crontab -l 2>/dev/null

  # monitor.sh: run every hour at minute 0
  echo "0 * * * * $BIN_DIR/$MONITOR_SCRIPT"

  # backup.sh: run at 02:00 on the 4th and 20th
  echo "0 2 4,20 * * $BIN_DIR/$BACKUP_SCRIPT"

  # cleanup.sh: run at 03:00 on the 1st of each month
  echo "0 3 1 * * $BIN_DIR/$CLEANUP_SCRIPT"
} | crontab -


echo "Cron jobs have been updated ."
echo "Bootstrap has been complete! You can now use menu.sh, monitor.sh, backup.sh, and cleanup.sh from /usr/local/bin."
exit 0
