#!/usr/bin/env bash

BACKUP_DIR="/opt/sysmonitor/backups"
LOG_FILE="/var/log/backup.log"

# Detect if script is running interactively or by cron(auto)
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


# Show logs if user asked "show-logs" show the last 5 backup logs
# and check if its running interactive
if [[ "$IS_INTERACTIVE" == true ]]; then
    if [[ "$1" == "show-logs" ]]; then
    # Check if the log file exists and is not empty
    if [[ ! -s "$LOG_FILE" ]]; then
        echo "No backup log found or it's empty."
        exit 0
    fi

    # Prints the 5 last logs from backup.log
     echo "Last 5 backup entries:"
     tail -5 "$LOG_FILE"

     exit 0
    fi
fi


# Create backup dir if not exists ("/opt/sysmonitor/backups")
mkdir -p "$BACKUP_DIR"

# Check free space vs. size of /home
HOME_SIZE_BYTES=$(du -sb /home 2>/dev/null | awk '{print $1}')
AVAILABLE_BYTES=$(df -B1 --output=avail "$BACKUP_DIR" | tail -1)


# Log helper function
log_msg() {
    echo "[$(date)] $*" >> "$LOG_FILE"
}

# Check if the script got the home size and disk space size
if [[ -z "$AVAILABLE_BYTES" || -z "$HOME_SIZE_BYTES" ]]; then
    log_msg "Error: Could not detect disk space or home size."
    exit 1
fi

# Check if there's enough space
if (( AVAILABLE_BYTES < HOME_SIZE_BYTES )); then
    log_msg "Not enough disk space to create backup. Required: $HOME_SIZE_BYTES, Available: $AVAILABLE_BYTES"
    $IS_INTERACTIVE && echo "Not enough disk space, skipping backup."
    exit 1
fi

# making the format for the backup file 
FORMAT="+%Y_%m_%d_%H_%M_%S"
DATE_FORMATE_STR="$(date "$FORMAT")"
ARCHIVE_NAME="${DATE_FORMATE_STR}_home_backup.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"

# Perform the backup with tar + gzip
tar -czf "$ARCHIVE_PATH" --ignore-failed-read /home 2>/dev/null

# if no code error
if [[ $? -eq 0 ]]; then
    log_msg "Backup success: $ARCHIVE_NAME (size: $(du -sh "$ARCHIVE_PATH" | awk '{print $1}'))"
    $IS_INTERACTIVE && echo "Backup created at: $ARCHIVE_PATH"
else
    log_msg "Backup failed for $ARCHIVE_PATH"
    $IS_INTERACTIVE && echo "Backup failed."
    exit 1
fi

# Remove old backups > 7 days  with ONLY CRONTAB 
# ** find version
#if [[ "$IS_INTERACTIVE" == false ]]; then
#    find "$BACKUP_DIR" -type f -name "*_home_backup.tar.gz" -mtime +7 -exec rm -f {} \; 2>/dev/null
#fi

# ** loop version
if [[ "$IS_INTERACTIVE" == false ]]; then
    DAYS_OLD=7

    for FILE in "$BACKUP_DIR"/*_home_backup.tar.gz; do
        # check if file exist 
        if [[ -e "$FILE" ]]; then
            last_modification_seconds=$(stat --format=%Y "$FILE" 2>/dev/null)

            if [[ -n "$last_modification_seconds" ]]; then
                last_modification_in_days=$((($(date +%s) - last_modification_seconds) / 86400))

                #check if file older then 7 days
                if (( last_modification_in_days > DAYS_OLD )); then
                    rm -f "$FILE"
                    echo "Deleted old backup: $FILE"
                fi
            else
                echo "Could not find modification time for $FILE"
            fi
        fi
    done
fi


exit 0
