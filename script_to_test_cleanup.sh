#!/usr/bin/env bash

# Ensure the script is run as root
if [[ $(id -u) -ne 0 ]]; then
    echo "Run as root"
    exit 2
fi

read -rp "Create data more than 10MiB? [Y/n] " response
response=${response:-y}

# By default (N), files of ~10KiB
count=10

# If user answered Y, create 10MiB files
[[ "$response" =~ [Yy] ]] && count=100

aged='aged'
tmp_dirs=('/tmp' '/var/tmp' '/var/log')

for i in {1..5}; do
    for dir in "${tmp_dirs[@]}"; do
        dirname="$dir/$aged-$i"
        mkdir -p "$dirname" 2>/dev/null
        for j in {1..7}; do
            filename="$dirname/$aged-file$j"
            # count × bs => 10240 × 1KiB = 10MiB
            dd if=/dev/urandom of="$filename" count="$count" bs=1KiB status=none
            # Set last modification time to 17 days ago
            touch -d "17 days ago" "$filename"
        done
    done
done
