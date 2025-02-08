#!/usr/bin/env bash

DAYS_OLD=17
SIZE_THRESHOLD=$((10*1024*1024))  # 10 MiB in bytes
TARGET_DIRS=("/tmp" "/var/tmp" "/var/log")

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

# enable recursive loop (globbing)
shopt -s globstar dotglob

find_old_files() {
    for dir in "${TARGET_DIRS[@]}"; do
        for FILE in "$dir"/**; do
            if [[ -f "$FILE" ]]; then  #check if its a file
                last_modification_seconds=$(stat --format=%Y "$FILE" 2>/dev/null)
                
                if [[ -n "$last_modification_seconds" ]]; then
                    last_modification_in_days=$((($(date +%s) - last_modification_seconds) / 86400))
                fi

                # addes it to the array(list)
                if (( last_modification_in_days >= DAYS_OLD )); then
                    echo "$FILE"
                fi
            fi
        done
    done
}
mapfile -t OLD_FILES < <(find_old_files)

# ** mapfile with find version
# find files older than $DAYS_OLD days 
# find "file" -type f -mtime +17
#mapfile -t OLD_FILES < <(find "${TARGET_DIRS[@]}" -type f -mtime +$DAYS_OLD 2>/dev/null)


# if no old files found, exit
if [[ ${#OLD_FILES[@]} -eq 0 ]]; then
    echo "No files older than $DAYS_OLD days were found."
    exit 0
fi

# calculate total size of files to be deleted
TOTAL_OLD_SIZE=0
for file in "${OLD_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        file_size=$(stat -c "%s" "$file" 2>/dev/null || echo 0)
        (( TOTAL_OLD_SIZE += file_size ))
    fi
done

#
# If interactive, check if total size is above threshold
if [[ "$IS_INTERACTIVE" == true ]]; then
    if (( TOTAL_OLD_SIZE > SIZE_THRESHOLD )); then
        echo "Files to delete exceed 10 MiB (~$((TOTAL_OLD_SIZE/1024/1024)) MiB)."
        read -rp "Proceed with deletion? (y/n): " ans
        if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
            echo "Stoped by the user."
            exit 0
        fi
    fi
    echo "Deleting files older than $DAYS_OLD days"
fi

# Delete the old files
for file_to_del in "${OLD_FILES[@]}"; do
    [[ -f "$file_to_del" ]] && rm -f "$file_to_del"
done

echo "Cleanup complete. Total deleted: $((TOTAL_OLD_SIZE/1024/1024)) MiB."
exit 0
