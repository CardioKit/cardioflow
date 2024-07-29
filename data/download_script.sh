#!/bin/bash

# Initialize variables
download_dir=""
ids=()

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--directory) download_dir="$2"; shift ;;
        -p|--patients) IFS=',' read -r -a ids <<< "$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if download directory is set
if [ -z "$download_dir" ]; then
    echo "Download directory is not set. Use -d or --directory to set it."
    exit 1
fi

# Check if ids are set
if [ ${#ids[@]} -eq 0 ]; then
    echo "No patient IDs provided. Use -p or --patients to set them."
    exit 1
fi

# Create the download directory if it doesn't exist
mkdir -p "$download_dir"

# Base URL
base_url="https://physionet.org/files/icentia11k-continuous-ecg/1.0"

# Loop through each ID
for id in "${ids[@]}"; do
    prefix="${id:0:3}"
    # Create directories to organize downloads
    mkdir -p "$download_dir/$id"
    # Loop from 0 to 49 (or whatever range of files you need)
    for i in $(seq -w 0 49); do
        # Construct the full URL
        atr_url="${base_url}/${prefix}/${id}/${id}_s${i}.atr?download"
        dat_url="${base_url}/${prefix}/${id}/${id}_s${i}.dat?download"
        hea_url="${base_url}/${prefix}/${id}/${id}_s${i}.hea?download"

        # Download each file using curl
        curl -o "$download_dir/$id/${id}_s${i}.atr" "$atr_url"
        curl -o "$download_dir/$id/${id}_s${i}.dat" "$dat_url"
        curl -o "$download_dir/$id/${id}_s${i}.hea" "$hea_url"

        # Sleep to prevent overwhelming the server
        sleep 1
    done
done
