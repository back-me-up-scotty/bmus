#!/bin/bash

# ===========================================================================
# BmuS - Back Me Up Scotty - Backup script for Pi/Linux <-> NAS backup v.25.8
# ===========================================================================
# -------------------------------------------------------------------------
# PLEASE SUPPORT FURTHER DEVELOPMENT
# -------------------------------------------------------------------------
#
#  If you would like to support the development and maintenance of this script,
#  you are welcome to send a donation of your choice.
#  Your support helps the development of this project.Thank you.
#
#  PayPal Donation: https://py.pl/N9HER
#
# ===========================================================================
# BmuS - Back Me Up Scotty - Backup Solution
# Copyright (c) 2025 Niels Gerhardt
# ===========================================================================
# BmuS COMMUNITY SOURCE - AVAILABLE LICENSE
# 
# GRANT OF LICENSE
# Permission is hereby granted, free of charge, to any person or entity obtaining 
# a copy of this software and associated documentation files (the "Software"), to 
# use the Software for PERSONAL and INTERNAL BUSINESS purposes, subject to the 
# following conditions: a) Internal Use: You may install and use the Software on 
# an unlimited number of devices owned or controlled by you or your organization 
# to perform backups of your own data or systems.
# b) Modification: You may modify the source code of the Software for your own 
# internal needs or adaptation.
# 
# RESTRICTIONS
# The rights granted above are strictly limited by the following prohibitions:
# a) No Sale or Resale: You may NOT sell, rent, lease, license, or sub-license the 
# Software or any parts thereof. The Software must remain free of charge.
# b) No Commercial Distribution: You may NOT include this Software as part of a 
# paid product, service package, or commercial distribution.
# c) No "Backup-as-a-Service": You may NOT use the Software to offer a paid backup 
# service to third parties where the Software itself is the primary value proposition.
# d) No Public Redistribution: You may NOT redistribute, upload to public repositories, 
# or publish the source code or binaries (original or modified) to the general public.
# e) This header must remain in the script and must not be deleted or modified.
# 
# OWNERSHIP
# The original Author retains all right, title, and interest in and to the Software. 
# Modifications made by you remain your property but are subject to the distribution 
# restrictions of this license (i.e., you cannot sell or share your modifications publicly).
# 
# DISCLAIMER OF WARRANTY
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. 
# THE AUTHORS OR COPYRIGHT HOLDERS SHALL NOT BE LIABLE FOR ANY DAMAGES, DATA LOSS, 
# OR LIABILITY ARISING FROM THE USE OF THE SOFTWARE. USE AT YOUR OWN RISK.
# 
# ===========================================================================
#  Author: Niels Gerhardt
#  Contact: bmus(AT)back-me-up-scotty(DOT)com
#  Web: https://www.back-me-up-scotty.com
#  Copyright (c) 2025 Niels Gerhardt
#
#  The author takes no responsibility for damage resulting from the use of the script. 
#  By using it, you acknowledge this.
# -------------------------------------------------------------------------
# Load configuration file. Change this to your home directory or 
# wherever bmus is stored.
#
CONFIG_FILE="${CONFIG_FILE:-/home/user/bmus.conf}"
# -------------------------------------------------------------------------

# --- [ 1. LOAD CONFIG ] ------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
    echo "FATAL ERROR: Configuration file not found: $CONFIG_FILE"
    echo "Please create the file or set the environment variable CONFIG_FILE"
    echo "Example: CONFIG_FILE=/path/to/backup.conf \$0"
    exit 1
fi

# Set default language to 'english' before loading
LANGUAGE="english"
source "$CONFIG_FILE"

# Initialize log file
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
chmod 644 "$LOGFILE"

MAIL_BODY=""
> "$LOGFILE"

log_echo() {
    local msg="$1"
    echo -e "$msg" >> "$LOGFILE"
    MAIL_BODY+="$msg"$'\n'
}

# -------------------------------------------------------------------------
# === [ NAS REACHABILITY CHECK FUNCTION ] ===
# -------------------------------------------------------------------------
# FUNCTION: check_nas_reachability
# Checks if NAS is reachable via ping with configurable retries
# Returns: 0 if reachable, 1 if unreachable (and IGNORE_FAILED_PING=0)
# -------------------------------------------------------------------------
check_nas_reachability() {
    local nas_ip="$1"
    local max_retries="${PING_RETRIES:-2}"
    local retry_delay="${PING_RETRY_DELAY:-5}"
    local attempt=0
    local total_attempts=$((max_retries + 1))
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_PING_CHECK_START" "$nas_ip")"
    
    while [ $attempt -lt $total_attempts ]; do
        ((attempt++))
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_PING_ATTEMPT" "$attempt" "$total_attempts")"
        
        if ping -c 2 -W 3 "$nas_ip" >/dev/null 2>&1; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_PING_SUCCESS" "$nas_ip")"
            return 0
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_PING_FAILED_ATTEMPT" "$attempt" "$total_attempts")"
            
            if [ $attempt -lt $total_attempts ]; then
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_PING_RETRY_WAIT" "$retry_delay")"
                sleep "$retry_delay"
            fi
        fi
    done
    
    # All ping attempts failed
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_PING_ALL_FAILED" "$nas_ip" "$total_attempts")"
    
    if [ "${IGNORE_FAILED_PING:-0}" -eq 1 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $WARN_PING_IGNORED"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $WARN_PING_CONTINUE_ANYWAY"
        return 0
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_PING_ABORT"
        return 1
    fi
}

# --- [ ENCRYPTION: Load encryption functions ] ---

if [ -f "$(dirname "$0")/$BACKUP_ENCRYPTION_SCRIPT" ]; then
    source "$(dirname "$0")/$BACKUP_ENCRYPTION_SCRIPT"
fi
# --- [ END: Encryption functions loaded ] ---

# --- [ 2. LOAD LANGUAGE FILE (DYNAMIC) ] ------------------------------
# Use the variable from the config. Falls back to 'english' if not set.
LANG_CODE="${LANGUAGE:-english}"
LANG_FILE="$(dirname "$0")/${LANG_CODE}.lang"

if [ ! -f "$LANG_FILE" ]; then
    # Error must be harcoded if language file is not found
    echo "FATAL ERROR: Language file not found: $LANG_FILE (Language code: $LANG_CODE)"
    echo "Please ensure the file exists or set LANGUAGE='' in $CONFIG_FILE"
    exit 1
fi

source "$LANG_FILE"


# =========================================================================
# CHECK: CONFLICT RESOLUTION (Encryption vs. Deduplication)
# =========================================================================
if [ "${BACKUP_ENCRYPTION:-0}" -eq 1 ] && [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
{
        echo ""
        echo "$ERR_CONFIG_CONFLICT_TITLE"
        echo "----------------------------------------------------------------"
        echo "$ERR_CONFIG_CONFLICT_DESC"
        echo "$ERR_CONFIG_CONFLICT_REASON_1"
        echo "$ERR_CONFIG_CONFLICT_REASON_2"
        echo ""
        echo "$ERR_CONFIG_CONFLICT_ACTION_TITLE"
        echo "$ERR_CONFIG_CONFLICT_ACTION_1"
        echo "$ERR_CONFIG_CONFLICT_ACTION_2"
        echo "----------------------------------------------------------------"
        echo ""
    } | tee -a "$LOGFILE"
    exit 1
fi


# --- [ 3. START OF THE SCRIPT WITH LOADED TEXTS ] --------------------------
echo "$(printf "$MSG_CONFIG_LOAD_START" "$CONFIG_FILE")"

# Check required variables
REQUIRED_VARS=(
    "MASTER_IP" "NAS_IP" "NAS_SHARE" "EMAIL" "SEND_MAIL"
    "LOGFILE" "BACKUP_PATH" "CREDENTIALS_FILE" "BACKUP_AGE_DAYS"
    "BACKUP_MAXDEPTH" "BACKUP_SQL" "RSYNC_BANDWIDTH_LIMIT" 
    "DASHBOARD_FILENAME" "LOGFILE" "HISTORY_PATH" "HISTORY_MAX_AGE_DAYS"
)

# --- [ ENCRYPTION: Add to required vars ] ---
# Check encryption variables if encryption is enabled
if [ "${BACKUP_ENCRYPTION:-0}" -eq 1 ]; then
    REQUIRED_VARS+=(
        "ENCRYPTION_METHOD"
        "ENCRYPTION_PASSWORD_FILE"
    )
fi
# --- [ END: Encryption required vars ] ---

# ===== [ DEDUPLICATION - Add to required vars if enabled ] =====
if [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
    REQUIRED_VARS+=(
        "DEDUP_STRATEGY"
        "DEDUP_REFERENCE_DAYS"
    )
fi
# ===== [ END: DEDUPLICATION required vars ] =====

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "$(printf "$ERR_VAR_NOT_SET" "$var")"
        exit 1
    fi
done

if [ ${#BACKUP_SOURCES[@]} -eq 0 ]; then
    echo "$ERR_BACKUP_SOURCES_EMPTY"
    exit 1
fi

echo "$MSG_CONFIG_LOAD_SUCCESS"
echo ""

# =========================================================================
# BATCH PROCESSING FUNCTIONS
# =========================================================================

# Function: Wait until enough RAM is available
wait_for_memory() {
    local required_mb=$1
    local check_count=0
    
    while true; do
        local available_mb=$(free -m | awk 'NR==2{print $7}')
        local used_mb=$(free -m | awk 'NR==2{print $3}')
        local total_mb=$(free -m | awk 'NR==2{print $2}')
        local used_percent=$(( used_mb * 100 / total_mb ))
        
        if [ "$available_mb" -gt "$required_mb" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$BATCH_CHECK_RAM_OK" "$available_mb")"
            break
        else
            ((check_count++))
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$BATCH_CHECK_RAM_WAIT" "$available_mb" "$required_mb")"
            
            # Show top processes if waiting longer than 30s
            if [ $check_count -ge 3 ]; then
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $BATCH_CHECK_RAM_TOP_CONSUMERS"
                ps aux --sort=-%mem | head -n 6 | awk '{printf "   %s: %s%%\n", $11, $4}' >> "$LOGFILE"
            fi
            
            sleep 10
        fi
    done
}

# =========================================================================
# RESTORE FUNCTIONS
# =========================================================================

# -------------------------------------------------------------------------
# FUNCTION: mount_nas_for_restore
# Mount NAS share for restore operations
# -------------------------------------------------------------------------

mount_nas_for_restore() {
    if mountpoint -q "$BACKUP_PATH" 2>/dev/null; then
        echo "$(printf "$RESTORE_INFO_NAS_ALREADY_MOUNTED" "$BACKUP_PATH")"
        return 0
    fi
    
    if [ ! -d "$BACKUP_PATH" ]; then
        sudo mkdir -p "$BACKUP_PATH"
        sudo chown "$USER":"$USER" "$BACKUP_PATH"
    fi
    
    echo "$RESTORE_INFO_MOUNTING_NAS"
    
    # --- FIX: Support NFS & CIFS based on Config ---
    if [ "${NAS_MOUNT_MODE:-cifs_simple}" = "nfs" ]; then
        sudo mount -t nfs "$NAS_IP:$NAS_SHARE_NFS" "$BACKUP_PATH" -o vers=3,proto=tcp,nolock,async,noatime,nodiratime,actimeo=600,rsize=131072,wsize=131072,timeo=600,retrans=2 2>&1
    else
        # Default to CIFS
        sudo mount -t cifs "//$NAS_IP/$NAS_SHARE" "$BACKUP_PATH" -o username="$NAS_USER",password="$NAS_PASS",vers=3.0,iocharset=utf8,mfsymlinks,nobrl 2>&1
    fi
    # -----------------------------------------------
    
    if [ $? -eq 0 ]; then
        echo "$RESTORE_INFO_NAS_MOUNTED"
        return 0
    else
        echo "$RESTORE_ERR_NAS_MOUNT_FAILED"
        return 1
    fi
}

# -------------------------------------------------------------------------
# FUNCTION: umount_nas_after_restore
# Unmount NAS share after restore operations
# -------------------------------------------------------------------------
umount_nas_after_restore() {
    if mountpoint -q "$BACKUP_PATH" 2>/dev/null; then
        sync
        sleep 2
        sudo umount "$BACKUP_PATH"
        echo "$RESTORE_INFO_NAS_UNMOUNTED"
    fi
}
# -------------------------------------------------------------------------
# FUNCTION: detect_backup_structure
# Intelligently detect backup structure type in a directory
# Returns: "flat", "date-folders", "nested-dedup", or "mixed"
# -------------------------------------------------------------------------
detect_backup_structure() {
    local search_dir="$1"
    
    local has_flat=0
    local has_date_folders=0
    local has_nested=0
    
    # Check for flat files (direct children that are files)
    if find "$search_dir" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.tar.gz" -o -name "*.bak" -o -name "*.sh" \) 2>/dev/null | grep -q .; then
        has_flat=1
    fi
    
    # Check for date-only folders (YYYY-MM-DD)
    if find "$search_dir" -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" 2>/dev/null | grep -q .; then
        has_date_folders=1
        
        # Check if date folders contain timestamped subfolders (nested structure)
        if find "$search_dir" -maxdepth 2 -type d -path "*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*" 2>/dev/null | grep -q .; then
            has_nested=1
        fi
    fi
    
    # Determine structure type
    if [ $has_nested -eq 1 ]; then
        echo "nested-dedup"
    elif [ $has_date_folders -eq 1 ] && [ $has_flat -eq 1 ]; then
        echo "mixed"
    elif [ $has_date_folders -eq 1 ]; then
        echo "date-folders"
    elif [ $has_flat -eq 1 ]; then
        echo "flat"
    else
        echo "empty"
    fi
}

# -------------------------------------------------------------------------
# FUNCTION: list_available_backups
# List all available backups (encrypted or unencrypted)
# ===== [ MODIFIED: Support for flat, date-based, and nested structures ] =====
# -------------------------------------------------------------------------

list_available_backups() {
    local source_dir="$1"
    local filter_date="$2"
    
    # Detect structure type
    local structure=$(detect_backup_structure "$source_dir")
    
    echo "$RESTORE_LIST_SEPARATOR"
    
    if [ -n "$filter_date" ]; then
        echo "$(printf "$RESTORE_LIST_DATE_FILTER" "$filter_date")"
    else
        echo "$RESTORE_LIST_ALL_FILES"
    fi
    
    # Show detected structure info
    case "$structure" in
        flat)
            echo "$(printf "$RESTORE_INFO_STRUCTURE_DETECTED" "$RESTORE_STRUCTURE_FLAT")"
            ;;
        date-folders)
            echo "$(printf "$RESTORE_INFO_STRUCTURE_DETECTED" "$RESTORE_STRUCTURE_DATE_FOLDERS")"
            ;;
        nested-dedup)
            echo "$(printf "$RESTORE_INFO_STRUCTURE_DETECTED" "$RESTORE_STRUCTURE_NESTED")"
            ;;
        mixed)
            echo "$(printf "$RESTORE_INFO_STRUCTURE_DETECTED" "$RESTORE_STRUCTURE_MIXED")"
            ;;
        empty)
            echo "$RESTORE_INFO_NO_BACKUPS_FOUND"
            echo "$RESTORE_LIST_SEPARATOR"
            return 1
            ;;
    esac
    
    echo "$RESTORE_LIST_SEPARATOR"
    echo ""
    
    # Process based on structure type
    case "$structure" in
        flat)
            # Flat structure: direct files in root
            if [ -n "$filter_date" ]; then
                find "$source_dir" -maxdepth 1 -type f \
                    -printf "%T+ %p\n" 2>/dev/null | \
                    grep "^${filter_date}" | \
                    sort -r | \
                    while read -r line; do
                        date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                        file_part=$(echo "$line" | cut -d' ' -f2-)
                        filename=$(basename "$file_part")
                        filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                        filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                        
                        printf "%-12s  %-50s  %10s\n" "$date_part" "$filename" "$filesize_human"
                    done
            else
                find "$source_dir" -maxdepth 1 -type f \
                    -printf "%T+ %p\n" 2>/dev/null | \
                    sort -r | \
                    while read -r line; do
                        date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                        file_part=$(echo "$line" | cut -d' ' -f2-)
                        filename=$(basename "$file_part")
                        filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                        filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                        
                        printf "%-12s  %-50s  %10s\n" "$date_part" "$filename" "$filesize_human"
                    done
            fi
            ;;
            
        date-folders)
            # Date-based folders without nesting
            if [ -n "$filter_date" ] && [ -d "$source_dir/$filter_date" ]; then
                find "$source_dir/$filter_date" -maxdepth 1 -type f \
                    -printf "%T+ %p\n" 2>/dev/null | \
                    sort -r | \
                    while read -r line; do
                        date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                        file_part=$(echo "$line" | cut -d' ' -f2-)
                        filename=$(basename "$file_part")
                        filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                        filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                        
                        printf "%-12s  %-50s  %10s\n" "$date_part" "$filename" "$filesize_human"
                    done
            else
                for date_folder in "$source_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
                    if [ -d "$date_folder" ]; then
                        find "$date_folder" -maxdepth 1 -type f \
                            -printf "%T+ %p\n" 2>/dev/null
                    fi
                done | sort -r | \
                    while read -r line; do
                        date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                        file_part=$(echo "$line" | cut -d' ' -f2-)
                        filename=$(basename "$file_part")
                        filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                        filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                        
                        printf "%-12s  %-50s  %10s\n" "$date_part" "$filename" "$filesize_human"
                    done
            fi
            ;;
            
        nested-dedup)
            # Nested structure: YYYY-MM-DD/YYYY-MM-DD_HH-MM-SS/
            
            # Case 1: Date is given -> List files inside that date/timestamp
            if [ -n "$filter_date" ]; then
                # Check if folder exists
                if [ -d "$source_dir/$filter_date" ]; then
                    # Folder exists -> List content
                    find "$source_dir/$filter_date" -mindepth 2 -type f \
                        -printf "%T+ %p\n" 2>/dev/null | \
                        sort -r | \
                        while read -r line; do
                            date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                            file_part=$(echo "$line" | cut -d' ' -f2-)
                            
                            timestamp_folder=$(echo "$file_part" | grep -oP '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -n 1)
                            filename=$(basename "$file_part")
                            filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                            filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                            
                            printf "%-12s  %-20s  %-40s  %10s\n" "$date_part" "$timestamp_folder" "$filename" "$filesize_human"
                        done
                else
                    # Date given, but folder does not exist -> Error
                    echo ""
                    echo "$(printf "$RESTORE_ERR_DATE_FOLDER_NOT_FOUND" "$filter_date")"
                    
                    # --- Help user by listing available dates ---
                    echo ""
                    echo "$RESTORE_INFO_AVAILABLE_DATES"
                    echo "───────────────────────────────────────────────────────────────"
                    # List available date folders (YYYY-MM-DD)
                    find "$source_dir" -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -printf "%f\n" | sort -r | head -n 5
                    echo "..."
                    # ------------------------------------------------------
                    
                    return 1
                fi
            
            # Case 2: No date was given -> List SNAPSHOTS (Folders), not files!
            else
                echo "$RESTORE_INFO_AVAILABLE_SNAPSHOTS"
                echo "$RESTORE_LIST_SNAPSHOT_HEADER"
                echo "$RESTORE_LIST_SNAPSHOT_SEPARATOR"

                find "$source_dir" -mindepth 2 -maxdepth 2 -type d \
                    -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | \
                    sort -r | while read -r dir_path; do
                        dirname=$(basename "$dir_path")
                        # Format: YYYY-MM-DD_HH-MM-SS
                        date_str=$(echo "$dirname" | cut -d'_' -f1)
                        time_str=$(echo "$dirname" | cut -d'_' -f2 | sed 's/-/:/g')

                        printf "%-12s | %-8s | %s\n" "$date_str" "$time_str" "$dirname"
                    done
            fi
            ;;
            
        mixed)
            # Mixed structure: show both flat and folder-based
            echo "$RESTORE_INFO_MIXED_STRUCTURE_DETECTED"
            echo ""
            echo "$RESTORE_INFO_FLAT_FILES"
            
            # Show flat files first
            find "$source_dir" -maxdepth 1 -type f \
                -printf "%T+ %p\n" 2>/dev/null | \
                sort -r | \
                while read -r line; do
                    date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                    file_part=$(echo "$line" | cut -d' ' -f2-)
                    filename=$(basename "$file_part")
                    filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                    filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                    
                    printf "%-12s  %-50s  %10s\n" "$date_part" "$filename" "$filesize_human"
                done
            
            echo ""
            echo "$RESTORE_INFO_FOLDER_BASED_FILES"
            
            # Show folder-based files
            for date_folder in "$source_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
                if [ -d "$date_folder" ]; then
                    find "$date_folder" -type f \
                        -printf "%T+ %p\n" 2>/dev/null
                fi
            done | sort -r | \
                while read -r line; do
                    date_part=$(echo "$line" | cut -d' ' -f1 | cut -d'T' -f1)
                    file_part=$(echo "$line" | cut -d' ' -f2-)
                    filename=$(basename "$file_part")
                    filesize=$(stat -c %s "$file_part" 2>/dev/null || echo 0)
                    filesize_human=$(numfmt --to=iec --suffix=B "$filesize")
                    
                    printf "%-12s  %-50s  %10s\n" "$date_part" "$filename" "$filesize_human"
                done
            ;;
    esac
    
    echo ""
    echo "$RESTORE_LIST_SEPARATOR"
    
    if [ -z "$filter_date" ]; then
        echo "$RESTORE_LIST_USE_DATE"
    fi
     # Warn about mixed structures
    if [ "$structure" = "mixed" ]; then
        echo ""
        echo "$RESTORE_WARN_MIXED_STRUCTURE"
        echo "$RESTORE_INFO_MIGRATION_SUGGESTION"
    fi
    echo ""
}
# -------------------------------------------------------------------------
# FUNCTION: restore_backup
# Restore backup from specific date (all files or single file)
# -------------------------------------------------------------------------

restore_backup() {
    local restore_date="$1"
    local restore_target="$2"
    local source_dir="$3"
    local single_file="$4"
    local latest_only="${RESTORE_LATEST:-0}"
    
     echo "[3/5] $(printf "$RESTORE_INFO_SEARCH_DATE" "$restore_date")"
    
    # ===== [ MODIFIED: Detect structure and adapt search ] =====
    local structure=$(detect_backup_structure "$source_dir")
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$RESTORE_DEBUG_STRUCTURE" "$structure")"
    
    # ===== [ Support date-based folders ] =====
    local search_path="$source_dir"
    if [ -d "$source_dir/$restore_date" ]; then
        search_path="$source_dir/$restore_date"
        echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$RESTORE_INFO_USING_DATE_FOLDER" "$search_path")"
    fi
    
   # Find files from that date
    if [ -n "$single_file" ]; then
        # Restore single file
        echo "$(printf "$RESTORE_INFO_FILE_FILTER" "$single_file")"
        
        if [ "$search_path" != "$source_dir" ]; then
            local search_depth="${ENCRYPTED_BACKUP_MAXDEPTH:-5}"
            FILES=$(find "$search_path" -maxdepth "$search_depth" -type f \
                -name "*$single_file*" -printf "%T@ %p\n" 2>/dev/null | \
                sort -rn | cut -d' ' -f2-)
        else
            FILES=$(find "$search_path" -maxdepth "${ENCRYPTED_BACKUP_MAXDEPTH:-2}" -type f \
                -name "*$single_file*" \
                -printf "%T@ %p\n" | \
                grep " .*${restore_date}" | \
                sort -rn | cut -d' ' -f2-)
        fi
    else
        # Restore all files from date (Whole folder restore)
        if [ "$search_path" != "$source_dir" ]; then
            local search_depth="${ENCRYPTED_BACKUP_MAXDEPTH:-5}"
            FILES=$(find "$search_path" -maxdepth "$search_depth" -type f \
                -printf "%T@ %p\n" 2>/dev/null | sort -rn | cut -d' ' -f2-)
        else
            FILES=$(find "$search_path" -maxdepth "${ENCRYPTED_BACKUP_MAXDEPTH:-2}" -type f \
                -printf "%T@ %p\n" | \
                grep " .*${restore_date}" | \
                sort -rn | cut -d' ' -f2-)
        fi
    fi
    
    if [ -z "$FILES" ]; then
        if [ -n "$single_file" ]; then
            echo "$(printf "$RESTORE_ERR_FILE_NOT_FOUND" "$single_file" "$restore_date")"
        else
            echo "$(printf "$RESTORE_ERR_NO_BACKUP_FOUND" "$restore_date")"
        fi
        return 1
    fi
    
    # ===== [ Handle --latest flag for single files ] =====
    local file_count=$(echo "$FILES" | wc -l)
    
    if [ "$latest_only" -eq 1 ] && [ -n "$single_file" ]; then
        FILES=$(echo "$FILES" | head -n 1)
        local original_count=$file_count
        file_count=1
        if [ "$original_count" -gt 1 ]; then
            echo ""
            echo "$(printf "$RESTORE_INFO_LATEST_MODE" "$original_count")"
            echo ""
        fi
    fi
    
    echo "$RESTORE_INFO_FOUND_BACKUPS"
    echo "$FILES"
    echo ""
    
    # ===== [ Warn if multiple versions ] =====
    if [ -n "$single_file" ] && [ "$file_count" -gt 1 ]; then
        echo ""
        echo "$(printf "$RESTORE_WARN_MULTIPLE_VERSIONS" "$file_count" "$single_file")"
        echo "$RESTORE_INFO_VERSIONED_RESTORE"
        echo "$RESTORE_INFO_USE_LATEST"
        echo ""
    fi
    
    echo "[5/5] $(printf "$RESTORE_INFO_RESTORING" "$restore_target")"
    
    mkdir -p "$restore_target"
    if [ $? -ne 0 ]; then
        echo "$(printf "$RESTORE_ERR_TARGET_CREATE_FAILED" "$restore_target")"
        return 1
    fi
    
    # ===== [ MODIFIED: Structure preservation & Version handling ] =====
    local restore_count=0
    
    while IFS= read -r file; do
        filename=$(basename "$file")
        
        # 1. Determine RELATIVE PATH and LOGIC SWITCH
        local relative_path=""
        
        # LOGIC: 
        # Clean Mode (--latest OR Single File): Strip timestamp folder -> Flat structure (latest wins)
        # Raw Mode (Full Restore without latest): Keep timestamp folder -> Full history structure
        
        if [ "$latest_only" -eq 1 ] || [ -n "$single_file" ]; then
            # --- CLEAN MODE (Strip Timestamp) ---
            if [[ "$file" =~ .*/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}/(.*) ]]; then
                 relative_path="${BASH_REMATCH[1]}"
            elif [[ "$file" =~ .*/[0-9]{4}-[0-9]{2}-[0-9]{2}/(.*) ]]; then
                 relative_path="${BASH_REMATCH[1]}"
            else
                 relative_path="$filename"
            fi
        else
            # --- RAW HISTORY MODE (Keep Structure) ---
            # We strip the base DATE folder (e.g. 2025-11-27), but KEEP the TIMESTAMP folder
            if [[ "$file" =~ .*/[0-9]{4}-[0-9]{2}-[0-9]{2}/(.*) ]]; then
                 relative_path="${BASH_REMATCH[1]}"
            else
                 relative_path="$filename"
            fi
        fi
        
        # Determine directory part
        local relative_dir=$(dirname "$relative_path")
        local final_target_dir="$restore_target"
        local target_filename="$filename"
        
        # 2. Prepare Target Directory
        if [ "$relative_dir" != "." ]; then
            final_target_dir="$restore_target/$relative_dir"
            mkdir -p "$final_target_dir"
        fi
        
        # 3. Overwrite Protection (Only needed for Clean Mode)
        # Prevents overwriting a newer file with an older one from the same day
        if [ "$latest_only" -eq 1 ] || [ -n "$single_file" ]; then
             if [ -e "$final_target_dir/$target_filename" ]; then
                # File exists -> It must be a newer version (because find sorts by newest first)
                # Skip this older version
                continue
            fi
        fi
        
        echo "$(printf "$RESTORE_INFO_COPYING" "$filename")$([ "$final_target_dir/$target_filename" != "$restore_target/$filename" ] && echo " → $relative_path")"
        
        cp -a "$file" "$final_target_dir/$target_filename"
        
        if [ $? -eq 0 ]; then
            ((restore_count++))
        else
            echo "$(printf "$RESTORE_ERR_COPY_FAILED" "$filename")"
        fi
    done <<< "$FILES"
    # ===== [ END: Versioned file copy ] =====
    
    echo ""
    echo "$(printf "$RESTORE_SUCCESS_FILES_RESTORED" "$restore_count")"
    
    # Decrypt GPG files if present (Recursive search now required due to folders)
    find "$restore_target" -name "*.gpg" -type f | while read -r gpg_file; do
        echo "$(printf "$RESTORE_INFO_DECRYPTING" "$(basename "$gpg_file")")"
        gpg --homedir "$GPG_HOMEDIR" --decrypt "$gpg_file" > "${gpg_file%.gpg}" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "$(printf "$RESTORE_SUCCESS_DECRYPTED" "${gpg_file%.gpg}")"
            rm -f "$gpg_file"
        else
            echo "$(printf "$RESTORE_ERR_DECRYPT_FAILED" "$(basename "$gpg_file")")"
        fi
    done
    
    return 0
}
# =========================================================================
# ENCRYPTED BACKUP RETENTION FUNCTION
# =========================================================================
DELETED_COUNT=0
DELETED_COUNT_ENCR=0
DELETED_FOLDERS=0  # Count deleted folders (not files) for accurate retention chart
# =========================================================================
# FUNCTION: cleanup_old_encrypted_backups
# Delete old encrypted backups based on retention policy
# ===== [ Support for date-based folders ] =====
# =========================================================================
# DEDUPLICATION FUNCTIONS
# =========================================================================

# -------------------------------------------------------------------------
# FUNCTION: test_hardlink_support
# Test if the filesystem/NAS supports hardlinks
# -------------------------------------------------------------------------
test_hardlink_support() {
    local test_dir="$1"
    local test_file="$test_dir/.hardlink_test_$$"
    local test_link="$test_dir/.hardlink_test_link_$$"
    
    # Create test file
    echo "test" > "$test_file" 2>/dev/null || return 1
    
    # Try to create hardlink
    ln "$test_file" "$test_link" 2>/dev/null
    local result=$?
    
    # Cleanup
    rm -f "$test_file" "$test_link" 2>/dev/null
    
    return $result
}

# -------------------------------------------------------------------------
# FUNCTION: find_reference_backup
# Find the most recent backup to use as hardlink reference
# Returns: Path to reference backup or empty string
# -------------------------------------------------------------------------
find_reference_backup() {
    local backup_base="$1"
    local max_age_days="${DEDUP_REFERENCE_DAYS:-14}"
    local max_depth="${DEDUP_MAX_DEPTH:-3}"
    local use_date_folders="${BACKUP_USE_DATE_FOLDERS:-0}"
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_SEARCHING_IN" "$backup_base")"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_MAX_AGE" "$max_age_days")"
    
    local reference=""
    
    # Check if nested date folder structure is used
    if [ "$use_date_folders" -eq 1 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_DEDUP_SEARCHING_NESTED_FOLDERS"
        
        # Find timestamped directories inside date folders (YYYY-MM-DD/YYYY-MM-DD_HH-MM-SS)
        reference=$(find "$backup_base" -maxdepth 2 -type d \
            -path "*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" \
            -mtime -"$max_age_days" 2>/dev/null | \
            sort -r | head -n 1)
    else
        # Find timestamped backup directories (format: YYYY-MM-DD_HH-MM-SS)
        # Sort in reverse order to get most recent first
        reference=$(find "$backup_base" -maxdepth 1 -type d \
            -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" \
            -mtime -"$max_age_days" 2>/dev/null | \
            sort -r | head -n 1)
    fi
    
    if [ -n "$reference" ] && [ -d "$reference" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_FOUND_REFERENCE" "$reference")"
        echo "$reference"
        return 0
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_DEBUG_NO_REFERENCE_FOUND"
    
    return 1
}

# -------------------------------------------------------------------------
# FUNCTION: create_dedup_backup_dir
# Create timestamped backup directory for deduplication
# ===== [ MODIFIED: Support nested date folder structure ] =====
# -------------------------------------------------------------------------
create_dedup_backup_dir() {
    local backup_base="$1"
    local use_date_folders="${BACKUP_USE_DATE_FOLDERS:-0}"
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local backup_dir=""
    
    # Check if nested date folder structure is enabled
    if [ "$use_date_folders" -eq 1 ]; then
        local date_folder=$(date '+%Y-%m-%d')
        backup_dir="$backup_base/$date_folder/$timestamp"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_DEDUP_NESTED_FOLDER_CREATED" "$backup_dir")"
    else
        backup_dir="$backup_base/$timestamp"
    fi
    
    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MKDIR" "$backup_dir")"
        echo "$backup_dir"
        return 0
    fi
    
    mkdir -p "$backup_dir" || return 1
    echo "$backup_dir"
    return 0
}
# ===== [ END: Support nested date folder structure ] =====


# -------------------------------------------------------------------------
# FUNCTION: calculate_dedup_stats
# Calculate deduplication statistics using aggregated rsync data
# -------------------------------------------------------------------------
calculate_dedup_stats() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    # USE LANGUAGE VARIABLE: Calculating stats...
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_MSG_CALCULATING"

    # ---------------------------------------------------------------------
    # 1. SUMMARY STATISTICS CALCULATION (From Rsync internal stats)
    # ---------------------------------------------------------------------
    # Instead of scanning the disk (slow/unreliable on cifs_optimized),
    # we use the aggregated stats from the rsync runs.
    
    # Deduped files = Total seen by rsync - Total transferred (new/changed)
    local hardlink_count=$((GLOBAL_RSYNC_TOTAL_FILES - GLOBAL_RSYNC_TRANSFERRED_FILES))
    local total_files="$GLOBAL_RSYNC_TOTAL_FILES"
    
    # Saved bytes = Total size - Transferred size
    local saved_bytes=$((GLOBAL_RSYNC_TOTAL_SIZE - GLOBAL_RSYNC_TRANSFERRED_SIZE))
    
    # Safety check: avoid negative numbers
    if [ "$hardlink_count" -lt 0 ]; then hardlink_count=0; fi
    if [ "$saved_bytes" -lt 0 ]; then saved_bytes=0; fi
    
    DEDUP_SAVED_BYTES="${saved_bytes:-0}"
    
    if [ "$total_files" -gt 0 ]; then
        local dedup_ratio=$(awk "BEGIN {printf \"%.1f\", ($hardlink_count / $total_files) * 100}")
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_LOG_STATS"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_HARDLINK_COUNT" "$hardlink_count")"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_DEDUP_RATIO" "${dedup_ratio}%")"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_TOTAL_FILES" "$total_files")"
        
        # Export dedup rate for history
        export BACKUP_DEDUP_RATE="$dedup_ratio"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_RATE_CALCULATED" "$dedup_ratio")"
    fi

    # ---------------------------------------------------------------------
    # 2. DETAILED LOG GENERATION (Optional / May be empty on cifs_optimized)
    # ---------------------------------------------------------------------
    if [ "${DEDUP_DETAILED_LOG:-0}" -eq 1 ] && [ -n "$DEDUP_LOGFILE" ]; then
        # USE LANGUAGE VARIABLE: Generating log...
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_MSG_GENERATING_LOG"
        
        # We try to find hardlinked files. 
        # NOTE: On 'cifs_optimized' (noserverino), this returns nothing because client sees link count 1.
        # But the stats above are correct regardless!
        
        find "$backup_dir" -type f -links +1 -printf "%n|%s|%P\n" > "${DEDUP_LOGFILE}.raw"
        
        # Process the raw list to make it human readable (Links > 1 = Deduplicated)
        while IFS='|' read -r links size filepath; do
            if [ -n "$links" ]; then
                # Convert bytes to human readable (e.g. 1.5MB)
                human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Links: $links] [$human_size] $filepath" >> "$DEDUP_LOGFILE"
            fi
        done < "${DEDUP_LOGFILE}.raw"
        
        rm -f "${DEDUP_LOGFILE}.raw"
        
        # USE LANGUAGE VARIABLE: Log done.
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_MSG_LOG_DONE"
    fi
    
    return 0
}
# ===== [ END: DEDUPLICATION FUNCTIONS ] =====
# =========================================================================
# FUNCTION: cleanup_old_encrypted_backups
# Delete old encrypted backups based on retention policy
# ===== [ MODIFIED: Support for date-based folders & strict retention ] =====
# =========================================================================
cleanup_old_encrypted_backups() {
    local cipher_dir="$1"
    local max_age_days="${ENCRYPTED_BACKUP_AGE_DAYS:-0}"
    local use_date_folders="${BACKUP_USE_DATE_FOLDERS:-0}"
    local readable_names="${READABLE_NAMES:-0}"
    # --- [ FIX: Variable dedup_enabled definieren ] ---
    local dedup_enabled="${DEDUP_ENABLE:-0}"
    
    # Skip if retention is disabled
    if [ "$max_age_days" -eq 0 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_RETENTION_DISABLED"
        return 0
    fi

   # ===== [ Determine retention mode for accurate counting ] =====
    local retention_mode="flat"
    if [ "$dedup_enabled" -eq 1 ] || [ "$use_date_folders" -eq 1 ]; then
        retention_mode="folders"
    fi

    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_RETENTION_SEARCH_START" "$max_age_days")"
    
    local deleted_count=0
    local search_depth="${ENCRYPTED_BACKUP_MAXDEPTH:-2}"
    
    # --- [ NEW LOGIC: NAME BASED RETENTION (The name never lies) ] ---
    
    # Calculate Cutoff-Timestamp (Current time - Max Age)
    local current_ts=$(date +%s)
    local max_seconds=$((max_age_days * 86400))
    local cutoff_ts=$((current_ts - max_seconds))
    
    # Calculate find age for flat files (fallback)
    local find_age_days=$((max_age_days - 1))
    
    # ===== [ Date-based folder deletion logic ] =====
    if [ "$use_date_folders" -eq 1 ]; then
        # Delete entire date folders older than retention period
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_RETENTION_DATE_FOLDER_MODE"
        
        # Define find pattern based on READABLE_NAMES
        local find_pattern="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
        if [ "$readable_names" -eq 0 ]; then
            find_pattern="*"
        fi
        
        # Find folders (using process substitution for global variable scope)
        while IFS= read -r folder; do
            local folder_name=$(basename "$folder")
            local should_delete=0
            
            # --- CASE A: Readable Names (Format: YYYY-MM-DD) ---
            # Strong logic: Parse date from name. Trusted source.
            if [[ "$folder_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                
                # Convert Name to Unix Timestamp
                local folder_ts=$(date -d "$folder_name" +%s 2>/dev/null)
                
                # If valid timestamp and older than cutoff
                if [ -n "$folder_ts" ] && [ "$folder_ts" -lt "$cutoff_ts" ]; then
                    should_delete=1
                fi

            # --- CASE B: Encrypted Names (gocryptfs scrambled) ---
            # Fallback: Must use mtime because name is unreadable
            elif [ "$readable_names" -eq 0 ] && [ "$folder_name" != "gocryptfs.conf" ] && [ "$folder_name" != "gocryptfs.diriv" ]; then
                
                local folder_mtime=$(stat -c %Y "$folder" 2>/dev/null || echo 0)
                # Check strict cutoff timestamp (same math as name-based)
                if [ "$folder_mtime" -lt "$cutoff_ts" ]; then
                    should_delete=1
                fi
            fi
            
            # --- EXECUTE DELETION ---
            if [ "$should_delete" -eq 1 ]; then
                 if [ $DRY_RUN -eq 1 ]; then
                    log_echo "[DRY-RUN] $(printf "$ENC_RETENTION_DELETING_FOLDER" "$folder")"
                    local file_count=$(find "$folder" -type f 2>/dev/null | wc -l)
                    deleted_count=$((deleted_count + file_count))
                    DELETED_COUNT_ENCR=$((DELETED_COUNT_ENCR + file_count))
                    if [ "$retention_mode" = "folders" ]; then
                            DELETED_FOLDERS=$((DELETED_FOLDERS + 1))
                    fi
                else
                    local file_count=$(find "$folder" -type f 2>/dev/null | wc -l)
                    
                    if rm -rf "$folder"; then
                        deleted_count=$((deleted_count + file_count))
                        DELETED_COUNT_ENCR=$((DELETED_COUNT_ENCR + file_count))
                        if [ "$retention_mode" = "folders" ]; then
                            DELETED_FOLDERS=$((DELETED_FOLDERS + 1))
                        fi
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_RETENTION_DELETED_FOLDER" "$folder" "$file_count")"
                    else
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_ERR_DELETE_FOLDER_FAILED" "$folder")"
                    fi
                fi
            fi
        done < <(find "$cipher_dir" -maxdepth 1 -type d -name "$find_pattern" 2>/dev/null)
    else
        # ===== [ Individual file deletion logic (Flat Structure) ] =====
        # Find old encrypted files (Fallback to mtime as filenames are often random/hashes here)
        while IFS= read -r file; do
            if [ $DRY_RUN -eq 1 ]; then
                ((deleted_count++))
                ((DELETED_COUNT_ENCR++))
                # Note: Flat files do not count towards DELETED_FOLDERS
                FILE_AGE=$(stat -c %y "$file" 2>/dev/null || echo "unbekannt")
                log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_DELETE" "$file" "$FILE_AGE")"
            else
                if rm -f "$file"; then
                    ((deleted_count++))
                    ((DELETED_COUNT_ENCR++))
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_RETENTION_DELETING" "$file")"
                fi
            fi
        done < <(find "$cipher_dir" -maxdepth "$search_depth" -type f \
            \( -name "*" \) \
            -mtime +"$find_age_days" 2>/dev/null | grep -v "gocryptfs.conf")
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_RETENTION_DELETED_COUNT" "$deleted_count")"
    return 0
}

# =========================================================================
# ===== [ UNENCRYPTED BACKUP RETENTION - NAME BASED ] =====
# =========================================================================
# FUNCTION: cleanup_old_unencrypted_backups
# Delete old unencrypted backups based on DATE IN FOLDERNAME (Robust against mtime changes)
# =========================================================================
cleanup_old_unencrypted_backups() {
    local backup_dir="$1"
    local max_age_days="${BACKUP_AGE_DAYS:-14}"
    local use_date_folders="${BACKUP_USE_DATE_FOLDERS:-0}"
    local dedup_enabled="${DEDUP_ENABLE:-0}"
    
    # Skip if retention is disabled
    if [ "$max_age_days" -eq 0 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $UNENC_RETENTION_DISABLED"
        return 0
    fi

    local retention_mode="flat"
    if [ "$dedup_enabled" -eq 1 ] || [ "$use_date_folders" -eq 1 ]; then
        retention_mode="folders"
    fi

    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_RETENTION_SEARCH_START" "$max_age_days")"
    
    local deleted_count=0
    
    # Calculate Cutoff-Timestamp (Current time - Max Age)
    # Example: Now = 1000, MaxAge = 3 days (300). Cutoff = 700.
    # Any folder with a date timestamp < 700 is too old.
    local current_ts=$(date +%s)
    local max_seconds=$((max_age_days * 86400))
    local cutoff_ts=$((current_ts - max_seconds))
    
    # ===== [ DEDUP or DATE-FOLDER MODE: Delete timestamped folders ] =====
    if [ "$dedup_enabled" -eq 1 ] || [ "$use_date_folders" -eq 1 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $UNENC_RETENTION_FOLDER_MODE (Name-based)"
        
        # Check if nested structure is used (DEDUP + DATE_FOLDERS)
        if [ "$dedup_enabled" -eq 1 ] && [ "$use_date_folders" -eq 1 ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $UNENC_RETENTION_NESTED_FOLDER_MODE"
            
            # Iterate through DATE folders (YYYY-MM-DD)
            # --- [ MODIFIED: Using Process Substitution to preserve variable scope ] ---
            while read -r date_folder; do
                
                # Iterate through SNAPSHOT folders inside (YYYY-MM-DD_HH-MM-SS)
                while read -r timestamp_folder; do
                    
                    # Extract Date from Foldername
                    local folder_name=$(basename "$timestamp_folder")
                    # Take the first 10 chars (YYYY-MM-DD)
                    local date_part="${folder_name:0:10}"
                    
                    # Convert to Unix Timestamp
                    local folder_ts=$(date -d "$date_part" +%s 2>/dev/null)
                    
                    # If conversion failed, skip
                    if [ -z "$folder_ts" ]; then continue; fi
                    
                    # COMPARE: If Folder-Date is OLDER than Cutoff-Date
                    if [ "$folder_ts" -lt "$cutoff_ts" ]; then
                        if [ $DRY_RUN -eq 1 ]; then
                            log_echo "[DRY-RUN] $(printf "$UNENC_RETENTION_DELETING_FOLDER" "$timestamp_folder")"
                            local file_count=$(find "$timestamp_folder" -type f 2>/dev/null | wc -l)
                            deleted_count=$((deleted_count + file_count))
                            DELETED_COUNT=$((DELETED_COUNT + file_count))
                            if [ "$retention_mode" = "folders" ]; then DELETED_FOLDERS=$((DELETED_FOLDERS + 1)); fi
                        else
                            local file_count=$(find "$timestamp_folder" -type f 2>/dev/null | wc -l)
                            if rm -rf "$timestamp_folder"; then
                                deleted_count=$((deleted_count + file_count))
                                DELETED_COUNT=$((DELETED_COUNT + file_count))
                                if [ "$retention_mode" = "folders" ]; then DELETED_FOLDERS=$((DELETED_FOLDERS + 1)); fi
                                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_RETENTION_DELETED_FOLDER" "$timestamp_folder" "$file_count")"
                            else
                                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_ERR_DELETE_FOLDER_FAILED" "$timestamp_folder")"
                            fi
                        fi
                    fi
                done < <(find "$date_folder" -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]")
                
                # Cleanup empty parent date folder
                if [ $DRY_RUN -eq 0 ]; then
                    find "$date_folder" -maxdepth 1 -type f \( -name ".DS_Store" -o -name "Thumbs.db" -o -name "desktop.ini" -o -name "._*" \) -delete 2>/dev/null
                    if [ -d "$date_folder/@eaDir" ]; then rm -rf "$date_folder/@eaDir"; fi
                    
                    if rmdir "$date_folder" 2>/dev/null; then
                         log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_RETENTION_DELETED_EMPTY_DATE_FOLDER" "$date_folder")"
                    fi
                fi
            done < <(find "$backup_dir" -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]")
            
        else
           # Simple folder mode (YYYY-MM-DD or YYYY-MM-DD_HH-MM-SS) in root
           # --- [ MODIFIED: Using Process Substitution ] ---
            while read -r folder; do
                local folder_name=$(basename "$folder")
                # Extract date part (first 10 chars work for both formats)
                local date_part="${folder_name:0:10}"
                local folder_ts=$(date -d "$date_part" +%s 2>/dev/null)
                
                if [ -z "$folder_ts" ]; then continue; fi

                if [ "$folder_ts" -lt "$cutoff_ts" ]; then
                     if [ $DRY_RUN -eq 1 ]; then
                        log_echo "[DRY-RUN] $(printf "$UNENC_RETENTION_DELETING_FOLDER" "$folder")"
                        local file_count=$(find "$folder" -type f 2>/dev/null | wc -l)
                        deleted_count=$((deleted_count + file_count))
                        DELETED_COUNT=$((DELETED_COUNT + file_count))
                        if [ "$retention_mode" = "folders" ]; then DELETED_FOLDERS=$((DELETED_FOLDERS + 1)); fi
                    else
                        local file_count=$(find "$folder" -type f 2>/dev/null | wc -l)
                        if rm -rf "$folder"; then
                            deleted_count=$((deleted_count + file_count))
                            DELETED_COUNT=$((DELETED_COUNT + file_count))
                            if [ "$retention_mode" = "folders" ]; then DELETED_FOLDERS=$((DELETED_FOLDERS + 1)); fi
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_RETENTION_DELETED_FOLDER" "$folder" "$file_count")"
                        else
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_ERR_DELETE_FOLDER_FAILED" "$folder")"
                        fi
                    fi
                fi
            done < <(find "$backup_dir" -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*")
        fi
    else
        # ===== [ FLAT STRUCTURE MODE: Delete individual old files ] =====
        # Flat files rely on mtime, as they might not have dates in names. 
        # But we can try to improve it if filenames contain dates.
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $UNENC_RETENTION_FILE_MODE"
        
        # Calculate find age for strict consistency 
        local find_age_days=$((max_age_days - 1))
        
        FIND_EXPR=()
        for ext in "${BACKUP_FILETYPES[@]}"; do
            FIND_EXPR+=(-name "$ext" -o)
        done
        unset 'FIND_EXPR[-1]'
        
        # Here we stick to mtime as flat files often don't have parseable dates
        # But we use the corrected find_age logic
        # --- [ MODIFIED: Using Process Substitution ] ---
        while read -r file; do
             if [ $DRY_RUN -eq 1 ]; then
                ((deleted_count++))
                ((DELETED_COUNT++))
                if [ "$retention_mode" = "flat" ]; then DELETED_FOLDERS=$((DELETED_FOLDERS + 1)); fi
                FILE_AGE=$(stat -c %y "$file" 2>/dev/null || echo "unknown")
                log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_DELETE" "$file" "$FILE_AGE")"
            else
                if rm -f "$file"; then
                    ((deleted_count++))
                    ((DELETED_COUNT++))
                    if [ "$retention_mode" = "flat" ]; then DELETED_FOLDERS=$((DELETED_FOLDERS + 1)); fi
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_RETENTION_DELETING" "$file")"
                fi
            fi
        done < <(find "$backup_dir" -maxdepth "${BACKUP_MAXDEPTH:-1}" -type f \( "${FIND_EXPR[@]}" \) -mtime +"$find_age_days" 2>/dev/null)
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$UNENC_RETENTION_DELETED_COUNT" "$deleted_count")"
    return 0
}
# ===== [ END: UNENCRYPTED BACKUP RETENTION WITH FOLDER SUPPORT ] =====

# =========================================================================
# === [ MODIFIED START: Resource Monitoring Function (Robust) ] ===
# =========================================================================
# Function: Collect System Resources (Background Process)
# Captures RAM (MB), CPU Load (1m), and I/O Wait (%)
collect_resource_stats() {
    local interval="${RESOURCE_MONITOR_INTERVAL:-10}"
    local logfile="$1"
    
    # Clear previous log
    > "$logfile"
    
    # --- WRITE INITIAL DATA POINT IMMEDIATELY ---
    # Prevents empty graphs on short backup runs (< interval)
    local ts=$(date '+%H:%M:%S')
    local ram_used=$(free -m | awk 'NR==2{print $2-$7}')
    local cpu_load=$(awk '{print $1}' /proc/loadavg)
    # Use 0 for initial IO wait (vmstat needs time to sample)
    echo "$ts,$ram_used,$cpu_load,0" >> "$logfile"
    
    # --- START LOOP ---
    while true; do
        sleep "$interval"
        
        ts=$(date '+%H:%M:%S')
        
        # RAM Usage
        ram_used=$(free -m | awk 'NR==2{print $2-$7}')
        
        # CPU Load
        cpu_load=$(awk '{print $1}' /proc/loadavg)
        
        # I/O Wait % (Sample for 1 second)
        # vmstat 1 2 takes 1 second delay. Output is 2 lines. 
        # We take the 2nd line (current sample), column 16 (wa).
        # We assume column 16; some systems differ, but this is standard.
        local io_wait=$(vmstat 1 2 | tail -1 | awk '{print $16}')
        io_wait=${io_wait:-0}
        
        echo "$ts,$ram_used,$cpu_load,$io_wait" >> "$logfile"
    done
}
# =========================================================================
# === [ MODIFIED END: Resource Monitoring Function (Robust) ] ===
# =========================================================================
run_system_check() {
    echo "$MSG_CHECK_TITLE"
    echo ""
    echo "$MSG_CHECK_PREREQ"
    echo ""

    local MISSING=0
    local WARNINGS=0

    # Helper function for checking commands
    check_command() {
        local cmd="$1"
        local required="$2"
        local package="$3"
        
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "$(printf "$MSG_CMD_OK" "$cmd" "$(command -v "$cmd")")"
            return 0
        else
            if [ "$required" = "required" ]; then
                echo "$(printf "$ERR_CMD_NOT_FOUND" "$cmd")"
                if [ -n "$package" ]; then
                    echo "$(printf "$ERR_CMD_INSTALL" "$package")"
                fi
                ((MISSING++))
                return 1
            else
                echo "$(printf "$WARN_CMD_OPTIONAL" "$cmd")"
                if [ -n "$package" ]; then
                    echo "$(printf "       Installation: sudo apt-get install %s" "$package")"
                fi
                ((WARNINGS++))
                return 2
            fi
        fi
    }

    # Helper function for checking features
    check_feature() {
        local feature="$1"
        local config_var="$2"
        local config_value="$3"
        
        if [ "${!config_var}" = "$config_value" ]; then
            echo "$(printf "$MSG_FEATURE_ACTIVATED" "$feature")"
            return 0
        else
            echo "$(printf "$MSG_FEATURE_DEACTIVATED" "$feature")"
            return 1
        fi
    }

    echo "$MSG_SUB_TITLE_REQUIRED"
    check_command "bash" "required" "bash"
    check_command "rsync" "required" "rsync"
    check_command "mount.cifs" "required" "cifs-utils"
    check_command "zip" "required" "zip"
    check_command "date" "required" "coreutils"
    check_command "stat" "required" "coreutils"
    check_command "find" "required" "findutils"
    check_command "awk" "required" "gawk"
    check_command "numfmt" "required" "coreutils"
    check_command "sed" "required" "sed"
    check_command "grep" "required" "grep"
    check_command "tail" "required" "coreutils"
    check_command "head" "required" "coreutils"
    check_command "ping" "required" "iputils-ping"
    check_command "base64" "required" "coreutils"

    echo ""
    echo "$MSG_SUB_TITLE_CONDITIONAL"
    
    # MySQL check
    if [ "${BACKUP_SQL:-0}" -eq 1 ]; then
        echo ""
        check_feature "MySQL-Backup" "BACKUP_SQL" "1"
        check_command "mysql" "required" "mysql-client oder mariadb-client"
        check_command "mysqldump" "required" "mysql-client oder mariadb-client"
    else
        echo ""
        echo "$MSG_MYSQL_DISABLED"
        echo "$MSG_MYSQL_NOT_REQUIRED"
    fi

    # E-Mail check
    if [ "${SEND_MAIL:-0}" -eq 1 ]; then
        echo ""
        check_feature "$MSG_MSMTP_CONFIG_CHECK" "SEND_MAIL" "1"
        check_command "msmtp" "required" "msmtp msmtp-mta"
        
        # Check msmtp configuration
        if [ -f "$HOME_PI/.msmtprc" ] || [ -f "${HOME_PI}/.msmtprc" ]; then
            echo "$MSG_MSMTP_CONFIG_FOUND"
        else
            echo "$ERR_MSMTP_CONFIG_NOT_FOUND"
            echo "$ERR_MSMTP_CONFIG_CREATE"
            ((MISSING++))
        fi
    else
        echo ""
        echo "$MSG_MAIL_DISABLED"
        echo "$MSG_MAIL_NOT_REQUIRED"
    fi
     
    echo ""
    echo "$MSG_SUB_TITLE_SYSTEM_CONFIG"
    
    # Check sudo rights
    echo ""
    if sudo -n true 2>/dev/null; then
        echo "$MSG_SUDO_OK"
    elif sudo -v 2>/dev/null; then
        echo "$WARN_SUDO_PASSWORD"
        echo "$WARN_SUDO_CONFIG_PASSLESS"
        echo "       see README for details"
        ((WARNINGS++))
    else
        echo "$ERR_SUDO_NOT_AVAILABLE"
        echo "$ERR_SUDO_GROUP_REQUIRED"
        ((MISSING++))
    fi

   # -------------------------------------------------------------------------
    # === [ NAS REACHABILITY CHECK IN SYSTEM CHECK ] ===
    # -------------------------------------------------------------------------
    # Check NAS reachability
    echo ""
    if [ -n "$NAS_IP" ]; then
        echo "$(printf "$MSG_NAS_CHECK" "$NAS_IP")"
        
        local ping_attempts=0
        local ping_success=0
        local max_ping_attempts=3
        
        while [ $ping_attempts -lt $max_ping_attempts ] && [ $ping_success -eq 0 ]; do
            ((ping_attempts++))
            echo "$(printf "$MSG_PING_ATTEMPT" "$ping_attempts" "$max_ping_attempts")"
            
            if ping -c 2 -W 3 "$NAS_IP" >/dev/null 2>&1; then
                echo "$(printf "$MSG_NAS_OK" "$NAS_IP")"
                ping_success=1
            else
                if [ $ping_attempts -lt $max_ping_attempts ]; then
                    echo "$(printf "$MSG_PING_FAILED_ATTEMPT" "$ping_attempts" "$max_ping_attempts")"
                    sleep 3
                fi
            fi
        done
        
        if [ $ping_success -eq 0 ]; then
            echo "$(printf "$ERR_NAS_UNREACHABLE" "$NAS_IP")"
            echo "$ERR_CHECK_NETWORK"
            
            if [ "${IGNORE_FAILED_PING:-0}" -eq 1 ]; then
                echo "$WARN_PING_IGNORED"
                echo "$WARN_PING_SYSCHECK_CONTINUE"
                ((WARNINGS++))
            else
                ((MISSING++))
            fi
        fi
    else
        echo "$ERR_NAS_IP_NOT_SET"
        ((MISSING++))
    fi
    # === [ END: NAS REACHABILITY CHECK IN SYSTEM CHECK ] ===
    # -------------------------------------------------------------------------

    # Check Credentials file
    echo ""
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo "$(printf "$MSG_CRED_FILE_FOUND" "$CREDENTIALS_FILE")"
        
        # Check permissions
        PERMS=$(stat -c %a "$CREDENTIALS_FILE" 2>/dev/null)
        if [ "$PERMS" = "600" ]; then
            echo "$MSG_PERMS_OK"
        else
            echo "$(printf "$WARN_PERMS_WRONG" "$PERMS")"
            echo "$(printf "$WARN_PERMS_HINT" "$CREDENTIALS_FILE")"
            ((WARNINGS++))
        fi
        
        # Check content (temporarily load in subshell to avoid polluting namespace)
        (
            source "$CREDENTIALS_FILE"
            if [ -z "$NAS_USER" ] || [ -z "$NAS_PASS" ]; then
                exit 1
            fi
        )
        if [ $? -eq 0 ]; then
            echo "$MSG_CRED_NAS_OK"
        else
            echo "$(printf "$ERR_CRED_NAS_MISSING" "$CREDENTIALS_FILE")"
            ((MISSING++))
        fi
        
        if [ "${BACKUP_SQL:-0}" -eq 1 ]; then
            (
                source "$CREDENTIALS_FILE"
                if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
                    exit 1
                fi
            )
            if [ $? -eq 0 ]; then
                echo "$MSG_CRED_MYSQL_OK"
            else
                echo "$ERR_CRED_MYSQL_MISSING"
                ((MISSING++))
            fi
        fi
    else
        echo "$(printf "$ERR_CRED_FILE_NOT_FOUND" "$CREDENTIALS_FILE")"
        echo "$ERR_CRED_FILE_CREATE"
        ((MISSING++))
    fi

    # Check Dashboard Generator
    if [ "${DASHBOARD_ENABLE:-0}" -eq 1 ]; then
        echo ""
        check_feature "$MSG_FEATURE_DASHBOARD_GEN" "DASHBOARD_ENABLE" "1"
        if [ -f "$DASHBOARD_GENERATOR" ]; then
            echo "$(printf "$MSG_DASHBOARD_GEN_FOUND" "$DASHBOARD_GENERATOR")"
            
            # Check if executable
            if [ -x "$DASHBOARD_GENERATOR" ]; then
                echo "$MSG_DASHBOARD_EXECUTABLE"
            else
                echo "$WARN_DASHBOARD_NOT_EXECUTABLE"
                echo "$(printf "$WARN_DASHBOARD_CHMOD_HINT" "$DASHBOARD_GENERATOR")"
                ((WARNINGS++))
            fi
            
            # Check if function exists
            if grep -q "generate_dashboard()" "$DASHBOARD_GENERATOR" 2>/dev/null; then
                echo "$MSG_DASHBOARD_FUNC_FOUND"
            else
                echo "$ERR_DASHBOARD_FUNC_MISSING"
                ((MISSING++))
            fi
        else
            echo "$(printf "$ERR_DASHBOARD_GEN_NOT_FOUND" "$DASHBOARD_GENERATOR")"
            ((MISSING++))
        fi
    fi

    # Check backup sources
    echo ""
    echo "$MSG_SUB_TITLE_BACKUP_SOURCES"
    local SOURCE_COUNT=${#BACKUP_SOURCES[@]}
    echo "$(printf "$MSG_CONFIGURED" "$SOURCE_COUNT")"
    
    if [ $SOURCE_COUNT -eq 0 ]; then
        echo "$ERR_BACKUP_SOURCES_MISSING"
        ((MISSING++))
    else
        echo "$MSG_SOURCES_DEFINED"
        
        # Show first 5 sources
        local SHOW_COUNT=$((SOURCE_COUNT < 5 ? SOURCE_COUNT : 5))
        for i in $(seq 0 $((SHOW_COUNT - 1))); do
            echo "     - ${BACKUP_SOURCES[$i]}"
        done
        
        if [ $SOURCE_COUNT -gt 5 ]; then
            echo "$(printf "$MSG_SOURCES_MORE" "$((SOURCE_COUNT - 5))")"
        fi
    fi

    # Summary
    echo ""
    echo "$MSG_SUMMARY_TITLE"
    echo ""
    
    if [ $MISSING -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo "$MSG_ALL_CHECKS_SUCCESS"
        echo ""
        echo "$MSG_SYSTEM_READY"
        echo "$MSG_FIRST_CHECK_AUTO_SET"
        return 0
    elif [ $MISSING -eq 0 ] && [ $WARNINGS -gt 0 ]; then
        echo "$WARN_BASIC_SUCCESS_SUMMARY"
        echo "$(printf "$WARN_WARNINGS_FOUND" "$WARNINGS")"
        echo ""
        echo "$WARN_OPTIMIZATION_POTENTIAL"
        echo "$WARN_REVIEW_WARNINGS"
        echo ""
        echo "$WARN_CONTINUE_PROMPT"
        read -r -t 30 RESPONSE
        
        if [[ "$RESPONSE" =~ ^[jJyY]$ ]]; then
            echo ""
            echo "$MSG_CONTINUE_BACKUP"
            return 0
        else
            echo ""
            echo "$WARN_ABORT_HINT"
            return 1
        fi
    else
        echo "$ERR_CHECK_FAILED_SUMMARY"
        echo ""
        echo "$(printf "$ERR_MISSING_DEPS_COUNT" "$MISSING")"
        echo "$(printf "Warnings: %s" "$WARNINGS")"
        echo ""
        echo "$ERR_INSTALL_MISSING"
        echo ""
        echo "$ERR_BASE_INSTALL"
        echo "sudo apt-get update"
        echo "sudo apt-get install -y bash rsync cifs-utils coreutils gawk findutils zip sed grep iputils-ping"
        echo ""
        
        if [ "${BACKUP_SQL:-0}" -eq 1 ]; then
            echo "$ERR_MYSQL_INSTALL"
            echo "sudo apt-get install -y mysql-client"
            echo "$ERR_MARIADB_INSTALL"
            echo "sudo apt-get install -y mariadb-client"
            echo ""
        fi
        
        if [ "${SEND_MAIL:-0}" -eq 1 ]; then
            echo "$ERR_MAIL_INSTALL"
            echo "sudo apt-get install -y msmtp msmtp-mta ca-certificates"
            echo ""
        fi

    # - [ ENCRYPTION: Check encryption prerequisites ] ---
    
    if [ "${BACKUP_ENCRYPTION:-0}" -eq 1 ]; then
        echo ""
        check_feature "$ENC_FEATURE_NAME" "BACKUP_ENCRYPTION" "1"
        
        # Check gocryptfs
        if [ "$ENCRYPTION_METHOD" = "gocryptfs" ]; then
            check_command "gocryptfs" "required" "gocryptfs"
            check_command "fusermount" "required" "fuse"
        fi
        
        # Check GPG for SQL dumps
        if [ "${BACKUP_SQL:-0}" -eq 1 ] && [ -n "${GPG_RECIPIENT:-}" ]; then
            check_command "gpg" "required" "gnupg"
        fi
        
        # Check password file
        if [ -n "${ENCRYPTION_PASSWORD_FILE:-}" ]; then
            if [ -f "$ENCRYPTION_PASSWORD_FILE" ]; then
                echo "$ENC_CHECK_PASSWORD_FILE_OK"
                
                # Check permissions
                PERMS=$(stat -c %a "$ENCRYPTION_PASSWORD_FILE" 2>/dev/null)
                if [ "$PERMS" = "600" ]; then
                    echo "$ENC_CHECK_PERMS_OK"
                else
                    echo "$(printf "$ENC_CHECK_PERMS_WRONG" "$PERMS")"
                    ((WARNINGS++))
                fi
            else
                echo "$(printf "$ENC_CHECK_PASSWORD_FILE_MISSING" "$ENCRYPTION_PASSWORD_FILE")"
                ((MISSING++))
            fi
        fi
    fi
         
    # --- [ END: Encryption check ] ---
        echo "$ERR_INSTALL_PACKAGES"
        echo ""
        return 1
    fi

# ===== [ DEDUPLICATION - System check ] =====
    # Check deduplication prerequisites
    if [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
        echo ""
        check_feature "$DEDUP_FEATURE_NAME" "DEDUP_ENABLE" "1"
        
        # Test hardlink support on backup path (if accessible)
        if [ -d "$BACKUP_PATH" ] && mountpoint -q "$BACKUP_PATH" 2>/dev/null; then
            echo "$DEDUP_CHECK_FILESYSTEM"
            if test_hardlink_support "$BACKUP_PATH"; then
                echo "$DEDUP_CHECK_HARDLINKS_OK"
            else
                echo "$DEDUP_ERR_NO_HARDLINK_SUPPORT"
                ((MISSING++))
            fi
        else
            echo "$DEDUP_CHECK_NAS_SUPPORT"
            echo "$DEDUP_HARD_LINK_TEST_ON_FIRST_BACKUP"
        fi
    fi
# ===== [ END: DEDUPLICATION system check ] =====

}


# -------------------------------------------------------------------------
# PERFORM SYSTEM CHECK (if FIRST_CHECK=1)
# -------------------------------------------------------------------------
if [ "${FIRST_CHECK:-0}" -eq 1 ]; then
    echo "==========================================================================="
    echo "$MSG_FIRST_START_TITLE"
    echo "==========================================================================="
    echo ""
    
    run_system_check
    CHECK_RESULT=$?
    
    if [ $CHECK_RESULT -eq 0 ]; then
        echo ""
        echo "==========================================================================="
        echo "$MSG_CHECK_SUCCESS_TITLE"
        echo "==========================================================================="
        echo ""
        
        # Set FIRST_CHECK to 0 in the config file
        if [ -w "$CONFIG_FILE" ]; then
            sed -i 's/^FIRST_CHECK=1/FIRST_CHECK=0/' "$CONFIG_FILE"
            echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_FIRST_CHECK_SET" "$CONFIG_FILE")"
            echo ""
        else
            echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $WARN_HISTORY_ROTATION_FAIL"
            echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$WARN_HISTORY_NO_WRITE_PERMS" "$CONFIG_FILE")"
            echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $WARN_HISTORY_MANUAL_CHANGE"
            echo ""
        fi
        
        sleep 2
    else
        echo ""
        echo "==========================================================================="
        echo "$ERR_CHECK_ABORT_TITLE"
        echo "==========================================================================="
        echo ""
        echo "$ERR_INSTALL_PACKAGES"
        echo ""
        exit 1
    fi
fi
#=========================================================================
# COMMAND-LINE PARAMETER PROCESSING
# =========================================================================
RESTORE_MODE=0
RESTORE_DATE=""
RESTORE_TARGET=""
RESTORE_FILE=""
LIST_MODE=0
RESTORE_LATEST=0  
RESTORE_SOURCE_MODE="auto"  # auto, encrypted, unencrypted, all

# Process command-line parameters (--dry-run, --help, --restore)
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=1
            shift
            ;;
        --restore)
            RESTORE_MODE=1
            shift
            ;;
        --date)
            RESTORE_DATE="$2"
            shift 2
            ;;
        --target)
            RESTORE_TARGET="$2"
            shift 2
            ;;
        --file)
            RESTORE_FILE="$2"
            shift 2
            ;;
        --list)
            LIST_MODE=1
            shift
            ;;
        --latest)  
            RESTORE_LATEST=1
            shift
            ;;
        --source)
            RESTORE_SOURCE_MODE="$2"
            shift 2
            ;;
        --help|-h)
            echo "$(printf "$HELP_USAGE" "$0")"
            echo ""
            echo "$HELP_OPTIONS"
            echo "$HELP_DRY_RUN"
            echo "$HELP_HELP"
            echo ""
            echo "$RESTORE_HELP_USAGE"
            echo "$RESTORE_HELP_LIST"
            echo "$RESTORE_HELP_RESTORE"
            echo "$RESTORE_HELP_FILE"
            echo "$RESTORE_HELP_LATEST" 
            echo "$RESTORE_HELP_SOURCE"
            echo ""
            echo "$RESTORE_HELP_EXAMPLES"
            echo "$(printf "$RESTORE_HELP_EXAMPLE_BASIC" "$0")"
            echo "$(printf "$RESTORE_HELP_EXAMPLE_LATEST" "$0")"
            echo ""
            echo "$HELP_CONFIG_TITLE"
            echo "$(printf "$HELP_CONFIG_DEFAULT" "$CONFIG_FILE")"
            echo "$(printf "$HELP_CONFIG_ALT" "$0")"
            echo ""
            exit 0
            ;;
        *)
            echo "$(printf "$MSG_UNKNOWN_PARAM" "$1")"
            echo "$MSG_USE_HELP"
            exit 1
            ;;
    esac
done

# =========================================================================
# RESTORE MODE EXECUTION
# =========================================================================

if [ "$RESTORE_MODE" -eq 1 ]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "              $RESTORE_INFO_MODE_ACTIVE                        "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Load credentials
    if [ -f "$CREDENTIALS_FILE" ]; then
        source "$CREDENTIALS_FILE"
    else
        echo "$(printf "$ERR_CRED_FILE_READ_FAIL" "$CREDENTIALS_FILE")"
        exit 1
    fi
    
    # Step 1: Mount NAS
    echo "$RESTORE_INFO_MOUNT_NAS"
    mount_nas_for_restore
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
   # ===== [ MODIFIED: Multi-source restore support ] =====
    # Step 2: Determine restore source(s) based on --source parameter
    
    RESTORE_SOURCES=()  # Array to hold multiple sources
    RESTORE_ENCRYPTED_MOUNTED=0
    
    case "$RESTORE_SOURCE_MODE" in
        encrypted)
            # Force encrypted source
            if [ ! -d "$BACKUP_PATH/encrypted" ]; then
                echo "$RESTORE_ERR_NO_ENCRYPTED_BACKUPS"
                umount_nas_after_restore
                exit 1
            fi
            
            echo "$RESTORE_INFO_DECRYPT"
            check_encryption_prerequisites
            if [ $? -ne 0 ]; then
                umount_nas_after_restore
                exit 1
            fi
            
            ENCRYPTION_CIPHERTEXT_DIR="${ENCRYPTION_CIPHERTEXT_DIR:-$BACKUP_PATH/encrypted}"
            ENCRYPTION_PLAINTEXT_MOUNT="${ENCRYPTION_PLAINTEXT_MOUNT:-/mnt/backup_decrypted}"
            
            mount_encrypted_filesystem "$ENCRYPTION_CIPHERTEXT_DIR" "$ENCRYPTION_PLAINTEXT_MOUNT"
            if [ $? -ne 0 ]; then
                umount_nas_after_restore
                exit 1
            fi
            
            RESTORE_SOURCES+=("$ENCRYPTION_PLAINTEXT_MOUNT")
            RESTORE_ENCRYPTED_MOUNTED=1
            ;;
            
        unencrypted)
            # Force unencrypted source
            RESTORE_SOURCES+=("$BACKUP_PATH")
            ;;
            
        all)
            # Show both encrypted and unencrypted
            echo "$RESTORE_INFO_DUAL_MODE"
            
            # Add unencrypted source
            RESTORE_SOURCES+=("$BACKUP_PATH")
            
            # Try to mount encrypted source if exists
            if [ -d "$BACKUP_PATH/encrypted" ]; then
                echo "$RESTORE_INFO_DECRYPT"
                check_encryption_prerequisites
                if [ $? -eq 0 ]; then
                    ENCRYPTION_CIPHERTEXT_DIR="${ENCRYPTION_CIPHERTEXT_DIR:-$BACKUP_PATH/encrypted}"
                    ENCRYPTION_PLAINTEXT_MOUNT="${ENCRYPTION_PLAINTEXT_MOUNT:-/mnt/backup_decrypted}"
                    
                    mount_encrypted_filesystem "$ENCRYPTION_CIPHERTEXT_DIR" "$ENCRYPTION_PLAINTEXT_MOUNT"
                    if [ $? -eq 0 ]; then
                        RESTORE_SOURCES+=("$ENCRYPTION_PLAINTEXT_MOUNT")
                        RESTORE_ENCRYPTED_MOUNTED=1
                    fi
                fi
            fi
            ;;
            
        auto|*)
            # Auto-detect based on config (original behavior)
            if [ "$BACKUP_ENCRYPTION" -eq 1 ]; then
                echo "$RESTORE_INFO_DECRYPT"
                check_encryption_prerequisites
                if [ $? -ne 0 ]; then
                    umount_nas_after_restore
                    exit 1
                fi
                
                ENCRYPTION_CIPHERTEXT_DIR="${ENCRYPTION_CIPHERTEXT_DIR:-$BACKUP_PATH/encrypted}"
                ENCRYPTION_PLAINTEXT_MOUNT="${ENCRYPTION_PLAINTEXT_MOUNT:-/mnt/backup_decrypted}"
                
                mount_encrypted_filesystem "$ENCRYPTION_CIPHERTEXT_DIR" "$ENCRYPTION_PLAINTEXT_MOUNT"
                if [ $? -ne 0 ]; then
                    umount_nas_after_restore
                    exit 1
                fi
                
                RESTORE_SOURCES+=("$ENCRYPTION_PLAINTEXT_MOUNT")
                RESTORE_ENCRYPTED_MOUNTED=1
            else
                RESTORE_SOURCES+=("$BACKUP_PATH")
            fi
            ;;
    esac
    # ===== [ END: Multi-source restore support ] =====
    
    # Step 3: List, list with date filter, or restore
    
    if [ "$LIST_MODE" -eq 1 ]; then
        # List mode: show all files or filter by date
        echo "$RESTORE_INFO_LIST_BACKUPS"
        
        # ===== [ MODIFIED: Support multiple sources ] =====
        if [ ${#RESTORE_SOURCES[@]} -gt 1 ]; then
            # Multiple sources: show both
            for source in "${RESTORE_SOURCES[@]}"; do
                if [[ "$source" == *"backup_decrypted"* ]]; then
                    echo ""
                    echo "$RESTORE_INFO_ENCRYPTED_BACKUPS"
                else
                    echo ""
                    echo "$RESTORE_INFO_UNENCRYPTED_BACKUPS"
                fi
                list_available_backups "$source" "$RESTORE_DATE"
            done
        else
            # Single source
            list_available_backups "${RESTORE_SOURCES[0]}" "$RESTORE_DATE"
        fi
        # ===== [ END: Support multiple sources ] =====
        
        RESTORE_EXIT_CODE=0
        
    elif [ -n "$RESTORE_DATE" ] && [ -z "$RESTORE_TARGET" ]; then
        # Only date provided without target: list files from that date
        echo "$(printf "$RESTORE_LIST_DATE_FILTER" "$RESTORE_DATE")"
        
        # ===== [ BUGFIX: Use RESTORE_SOURCES array instead of undefined RESTORE_SOURCE ] =====
        # Iterate over all sources to ensure we find the backup regardless of mode
        for source in "${RESTORE_SOURCES[@]}"; do
            list_available_backups "$source" "$RESTORE_DATE"
        done
        # ===== [ END: Bugfix ] =====
        
        RESTORE_EXIT_CODE=0
        
    elif [ -n "$RESTORE_DATE" ] && [ -n "$RESTORE_TARGET" ]; then
        # Full restore with target directory
        
        # Check if --file was used without --target
        if [ -n "$RESTORE_FILE" ] && [ -z "$RESTORE_TARGET" ]; then
            echo "$RESTORE_ERR_NO_TARGET"
            RESTORE_EXIT_CODE=1
        else
            # ===== [ BUGFIX: Use first available source ] =====
            # In 'auto' mode (default), RESTORE_SOURCES has exactly one entry (encrypted or plain).
            # This fixes the "empty source" bug.
            restore_backup "$RESTORE_DATE" "$RESTORE_TARGET" "${RESTORE_SOURCES[0]}" "$RESTORE_FILE"
            RESTORE_EXIT_CODE=$?
            # ===== [ END: Bugfix ] =====
            
            if [ $RESTORE_EXIT_CODE -eq 0 ]; then
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "$RESTORE_SUCCESS_COMPLETE"
                echo "═══════════════════════════════════════════════════════════════"
                echo "$(printf "$RESTORE_INFO_RESTORED_TO" "$RESTORE_TARGET")"
                echo ""
            fi
        fi
        
    elif [ -n "$RESTORE_FILE" ]; then
        # --file without --date
        echo "$RESTORE_ERR_NO_DATE_FOR_FILE"
        echo ""
        echo "$(printf "$RESTORE_HELP_EXAMPLE" "$0")"
        RESTORE_EXIT_CODE=1
        
    else
        echo "$RESTORE_ERR_NO_DATE"
        echo "$RESTORE_ERR_NO_TARGET"
        echo ""
        echo "$(printf "$RESTORE_HELP_EXAMPLE" "$0")"
        RESTORE_EXIT_CODE=1
    fi
    
   # Cleanup
    if [ "$RESTORE_ENCRYPTED_MOUNTED" -eq 1 ]; then
        umount_encrypted_filesystem "$ENCRYPTION_PLAINTEXT_MOUNT"
    fi
    umount_nas_after_restore
    
    exit $RESTORE_EXIT_CODE
fi


# Announce Dry-Run mode
if [ $DRY_RUN -eq 1 ]; then
    log_echo "$MSG_DRY_RUN_TITLE_1"
    log_echo "$MSG_DRY_RUN_TITLE_2"
    log_echo "$MSG_DRY_RUN_TITLE_3"
    log_echo "$MSG_DRY_RUN_TITLE_4"
    log_echo ""
fi

log_echo "-------------------------------------------------------------------------------------------------"
log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$MSG_LOG_HEADER_START" "$MASTER_IP" "$NAS_IP")"
log_echo "-------------------------------------------------------------------------------------------------"
log_echo ""

# Load and validate credentials
if [ -f "$CREDENTIALS_FILE" ]; then
    source "$CREDENTIALS_FILE"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_CRED_LOAD_SUCCESS" "$CREDENTIALS_FILE")"
    
    if [ -z "$NAS_USER" ] || [ -z "$NAS_PASS" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_CRED_NAS_FAIL" "$CREDENTIALS_FILE")"
        exit 1
    fi
    if [ "$BACKUP_SQL" -eq 1 ] && ([ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]); then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$WARN_SQL_CREDS_MISSING" "$CREDENTIALS_FILE")"
    fi
else
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_CRED_FILE_READ_FAIL" "$CREDENTIALS_FILE")"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_CRED_FILE_CREATE_HINT"
    exit 1
fi



START=$(date +%s)


# =========================================================================
# === [ MODIFIED START: Start Resource Monitor ] ===
# =========================================================================
RESOURCE_MONITOR_PID=""
if [ "${RESOURCE_MONITOR_ENABLE:-0}" -eq 1 ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_START_RESSOURCE_MON"
    collect_resource_stats "$RESOURCE_LOGFILE" &
    RESOURCE_MONITOR_PID=$!
fi


# -------------------------------------------------------------------------
# === [ NAS REACHABILITY CHECK WITH RETRY ] ===
# -------------------------------------------------------------------------
# Check NAS reachability with configurable retry logic
if ! check_nas_reachability "$NAS_IP"; then
    exit 1
fi

# Prepare mount point
if [ ! -d "$BACKUP_PATH" ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_MOUNTPOINT_NOT_EXIST" "$BACKUP_PATH")"
    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MKDIR" "$BACKUP_PATH")"
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_CHOWN" "$BACKUP_PATH")"
    else
        sudo mkdir -p "$BACKUP_PATH"
        sudo chown "$USER":"$USER" "$BACKUP_PATH"
        sudo chmod 755 "$BACKUP_PATH"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_MOUNTPOINT_CREATED" "$BACKUP_PATH")"
    fi
else
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_MOUNTPOINT_EXISTS" "$BACKUP_PATH")"
fi

# If already mounted: unmount
if mountpoint -q "$BACKUP_PATH"; then
    log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$MSG_ALREADY_MOUNTED" "$BACKUP_PATH")"
    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_UNMOUNT_PRE" "$BACKUP_PATH")"
    else
        STATUS=$(sudo umount "$BACKUP_PATH" 2>&1)
        CODE=$?
        if [ $CODE -ne 0 ]; then
            log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$ERR_UMOUNT_FAILED" "$STATUS")"
            exit 1
        else
            log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $MSG_UMOUNT_SUCCESS"
        fi
    fi
fi

# Start - Intelligent Re-Mounting
# Set defaults for new variables if not in config
MOUNT_RETRIES=${MOUNT_RETRIES:-2}
MOUNT_RETRY_DELAY_SECONDS=${MOUNT_RETRY_DELAY_SECONDS:-5}
CURRENT_ATTEMPT=0
MAX_ATTEMPTS=$((MOUNT_RETRIES + 1))
MOUNT_SUCCESS=0

# Mount NAS share (with UTF-8 support)
while [ $CURRENT_ATTEMPT -lt $MAX_ATTEMPTS ] && [ $MOUNT_SUCCESS -eq 0 ]; do
    CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))
    log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$MSG_ATTEMPT_MOUNT" "$CURRENT_ATTEMPT" "$MAX_ATTEMPTS")"

    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MOUNT" "$NAS_IP" "$NAS_SHARE" "$BACKUP_PATH")"
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MOUNT_OPTIONS" "$NAS_USER")"
        MOUNT_SUCCESS=1
    else
       
        
      # MODIFIED: Dynamic Mount Mode based on bmus.conf
        case "${NAS_MOUNT_MODE:-cifs_simple}" in
            
            "cifs_simple")
                # OLD METHOD: Good stats, but prone to errors with symlinks and timeouts
                # ADDED: mfsymlinks to fix copy errors in /etc/ (apache2/mysql symlinks)
                # ADDED: nobrl to prevent write errors due to locking conflicts on some kernels
                log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $MSG_MOUNT_MODE_SIMPLE"
                STATUS=$(sudo mount -t cifs "//$NAS_IP/$NAS_SHARE" "$BACKUP_PATH" -o username="$NAS_USER",password="$NAS_PASS",vers=3.0,iocharset=utf8,mfsymlinks,nobrl 2>&1)
                ;;
                
            "nfs")
                # NFS METHOD: Performance Optimized for Rsync
                # nfsvers=3:    Often faster and less overhead than v4 in LAN
                # async:        Allows asynchronous writing (performance boost)
                # noatime:      Do not write access times
                # actimeo=60:   Cache file attributes for 60s (important for rsync speed!)
                # rsize/wsize:  Maximum block size (1MB) for modern Gigabit
                # nolock:       Prevents file locking problems that can cause timeouts

                log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $MSG_MOUNT_MODE_NFS (Optimized)" 
                STATUS=$(sudo mount -t nfs "$NAS_IP:$NAS_SHARE_NFS" "$BACKUP_PATH" -o vers=3,proto=tcp,nolock,async,noatime,nodiratime,actimeo=600,lookupcache=all,rsize=131072,wsize=131072,timeo=600,retrans=2 2>&1)
                ;;
                
            *)
                # cifs_optimized - Bad (no) dedup stats, but slightly faster. Ino is calculated by the client, not by NAS. Shorter wait time.
                log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $MSG_MOUNT_MODE_OPT"
                STATUS=$(sudo mount -t cifs "//$NAS_IP/$NAS_SHARE" "$BACKUP_PATH" -o username="$NAS_USER",password="$NAS_PASS",vers=3.0,iocharset=utf8,mfsymlinks,nobrl,noserverino 2>&1)
                ;;
        esac
        
        CODE=$?
        
        if [ $CODE -ne 0 ]; then
            log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$ERR_MOUNT_FAILED" "$CURRENT_ATTEMPT" "$MAX_ATTEMPTS" "$STATUS")"
            if [ $CURRENT_ATTEMPT -lt $MAX_ATTEMPTS ]; then
                log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$MSG_RETRY_DELAY" "$MOUNT_RETRY_DELAY_SECONDS")"
                sleep "$MOUNT_RETRY_DELAY_SECONDS"
            fi
        else
            MOUNT_SUCCESS=1
        fi
    fi
done

if [ $MOUNT_SUCCESS -eq 0 ]; then
    log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$ERR_MOUNT_ABORT" "$MAX_ATTEMPTS")"
    exit 1
fi

log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$MSG_MOUNT_SUCCESS" "$BACKUP_PATH")"

# Set defaults for encrypted backup variables if not in config
ENCRYPTED_BACKUP_MAXDEPTH="${ENCRYPTED_BACKUP_MAXDEPTH:-2}"

# ===== [ Store original BACKUP_PATH for dashboard ] =====
# Store the original BACKUP_PATH before any modifications
# This ensures dashboard always goes to the root backup directory
DASHBOARD_BASE_PATH="$BACKUP_PATH"
# ===== [ END: Store original BACKUP_PATH for dashboard ] =====

# --- [ ENCRYPTION: Initialize and mount encrypted filesystem ] ---

if [ "$BACKUP_ENCRYPTION" -eq 1 ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_ENABLED"
    
    # Check prerequisites
    check_encryption_prerequisites
    if [ $? -ne 0 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_PREREQ_FAILED"
        exit 1
    fi
    
    # Show encryption status
    show_encryption_status
    
    # Set encryption directories
    ENCRYPTION_CIPHERTEXT_DIR="${ENCRYPTION_CIPHERTEXT_DIR:-$BACKUP_PATH/encrypted}"
    ENCRYPTION_PLAINTEXT_MOUNT="${ENCRYPTION_PLAINTEXT_MOUNT:-/mnt/backup_decrypted}"

    # --- DRY RUN CHECK ---
    if [ "$DRY_RUN" -eq 1 ]; then
        log_echo "[DRY-RUN] $MSG_DRY_RUN_ENC_MOUNT"
        # Simulate path change so the rest of the script uses the "virtual" decrypted path
        BACKUP_PATH=$(get_encrypted_backup_path "$ENCRYPTION_PLAINTEXT_MOUNT")
    else
        # --- REAL RUN ---
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_ENABLED"

        # Initialize if needed (first run)
        if [ ! -f "$ENCRYPTION_CIPHERTEXT_DIR/gocryptfs.conf" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_FIRST_RUN"
            init_encrypted_filesystem "$ENCRYPTION_CIPHERTEXT_DIR"
            if [ $? -ne 0 ]; then
                exit 1
            fi
        fi

        # Mount encrypted filesystem
        mount_encrypted_filesystem "$ENCRYPTION_CIPHERTEXT_DIR" "$ENCRYPTION_PLAINTEXT_MOUNT"
        if [ $? -ne 0 ]; then
            exit 1
        fi

        # REDIRECT all backup operations to plaintext mount
        NAS_MOUNT_PATH="$BACKUP_PATH"
        ORIGINAL_BACKUP_PATH="$BACKUP_PATH"
        
        # Get correct backup path (with or without date folder)
        BACKUP_PATH=$(get_encrypted_backup_path "$ENCRYPTION_PLAINTEXT_MOUNT")
        
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_AUTO_ENCRYPT"
        
        if [ "${ENCRYPTED_BACKUP_USE_DATE_FOLDERS:-0}" -eq 1 ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_LOG_DATE_FOLDER_ACTIVE" "$BACKUP_PATH")"
        fi
    fi
fi 
# --- [ END: Encryption mount ] ---

# ===== [ DEDUPLICATION - Setup ] =====
# Initialize deduplication if enabled
DEDUP_REFERENCE_DIR=""
DEDUP_BACKUP_DIR=""

if [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_LOG_ENABLED"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_ENABLED" "$DEDUP_STRATEGY")"
    
    # Test hardlink support
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_INFO_TESTING_HARDLINKS"
    if ! test_hardlink_support "$BACKUP_PATH"; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_ERR_NO_HARDLINK_SUPPORT"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_WARN_DISABLE_NO_HARDLINKS"
        DEDUP_ENABLE=0
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_STATUS_READY"
        
        # Store the base path BEFORE creating timestamped directory
        DEDUP_BASE_PATH="$BACKUP_PATH"
        
        # Find reference backup in the base path
        DEDUP_REFERENCE_DIR=$(find_reference_backup "$DEDUP_BASE_PATH")
       # Insert debugging logs
        #log_echo "[DEBUG] Reference dir: $DEDUP_REFERENCE_DIR"  # uncomment this for debugging
         #   if [ -n "$DEDUP_REFERENCE_DIR" ] && [ -d "$DEDUP_REFERENCE_DIR" ]; then # uncomment this for debugging
         #       log_echo "[DEBUG] Reference dir exists and is valid" # uncomment this for debugging
         #       else # uncomment this for debugging
         #       log_echo "[DEBUG] Reference dir does not exists and is invalid" # uncomment this for debugging
         #   fi # uncomment this for debugging


        if [ -n "$DEDUP_REFERENCE_DIR" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_REFERENCE_FOUND" "$(basename "$DEDUP_REFERENCE_DIR")")"
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_INFO_FIRST_BACKUP"
        fi
        
        # Create new timestamped backup directory
        DEDUP_BACKUP_DIR=$(create_dedup_backup_dir "$DEDUP_BASE_PATH")
        if [ -z "$DEDUP_BACKUP_DIR" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_ERR_BACKUP_DIR_CREATION_FAILED"
            DEDUP_ENABLE=0
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_BACKUP_DIR" "$(basename "$DEDUP_BACKUP_DIR")")"
            
            # Update BACKUP_PATH to the new timestamped directory
            BACKUP_PATH="$DEDUP_BACKUP_DIR"
            
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_TARGET_PATH" "$BACKUP_PATH")"
        fi
    fi
fi
# ===== [ END: DEDUPLICATION setup ] =====
 
# Global counters for backup statistics
COPY_ERRORS=0
TOTAL_BACKUP_BYTES=0
TOTAL_NEW_FILES=0
TOTAL_NEW_DIRS=0
VERIFY_ERRORS=0
DELETED_COUNT=0
CHANGED_FILES_LIST=""
DETAILED_FILE_LIST=""
DEDUP_SAVED_BYTES=0

# ===== [ UNIFIED RETENTION FOR UNENCRYPTED BACKUPS ] =====
# Delete old unencrypted backups (files AND folders based on structure)
DELETED_COUNT=0


# Determine correct backup path for retention
# Priority: 1. Original path (encryption), 2. Base path (deduplication), 3. Standard path
RETENTION_BACKUP_PATH="$BACKUP_PATH"
if [ "$BACKUP_ENCRYPTION" -eq 1 ] && [ -n "${ORIGINAL_BACKUP_PATH:-}" ]; then
    # For encrypted backups, clean up in the original (non-encrypted) path
    RETENTION_BACKUP_PATH="$ORIGINAL_BACKUP_PATH"
elif [ "${DEDUP_ENABLE:-0}" -eq 1 ] && [ -n "${DEDUP_BASE_PATH:-}" ]; then
    # For deduplication, clean up in the base path (not the current timestamped dir)
    RETENTION_BACKUP_PATH="$DEDUP_BASE_PATH"
fi

# ===== [ Count existing folders before retention for accurate chart ] =====
EXISTING_FOLDERS_UNENCRYPTED=0
if [ "${DEDUP_ENABLE:-0}" -eq 1 ] || [ "${BACKUP_USE_DATE_FOLDERS:-0}" -eq 1 ]; then
    # Count timestamped backup folders (YYYY-MM-DD_HH-MM-SS or YYYY-MM-DD)
    if [ "${DEDUP_ENABLE:-0}" -eq 1 ] && [ "${BACKUP_USE_DATE_FOLDERS:-0}" -eq 1 ]; then
        # Nested: Count timestamp folders inside date folders
        EXISTING_FOLDERS_UNENCRYPTED=$(find "$RETENTION_BACKUP_PATH" -mindepth 2 -maxdepth 2 -type d \
            -path "*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*" 2>/dev/null | wc -l)
    else
        # Date folders or flat timestamp folders
        EXISTING_FOLDERS_UNENCRYPTED=$(find "$RETENTION_BACKUP_PATH" -maxdepth 1 -type d \
            -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*" 2>/dev/null | wc -l)
    fi
else
    # Flat mode: count files as retention units
    FIND_EXPR=()
    for ext in "${BACKUP_FILETYPES[@]}"; do
        FIND_EXPR+=(-name "$ext" -o)
    done
    unset 'FIND_EXPR[-1]'
    EXISTING_FOLDERS_UNENCRYPTED=$(find "$RETENTION_BACKUP_PATH" -maxdepth "${BACKUP_MAXDEPTH:-1}" -type f \
        \( "${FIND_EXPR[@]}" \) 2>/dev/null | wc -l)
fi
# ===== [ END: Count existing folders ] =====

cleanup_old_unencrypted_backups "$RETENTION_BACKUP_PATH"

# =========================================================================
# CLEANUP ENCRYPTED BACKUPS (Even if Encryption is currently disabled)
# =========================================================================
# Define path explicitly
ENCRYPTION_CIPHERTEXT_DIR="${ENCRYPTION_CIPHERTEXT_DIR:-$RETENTION_BACKUP_PATH/encrypted}"
MAX_AGE_ENCRYPTED="${ENCRYPTED_BACKUP_AGE_DAYS:-0}"

# Condition: Folder exists AND Retention days are set (>0)
if [ -d "$ENCRYPTION_CIPHERTEXT_DIR" ] && [ "$MAX_AGE_ENCRYPTED" -gt 0 ]; then
    
    # ===== [ Count existing encrypted folders before retention ] =====
    EXISTING_FOLDERS_ENCRYPTED=0
    
    # Check if we should look for folders or files based on structure
    # We default to the current config settings
    if [ "${BACKUP_USE_DATE_FOLDERS:-0}" -eq 1 ]; then
        # FIX: "local" entfernt, da wir im globalen Scope sind
        find_pattern="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
        if [ "${READABLE_NAMES:-0}" -eq 0 ]; then
            find_pattern="*"  # All folders (encrypted names)
        fi
        
        if [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
            # Nested: Count timestamp folders inside date folders (Estimation)
            EXISTING_FOLDERS_ENCRYPTED=$(find "$ENCRYPTION_CIPHERTEXT_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | \
                grep -v "gocryptfs" | wc -l)
        else
            # Date folders only
            EXISTING_FOLDERS_ENCRYPTED=$(find "$ENCRYPTION_CIPHERTEXT_DIR" -maxdepth 1 -type d -name "$find_pattern" 2>/dev/null | \
                grep -v "gocryptfs" | wc -l)
        fi
    else
        # Flat: count encrypted files
        EXISTING_FOLDERS_ENCRYPTED=$(find "$ENCRYPTION_CIPHERTEXT_DIR" -maxdepth "${ENCRYPTED_BACKUP_MAXDEPTH:-2}" -type f 2>/dev/null | \
            grep -v "gocryptfs" | wc -l)
    fi
    # ===== [ END: Count existing encrypted folders ] =====
    
    # Call the cleanup function (which now has the correct date-parsing logic!)
    cleanup_old_encrypted_backups "$ENCRYPTION_CIPHERTEXT_DIR"
fi
log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $MSG_BACKUP_START"

# Backup MySQL databases (with single-transaction for InnoDB)
if [ "$BACKUP_SQL" -eq 1 ]; then
    for DB in "${MYSQL_DBS[@]}"; do
        OUTPUT_FILE="$BACKUP_PATH/$(date +%Y-%m-%d)-${DB}.sql"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SQL_DUMP_START" "$DB")"
        
        if [ $DRY_RUN -eq 1 ]; then
            log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_SQL_DUMP" "$OUTPUT_FILE")"
            log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_SQL_CMD" "$MYSQL_USER" "$DB")"
            
            # Estimate size based on a previus dump (if CALC_ALL=1)
            if [ "${CALC_ALL:-0}" -eq 1 ]; then
                PREV_DUMP=$(find "$BACKUP_PATH" -name "*-${DB}.sql" -type f -printf "%s" -quit 2>/dev/null || echo 0)
                if [ "$PREV_DUMP" -gt 0 ]; then
                    TOTAL_BACKUP_BYTES=$((TOTAL_BACKUP_BYTES + PREV_DUMP))
                    log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_SQL_SIZE" "$(numfmt --to=iec --suffix=B $PREV_DUMP)")"
                fi
            fi
        else
            # Attempt 1: With single-transaction
            STATUS=$(mysqldump --single-transaction -u "$MYSQL_USER" -p"$MYSQL_PASS" "$DB" > "$OUTPUT_FILE" 2>&1)
            CODE=$?
            
            if [ $CODE -ne 0 ]; then
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_SQL_DUMP_FAIL_1" "$DB" "$STATUS")"
                
                # Attempt 2: Without single-transaction (for MyISAM)
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_SQL_DUMP_NO_TX"
                STATUS=$(mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" "$DB" > "$OUTPUT_FILE" 2>&1)
                CODE=$?
                
                if [ $CODE -ne 0 ]; then
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_SQL_DUMP_FAIL_2" "$DB" "$STATUS")"
                else
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SQL_DUMP_NO_TX_SUCCESS" "$OUTPUT_FILE")"
                    if [ "${CALC_ALL:-0}" -eq 1 ]; then
                        FILE_SIZE_SQL=$(stat -c %s "$OUTPUT_FILE" 2>/dev/null || echo 0)
                        TOTAL_BACKUP_BYTES=$((TOTAL_BACKUP_BYTES + FILE_SIZE_SQL))
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SQL_DUMP_SIZE_ADDED" "$FILE_SIZE_SQL")"
                    fi
                fi
            else
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SQL_DUMP_SUCCESS" "$OUTPUT_FILE")"
                if [ "${CALC_ALL:-0}" -eq 1 ]; then
                    FILE_SIZE_SQL=$(stat -c %s "$OUTPUT_FILE" 2>/dev/null || echo 0)
                    TOTAL_BACKUP_BYTES=$((TOTAL_BACKUP_BYTES + FILE_SIZE_SQL))
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SQL_DUMP_SIZE_ADDED" "$FILE_SIZE_SQL")"
                fi
            fi                  
        fi
        # --- [ ENCRYPTION: Encrypt SQL dump with GPG if enabled ] ---
                
                if [ "$BACKUP_ENCRYPTION" -eq 1 ] && [ -n "${GPG_RECIPIENT:-}" ]; then
                     ENCRYPTED_FILE="${OUTPUT_FILE}.gpg"
                    encrypt_sql_dump "$OUTPUT_FILE" "$ENCRYPTED_FILE"
                    
                    if [ $? -eq 0 ]; then
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_SQL_ENCRYPTED"
                    fi
                fi
                # --- [ END: SQL encryption ] ---
    done
fi


# Function: Copy files/folders with rsync (with Root fallback on errors)
copy_with_retry() {
    local src="$1"
    local dest="$2"
    local temp_log="/tmp/bmus_rsync_output.tmp"

    if [ ! -e "$src" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$WARN_SRC_NOT_EXIST" "$src")"
        return
    fi

    local new_files=0
    local new_dirs=0
    # --numeric-ids: Prevent NFS user-mapping timeouts
    # --stats: Get internal rsync statistics for deduplication calculation
    local RSYNC_OPTIONS="-a --update -i --numeric-ids --stats"
    
    # -----------------------------------------------------------
    # INTELLIGENT MODE DETECTION (Based on Config)
    # -----------------------------------------------------------
    local BASE_OPTS="--itemize-changes --relative --no-specials --no-devices"
    local IS_NFS=0
    
    # PERFORMANCE FIX: We rely on the config variable instead of running 'stat' 
    # on the destination, which can cause timeouts on NFS.
    if [ "${NAS_MOUNT_MODE:-cifs_simple}" = "nfs" ]; then
        # NFS DETECTED!
        IS_NFS=1
        # Flags: --no-o --no-g --no-p prevents permission timeouts on NFS
        RSYNC_OPTIONS+=" $BASE_OPTS --no-o --no-g --no-p"
    else
        # SMB / LOCAL / CIFS
        # FIX FOR DEDUPLICATION AND ERRORS ON CIFS:
        # 1. --modify-window=2: Handles FAT/SMB timestamp precision (2s window required)
        # 2. --no-o --no-g --no-p: CRITICAL! SMB mounts usually enforce specific User/Group
        # 3. --copy-links: Turns symlinks into real files. Fixes symlink errors on SMB.
        # 4. --omit-dir-times: CRITICAL FIX! Prevents "Operation not permitted" errors when
        #    rsync tries to set modification times on SMB directories.
        RSYNC_OPTIONS+=" $BASE_OPTS --modify-window=2 --no-o --no-g --no-p --copy-links --omit-dir-times"
    fi
    
    # Add bandwidth limit
    if [ "${RSYNC_BANDWIDTH_LIMIT:-0}" -gt 0 ]; then
        RSYNC_OPTIONS+=" --bwlimit=$RSYNC_BANDWIDTH_LIMIT"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_BANDWIDTH_LIMIT" "$RSYNC_BANDWIDTH_LIMIT")"
    fi
    
    # In Dry-Run: add --dry-run
    if [ $DRY_RUN -eq 1 ]; then
        RSYNC_OPTIONS+=" --dry-run"
    fi

    # Exclude script itself and configured items
    SCRIPT_PATH="$(realpath "$0")"
    SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
    RSYNC_OPTIONS+=" --exclude=$SCRIPT_NAME"

    for item in "${EXCLUDE_ITEMS[@]}"; do
        RSYNC_OPTIONS+=" --exclude=$item"
    done
    
    # Check for .backupignore
    local EXCLUDE_FILE="$src/.backupignore"
    if [ -d "$src" ] && [ -f "$EXCLUDE_FILE" ]; then
        RSYNC_OPTIONS+=" --exclude-from=\"$EXCLUDE_FILE\""
         log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_RSYNC_USE_EXCLUDE" "$EXCLUDE_FILE")"
    fi
    
    # Deduplication Logic
    local dedup_active=0
    if [ "${DEDUP_ENABLE:-0}" -eq 1 ] && [ -n "$DEDUP_REFERENCE_DIR" ] && [ -n "$DEDUP_BACKUP_DIR" ] && [ -d "$DEDUP_REFERENCE_DIR" ]; then
        relpath="${dest#"$DEDUP_BACKUP_DIR"/}"
        if [ "$relpath" = "$dest" ]; then relpath="${dest#"$BACKUP_PATH"/}"; fi

        LINK_DEST="$DEDUP_REFERENCE_DIR"
        if [ -n "$relpath" ] && [ "$relpath" != "$dest" ]; then
            LINK_DEST="$DEDUP_REFERENCE_DIR/$relpath"
        fi

        if [ -d "$LINK_DEST" ]; then
            RSYNC_OPTIONS+=" --link-dest=$LINK_DEST"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_USING_REFERENCE" "$(basename "$LINK_DEST")")"
            dedup_active=1
        else
             log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_LINK_DEST_NOT_FOUND" "$LINK_DEST")"
        fi
    fi

    # Compression
    if [ "${RSYNC_COMPRESSION:-0}" -eq 1 ]; then 
        RSYNC_OPTIONS+=" -z"; 
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $NICE_RSYNC_COMPRESSION_ENABLED"
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $NICE_RSYNC_COMPRESSION_DISABLED"
    fi
    
    # -----------------------------------------------------------
    # EXECUTION STRATEGY
    # -----------------------------------------------------------
    NICE_LEVEL="${RSYNC_NICE:-19}"
    IONICE_CLASS="${RSYNC_IONICE:-3}"
    local CMD_PREFIX=""
    
    if [ "$IS_NFS" -eq 1 ]; then
        # NFS: RAW SPEED. No nice, no ionice.
        CMD_PREFIX="" 
    else
        # SMB/Local: Throttle
        CMD_PREFIX="nice -n $NICE_LEVEL ionice -c $IONICE_CLASS"
    fi

    # Execute Rsync to temp file
    # FIX: Correct order: LC_ALL=C must come BEFORE nice/ionice to prevent Error 127
    if [ -d "$src" ]; then
        if [ "$IS_NFS" -eq 1 ]; then
             LC_ALL=C rsync $RSYNC_OPTIONS "$src/" "$dest/" > "$temp_log" 2>&1
        else
             LC_ALL=C nice -n $NICE_LEVEL ionice -c $IONICE_CLASS rsync $RSYNC_OPTIONS "$src/" "$dest/" > "$temp_log" 2>&1
        fi
    else
        if [ "$IS_NFS" -eq 1 ]; then
             LC_ALL=C rsync $RSYNC_OPTIONS "$src" "$dest" > "$temp_log" 2>&1
        else
             LC_ALL=C nice -n $NICE_LEVEL ionice -c $IONICE_CLASS rsync $RSYNC_OPTIONS "$src" "$dest" > "$temp_log" 2>&1
        fi
    fi

    local CODE=$?
    local STATUS=$(cat "$temp_log")
    
    # ===== [ Parse Rsync Stats for accurate Deduplication Calculation ] =====
    # FIX: We parse stats regardless of Exit Code (if stats are present).
    if grep -q "Number of files:" "$temp_log"; then
        # Extract values using grep and awk.
        local run_files=$(grep "Number of files:" "$temp_log" | head -1 | awk -F': ' '{print $2}' | awk '{print $1}' | tr -cd '0-9')
        local run_xfer_files=$(grep "files transferred:" "$temp_log" | head -1 | awk -F': ' '{print $2}' | awk '{print $1}' | tr -cd '0-9')
        local run_size=$(grep "Total file size:" "$temp_log" | head -1 | awk -F': ' '{print $2}' | awk '{print $1}' | tr -cd '0-9')
        local run_xfer_size=$(grep "transferred file size:" "$temp_log" | head -1 | awk -F': ' '{print $2}' | awk '{print $1}' | tr -cd '0-9')
        
        # Add to global totals (default to 0)
        GLOBAL_RSYNC_TOTAL_FILES=$((GLOBAL_RSYNC_TOTAL_FILES + ${run_files:-0}))
        GLOBAL_RSYNC_TRANSFERRED_FILES=$((GLOBAL_RSYNC_TRANSFERRED_FILES + ${run_xfer_files:-0}))
        GLOBAL_RSYNC_TOTAL_SIZE=$((GLOBAL_RSYNC_TOTAL_SIZE + ${run_size:-0}))
        GLOBAL_RSYNC_TRANSFERRED_SIZE=$((GLOBAL_RSYNC_TRANSFERRED_SIZE + ${run_xfer_size:-0}))
    fi
    # ===== [ END: Parse Rsync Stats ] =====
    
    # Parse Output for Log
    while IFS= read -r line; do
        case "$line" in
            *d+++++++*)
                ((new_dirs++))
                DIR_PATH="${line##* }"
                CHANGED_FILES_LIST+="$(printf "$LOG_NEW_DIR" "$DIR_PATH")"$'\n'
                if [ "${WRITE_DETAILED_FILELOG:-0}" -eq 1 ]; then
                    FULL_DIR_PATH="$dest/$DIR_PATH"
                    DETAILED_FILE_LIST+="[DIR]  $FULL_DIR_PATH"$'\n'
                fi
                ;;
            *"+++++++++"*)
                ((new_files++))
                FILE_PATH="${line##* }"
                FULL_FILE_PATH="$dest/$FILE_PATH"
                
                # Check file size only if necessary (stat on NFS can be slow)
                if [ -f "$dest/$FILE_PATH" ]; then
                    # We only stat new files to log them
                    FILE_SIZE=$(stat -c %s "$dest/$FILE_PATH" 2>/dev/null || echo 0)
                    TOTAL_BACKUP_BYTES=$((TOTAL_BACKUP_BYTES + FILE_SIZE))
                    FILE_SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$FILE_SIZE")
                    CHANGED_FILES_LIST+="$(printf "$LOG_NEW_FILE" "$FILE_PATH" "$FILE_SIZE_HUMAN")"$'\n'
                fi
                ;;
            *"f.st"*)
                FILE_PATH="${line##* }"
                if [ -f "$dest/$FILE_PATH" ]; then
                    FILE_SIZE=$(stat -c %s "$dest/$FILE_PATH" 2>/dev/null || echo 0)
                    TOTAL_BACKUP_BYTES=$((TOTAL_BACKUP_BYTES + FILE_SIZE))
                    FILE_SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$FILE_SIZE")
                    CHANGED_FILES_LIST+="$(printf "$LOG_MOD_FILE" "$FILE_PATH" "$FILE_SIZE_HUMAN")"$'\n'
                fi
                ;;
        esac
    done <<< "$STATUS"
  
    TOTAL_NEW_FILES=$((TOTAL_NEW_FILES + new_files))
    TOTAL_NEW_DIRS=$((TOTAL_NEW_DIRS + new_dirs))
    
    rm -f "$temp_log"

    # On error: Retry
    if [ $CODE -ne 0 ] && [ $CODE -ne 23 ] && [ $CODE -ne 24 ]; then
        if [ $DRY_RUN -eq 0 ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$WARN_COPY_FAIL_RETRY" "$src")"
            
            # RETRY LOGIC (Simplified)
            # FIX: Correct order: LC_ALL=C must come BEFORE nice/ionice here too!
            if [ -d "$src" ]; then
                if [ "$IS_NFS" -eq 1 ]; then
                     LC_ALL=C rsync $RSYNC_OPTIONS "$src/" "$dest/" > "$temp_log" 2>&1
                else
                     LC_ALL=C nice -n $NICE_LEVEL ionice -c $IONICE_CLASS rsync $RSYNC_OPTIONS "$src/" "$dest/" > "$temp_log" 2>&1
                fi
            else
                if [ "$IS_NFS" -eq 1 ]; then
                     LC_ALL=C rsync $RSYNC_OPTIONS "$src" "$dest" > "$temp_log" 2>&1
                else
                     LC_ALL=C nice -n $NICE_LEVEL ionice -c $IONICE_CLASS rsync $RSYNC_OPTIONS "$src" "$dest" > "$temp_log" 2>&1
                fi
            fi
            
            CODE=$?
            STATUS=$(cat "$temp_log")
            rm -f "$temp_log"
            
            # Final Check
            if [ $CODE -ne 0 ] && [ $CODE -ne 23 ] && [ $CODE -ne 24 ]; then
                ((COPY_ERRORS++))
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_COPY_FAIL_ROOT" "$src") (Exit Code: $CODE)"
            else
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_RSYNC_SUCCESS" "$src")"
            fi
        fi
    else
       if [ $DRY_RUN -eq 1 ]; then
            log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_RSYNC_DONE" "$src" "$new_files" "$new_dirs")"
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_RSYNC_DONE" "$src" "$new_files" "$new_dirs")"         
        fi
    fi
}

# Iterate through backup sources (with wildcard support)
# ========== START: BATCH PROCESSING ==========
# Set defaults for batch variables if not in config

BATCH_SIZE="${BATCH_SIZE:-2}"
BATCH_PAUSE="${BATCH_PAUSE:-30}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-200}"

# Calculate total batches
TOTAL=${#BACKUP_SOURCES[@]}
TOTAL_BATCHES=$(( (TOTAL + BATCH_SIZE - 1) / BATCH_SIZE ))

# Display batch processing header
log_echo ""
log_echo "$BATCH_HEADER_LINE"
log_echo "$BATCH_HEADER_START"
log_echo "$(printf "$BATCH_INFO_TOTAL_SOURCES" "$TOTAL")"
log_echo "$(printf "$BATCH_INFO_BATCH_SIZE" "$BATCH_SIZE")"
log_echo "$(printf "$BATCH_INFO_PAUSE_DURATION" "$BATCH_PAUSE")"
log_echo "$(printf "$BATCH_INFO_RAM_THRESHOLD" "$MEMORY_THRESHOLD")"
log_echo "$BATCH_HEADER_LINE"
log_echo ""
# ========== END: BATCH PROCESSING HEADER ==========

# ===== [ NEW: Initialize dedup rate variable ] =====
# Initialize global variable for deduplication rate (used in history)
BACKUP_DEDUP_RATE="0.0"
# ===== [ END: Initialize dedup rate variable ] =====

# ===== [ NEW: Initialize deduplication logfile ] =====
# Create deduplication logfile if detailed logging is enabled
DEDUP_LOGFILE=""
if [ "${DEDUP_ENABLE:-0}" -eq 1 ] && [ "${DEDUP_DETAILED_LOG:-0}" -eq 1 ]; then
    DEDUP_LOGFILE="/tmp/$NAME_DEDUP_LOGFILE"
    > "$DEDUP_LOGFILE"  # Create empty file
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_DETAILED_LOG_START"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DETAILED_LOG_CREATED" "$DEDUP_LOGFILE")"
fi
# ===== [ END: Initialize deduplication logfile ] =====


# Iterate through backup sources (with batch processing)
COUNT=0

# ===== [ Initialize Global Rsync Stats ] =====
# We aggregate these values from each rsync run to calculate accurate
# deduplication stats without needing a slow 'find' command at the end.
GLOBAL_RSYNC_TOTAL_FILES=0
GLOBAL_RSYNC_TRANSFERRED_FILES=0
GLOBAL_RSYNC_TOTAL_SIZE=0
GLOBAL_RSYNC_TRANSFERRED_SIZE=0
# ===== [ END: Initialize Global Rsync Stats ] =====

for SRC in "${BACKUP_SOURCES[@]}"; do
    ((COUNT++))
    
    # ========== START: BATCH PAUSE LOGIC ==========
    # Calculate current batch number
    CURRENT_BATCH=$(( (COUNT - 1) / BATCH_SIZE + 1 ))
    BATCH_PROGRESS=$(( (COUNT - 1) % BATCH_SIZE + 1 ))
    
    # Pause between batches (if not first source and batch boundary reached)
    if [ $BATCH_PROGRESS -eq 1 ] && [ $COUNT -gt 1 ]; then
        log_echo ""
        log_echo "──────────────────────────────────────────────────────────────────"
        log_echo "  $(printf "$BATCH_COMPLETE" "$((CURRENT_BATCH - 1))")"
        log_echo "  $(printf "$BATCH_PAUSE_START" "$BATCH_PAUSE" "$CURRENT_BATCH")"
        log_echo "──────────────────────────────────────────────────────────────────"
        
        # RAM status before sync (no 'local' - we're not inside a function!)
        BATCH_RAM_BEFORE=$(free -m | awk 'NR==2{print $7}')
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$BATCH_RAM_BEFORE_SYNC" "$BATCH_RAM_BEFORE")"
        
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $BATCH_PAUSE_SYNC"
        sync
        
        # RAM status after sync
        BATCH_RAM_AFTER=$(free -m | awk 'NR==2{print $7}')
        BATCH_RAM_DIFF=$((BATCH_RAM_AFTER - BATCH_RAM_BEFORE))
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$BATCH_RAM_AFTER_SYNC" "$BATCH_RAM_AFTER" "$BATCH_RAM_DIFF")"
        
        sleep "$BATCH_PAUSE"
        wait_for_memory "$MEMORY_THRESHOLD"
        log_echo ""
    fi
    # ========== END: BATCH PAUSE LOGIC ==========
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$BATCH_SOURCE_PROGRESS" "$COUNT" "$TOTAL" "$CURRENT_BATCH")"

    FILES=($SRC)
    
    if [ ${#FILES[@]} -eq 0 ] && ! [ -e "$SRC" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_SRC_NOT_FOUND" "$SRC")"
        continue
    fi

    for ITEM in "${FILES[@]}"; do
        if [ ! -e "$ITEM" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_WILDCARD_NOT_FOUND" "$ITEM")"
            continue
        fi

        # MODIFIED: Always copy to root BACKUP_PATH. 
        # Rsync option --relative (set in copy_with_retry) will handle the directory tree creation.
        # e.g. /etc/snmp -> $BACKUP_PATH/etc/snmp
        DEST="$BACKUP_PATH"

        copy_with_retry "$ITEM" "$DEST"
    done
done

# ==========  BATCH PROCESSING SUMMARY ==========
log_echo ""
log_echo "$BATCH_HEADER_LINE"
log_echo "$BATCH_HEADER_DONE"
log_echo "$(printf "$BATCH_SUMMARY_COMPLETE" "$TOTAL" "$TOTAL_BATCHES")"
log_echo "$BATCH_HEADER_LINE"
log_echo ""

# ===== [ Fixed deduplication verification with any file type ] =====
# Calculate and log deduplication statistics
if [ "${DEDUP_ENABLE:-0}" -eq 1 ] && [ -n "$DEDUP_BACKUP_DIR" ]; then
    DEDUP_START=$(date +%s)
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_LOG_CALCULATING_STATS"
    
    # Verify hardlink functionality by testing a sample file
    if [ -n "$DEDUP_REFERENCE_DIR" ] && [ -d "$DEDUP_REFERENCE_DIR" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_DEBUG_VERIFY_HARDLINKS"
        
        # Find any file in the new backup (not limited to specific extensions)
        sample_file=$(find "$DEDUP_BACKUP_DIR" -type f -name "*" 2>/dev/null | head -n 1)
       
        if [ -n "$sample_file" ]; then
            sample_name=$(basename "$sample_file")
            ref_file=$(find "$DEDUP_REFERENCE_DIR" -type f -name "$sample_name" 2>/dev/null | head -n 1)
            
            if [ -n "$ref_file" ]; then
                new_links=$(stat -c %h "$sample_file" 2>/dev/null || echo 1)
                ref_links=$(stat -c %h "$ref_file" 2>/dev/null || echo 1)
                
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_SAMPLE_FILE" "$sample_name")"
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_NEW_LINKS" "$new_links")"
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DEBUG_REF_LINKS" "$ref_links")"
                
                if [ "$new_links" -gt 1 ]; then
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_SUCCESS_HARDLINK_VERIFIED"
                else
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_DEBUG_NO_HARDLINK_REASON"
                fi
            fi
        fi
    fi
    
    # Use the DEDUP_BACKUP_DIR (timestamped directory) for statistics
    calculate_dedup_stats "$DEDUP_BACKUP_DIR"
    
    DEDUP_END=$(date +%s)
    DEDUP_DURATION=$((DEDUP_END - DEDUP_START))
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_LOG_PERFORMANCE" "$(find "$DEDUP_BACKUP_DIR" -type f -links +1 2>/dev/null | wc -l)" "$DEDUP_DURATION")"
fi

# ===== [ END: DEDUPLICATION statistics ] =====

# =========================================================================
# === [Stop Resource Monitor ] ===
# =========================================================================
if [ -n "$RESOURCE_MONITOR_PID" ]; then
    # Kill the background process
    kill "$RESOURCE_MONITOR_PID" 2>/dev/null
    wait "$RESOURCE_MONITOR_PID" 2>/dev/null
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_STOP_RESSOURCE_MON"
fi
# =========================================================================


# Calculate backup statistics
BACKUP_SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$TOTAL_BACKUP_BYTES")
BACKUP_FILE_COUNT=$TOTAL_NEW_FILES
BACKUP_DIR_COUNT=$TOTAL_NEW_DIRS

END=$(date +%s)
DURATION=$((END-START))
DURATION_MIN=$(awk "BEGIN {printf \"%.2f\", $DURATION/60}")

# Log results
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_NEW_FILES_COUNT" "$BACKUP_FILE_COUNT")"
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_COPY_ERRORS_COUNT" "$COPY_ERRORS")"
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_NEW_DIRS_COUNT" "$BACKUP_DIR_COUNT")"
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_TOTAL_SIZE" "$BACKUP_SIZE_HUMAN")"
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_DURATION" "$DURATION" "$DURATION_MIN")"

# ===== [ Write detailed file log ] =====
if [ "${WRITE_DETAILED_FILELOG:-0}" -eq 1 ]; then
    # ---------------------------------------------------------------------
    # FIX: Ensure log is written to Base Path, not inside a nested Backup Folder
    # ---------------------------------------------------------------------
    
    # Get just the filename (e.g. bmus_file.log)
    log_filename=$(basename "$DETAILED_FILELOG_PATH")
    
    # Check if the configured path is somewhere inside the backup mount
    if [[ "$DETAILED_FILELOG_PATH" == "$DASHBOARD_BASE_PATH"* ]] || [[ "$DETAILED_FILELOG_PATH" == "$BACKUP_PATH"* ]]; then
        # Force it to the root of the mount to avoid saving it inside a daily backup folder
        RESOLVED_FILELOG_PATH="${DASHBOARD_BASE_PATH}/${log_filename}"
    else
        # If the user saved it somewhere else entirely (e.g. /home/pi/logs), keep it as is.
        RESOLVED_FILELOG_PATH="$DETAILED_FILELOG_PATH"
    fi
    
    log_echo ""
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $FILELOG_WRITE_START"
    
    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$FILELOG_DRY_RUN_WRITE" "$RESOLVED_FILELOG_PATH")"
        if [ -n "$DETAILED_FILE_LIST" ]; then
            FILELOG_COUNT=$(echo "$DETAILED_FILE_LIST" | wc -l)
            log_echo "[DRY-RUN] $(printf "$FILELOG_DRY_RUN_COUNT" "$FILELOG_COUNT")"
        fi
    else
        # Create detailed file log with header
        {
            echo "═══════════════════════════════════════════════════════════════"
            echo "$FILELOG_HEADER"
            echo "═══════════════════════════════════════════════════════════════"
            echo "$(printf "$FILELOG_SUBHEADER" "$(date '+%d.%m.%Y %H:%M:%S')")"
            echo "$(printf "$FILELOG_NAS_INFO" "$NAS_IP" "$BACKUP_PATH")"
            echo "$(printf "$FILELOG_MASTER_INFO" "$MASTER_IP")"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            
            if [ -n "$DETAILED_FILE_LIST" ]; then
                echo "$DETAILED_FILE_LIST"
            else
                echo "$FILELOG_NO_CHANGES"
            fi
            
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "$(printf "$FILELOG_FOOTER" "$BACKUP_FILE_COUNT" "$BACKUP_DIR_COUNT")"
            echo "═══════════════════════════════════════════════════════════════"
        } > "$RESOLVED_FILELOG_PATH"
        
        if [ $? -eq 0 ]; then
            FILELOG_SIZE=$(stat -c %s "$RESOLVED_FILELOG_PATH" 2>/dev/null || echo 0)
            FILELOG_SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$FILELOG_SIZE")
           
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$FILELOG_SUCCESS" "$RESOLVED_FILELOG_PATH" "$FILELOG_SIZE_HUMAN")"
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$FILELOG_ERROR" "$RESOLVED_FILELOG_PATH")"
        fi
    fi
fi
# ===== [ END: Write detailed file log ] =====

# Output differential backup info (Top X sorted by size / or defined limit)
if [ -n "$CHANGED_FILES_LIST" ]; then
    # regex adjusted to match language file variables (checking for generic prefixes)
    FILES_ONLY=$(echo -e "$CHANGED_FILES_LIST" | grep -E "^(✓|↻)")

    # Dynamic language detection (Works for DE, EN, ES, HE, FR, IT...)
    # We take the definition from the loaded .lang file ($LOG_NEW_DIR) and strip the "%s" placeholder.
    # grep -F searches for this exact fixed string, handling emojis and special chars correctly.
    DIR_SEARCH_PATTERN="${LOG_NEW_DIR%%%s*}"
    DIRS_ONLY=$(echo -e "$CHANGED_FILES_LIST" | grep -F "$DIR_SEARCH_PATTERN")
    
    # Set limit, if variable in bmus.conf is empty
    LIMIT_LOGS=${DASHBOARD_LINE_LOGS:-500}
    
    # Set limit, if variable in bmus.conf is empty
    LIMIT_LOGS="${DASHBOARD_LINE_NEW_DIRS:-20}"

    if [ -n "$FILES_ONLY" ]; then
        log_echo ""
        log_echo "═══════════════════════════════════════════════════════════"
        log_echo "$MSG_DIFF_HEADER"
        log_echo "═══════════════════════════════════════════════════════════"
                echo -e "$FILES_ONLY" | sort -t'(' -k2 -h -r | head -n "$LIMIT_LOGS" >> "$LOGFILE"
        log_echo ""
    fi
    
    log_echo "═══════════════════════════════════════════════════════════"
    log_echo "$MSG_NEW_DIRS_HEADER"
    log_echo "═══════════════════════════════════════════════════════════"
    if [ -n "$DIRS_ONLY" ]; then
    
        echo -e "$DIRS_ONLY" | head -n "$LIMIT_LOGS" >> "$LOGFILE"
    else
        log_echo "$MSG_NO_NEW_DIRS"
    fi
    log_echo "═══════════════════════════════════════════════════════════"
else
    log_echo ""
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_NO_CHANGES"
fi
# =========================================================================
# FUNCTIONS FOR NETWORK RESTART
# =========================================================================

# Find the name of the active network interface (Ethernet/WLAN)
# (Adjust the command to your Pi distribution if necessary)
get_net_interface() {
   # Try to find the default interface (eth0 or wlan0)
    # Example: the first interface with an IP address is taken:
    ip route | grep default | awk '{print $5}' | head -n 1
}

# Executes the restart of the interface
restart_network_interface() {
    INTERFACE=$(get_net_interface)
    if [ -n "$INTERFACE" ]; then
        
        # --- DRY RUN CHECK ---
        if [ "$DRY_RUN" -eq 1 ]; then
            log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_NET_RESET" "$INTERFACE")"
            return 0
        fi
        # ---------------------

        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$WARN_NET_IFACE_RESET" "$INTERFACE")"
        
        # Deactivate interface
        sudo ip link set dev "$INTERFACE" down
        sleep 5
        
        # Activate interface
        sudo ip link set dev "$INTERFACE" up
        
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_NET_IFACE_RESTARTED" "$INTERFACE")"
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_NET_IFACE_NOT_FOUND"
    fi
}

## Backup verification (checks integrity with rsync --dry-run)
if [ "${BACKUP_VERIFICATION}" -eq 1 ]; then
    log_echo ""
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_VERIFICATION_START"
    VERIFY_ERRORS=0
    
    # MAXIMUM DURATION in seconds before a timeout is triggered
    VERIFICATION_TIMEOUT=600 

    if [ "${DRY_RUN}" -eq 1 ]; then
        log_echo "[DRY-RUN] $MSG_DRY_RUN_VERIFY_SKIP"
    else
        for SRC in "${BACKUP_SOURCES[@]}"; do
            FILES=($SRC)
            for ITEM in "${FILES[@]}"; do
                [ -e "$ITEM" ] || continue
                
              # Always copy to root BACKUP_PATH.
              # Rsync option --relative (set in copy_with_retry) will handle the directory tree creation.
              # This ensures /etc/snmp lands in .../backup/etc/snmp instead of .../backup/snmp
              DEST="$BACKUP_PATH"

              copy_with_retry "$ITEM" "$DEST"
                
                # ----------------------------------------------------
                # TIMEOUT MONITORING WITH AUTOMATIC RETRY ON FREEZE
                # ----------------------------------------------------
                MAX_RETRY=3
                RETRY_COUNT=0
                
                while [ $RETRY_COUNT -lt $MAX_RETRY ]; do
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_VERIFY_START_ATTEMPT" "$ITEM" "$((RETRY_COUNT + 1))" "$MAX_RETRY")"
                    
                    # DISTINCTION: FILE OR DIRECTORY FOR RSYNC SYNTAX
                    if [ -d "$ITEM" ]; then
                        # It is a directory: Use slashes
                        timeout -s KILL $VERIFICATION_TIMEOUT nice -n "${RSYNC_NICE:-19}" ionice -c "${RSYNC_IONICE:-3}" \
                            rsync -avc --dry-run --bwlimit=1000 "$ITEM/" "$DEST/" > /dev/null 2>&1
                    else
                        # It is a file: Do NOT use slashes
                        timeout -s KILL $VERIFICATION_TIMEOUT nice -n "${RSYNC_NICE:-19}" ionice -c "${RSYNC_IONICE:-3}" \
                            rsync -avc --dry-run --bwlimit=1000 "$ITEM" "$DEST" > /dev/null 2>&1
                    fi
                    
                    RSYNC_EXIT_CODE=$?

                    if [ $RSYNC_EXIT_CODE -eq 124 ]; then
                        # Code 124 means the 'timeout' was triggered
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_VERIFY_TIMEOUT" "$VERIFICATION_TIMEOUT")"
                        restart_network_interface # Perform network reset
                        RETRY_COUNT=$((RETRY_COUNT + 1))
                        sleep 10 # Short pause before the next attempt
                    elif [ $RSYNC_EXIT_CODE -ne 0 ]; then
                        # Other errors (e.g. rsync error)
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_VERIFY_RSYNC_FAIL" "$RSYNC_EXIT_CODE")"
                        VERIFY_ERRORS=$((VERIFY_ERRORS + 1))
                        break # Verification failed, next item
                    else
                        # Success (Exit Code 0)
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_VERIFY_SUCCESS" "$ITEM")"
                        break 
                    fi
                done
                
                # If all attempts fail, the error count is incremented
                if [ $RETRY_COUNT -eq $MAX_RETRY ]; then
                    VERIFY_ERRORS=$((VERIFY_ERRORS + 1))
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_VERIFY_CRITICAL" "$MAX_RETRY")"
                fi
            done
        done
    fi
fi
# ===== [  BACKUP ALL BmuS SYSTEM FILES ] =====
# Secure versioned copies of all BmuS system files (optional via BACKUP_SCRIPT_ENABLE)
if [ "${BACKUP_SCRIPT_ENABLE:-1}" -eq 1 ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_SCRIPT_BACKUP_START"
    
    TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
    SCRIPT_BACKUP_COUNT=0
    SCRIPT_BACKUP_ERRORS=0
    
    # Iterate through all defined BmuS system files
    for SCRIPT_FILE in "${BACKUP_SCRIPT_FILES[@]}"; do
        if [ -f "$SCRIPT_FILE" ]; then
            SCRIPT_BASENAME="$(basename "$SCRIPT_FILE")"
            # Remove extension and add timestamp + .bak extension
            SCRIPT_NAME_NO_EXT="${SCRIPT_BASENAME%.*}"
            SCRIPT_EXT="${SCRIPT_BASENAME##*.}"
            
            # Special handling for hidden files (like .backup_credentials)
            if [[ "$SCRIPT_BASENAME" == .* ]]; then
                SCRIPT_BACKUP="$BACKUP_PATH/${SCRIPT_BASENAME}_${TIMESTAMP}.bak"
            else
                SCRIPT_BACKUP="$BACKUP_PATH/${SCRIPT_NAME_NO_EXT}_${TIMESTAMP}.${SCRIPT_EXT}.bak"
            fi
            
            if [ $DRY_RUN -eq 1 ]; then
                log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_SCRIPT_COPY" "$SCRIPT_BACKUP")"
                ((SCRIPT_BACKUP_COUNT++))
            else
                cp "$SCRIPT_FILE" "$SCRIPT_BACKUP" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SCRIPT_FILE_BACKED_UP" "$SCRIPT_BASENAME")"
                    ((SCRIPT_BACKUP_COUNT++))
                else
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_SCRIPT_FILE_COPY_FAIL" "$SCRIPT_BASENAME")"
                    ((SCRIPT_BACKUP_ERRORS++))
                fi
            fi
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$WARN_SCRIPT_FILE_NOT_FOUND" "$SCRIPT_FILE")"
        fi
    done
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_SCRIPT_BACKUP_SUMMARY" "$SCRIPT_BACKUP_COUNT" "$SCRIPT_BACKUP_ERRORS")"
fi
# ===== [ END: BACKUP ALL BmuS SYSTEM FILES ] =====

# Save backup history as CSV (for Dashboard graphs)
if [ "${BACKUP_HISTORY_ENABLE:-1}" -eq 1 ]; then
    HISTORY_FILE="$HISTORY_PATH"
    MAX_AGE_DAYS="${HISTORY_MAX_AGE_DAYS:-0}"

    # History rotation: Move old entries to a separate file
    if [ "$MAX_AGE_DAYS" -gt 0 ] && [ -f "$HISTORY_FILE" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_HISTORY_CHECK" "$MAX_AGE_DAYS")"
        
        LINES_TO_KEEP=$((MAX_AGE_DAYS + 1))
        TOTAL_LINES=$(wc -l < "$HISTORY_FILE")
        LINES_TO_ROTATE=$((TOTAL_LINES - LINES_TO_KEEP))

        if [ "$LINES_TO_ROTATE" -gt 0 ]; then
            TEMP_HISTORY_FILE="${HISTORY_FILE}.tmp"
            ROTATION_DATE=$(date '+%Y-%m-%d_%H-%M-%S')
            ROTATION_FILE="$BACKUP_PATH/backup-history_rotated_${ROTATION_DATE}.csv"
            
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_HISTORY_ROTATE_START" "$TOTAL_LINES" "$LINES_TO_KEEP")"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_HISTORY_ROTATE_LINES" "$LINES_TO_ROTATE")"
            
            # Create rotation file: Header + oldest records
            {
                head -n 1 "$HISTORY_FILE"
                head -n "$((LINES_TO_ROTATE + 1))" "$HISTORY_FILE" | tail -n +2
            } > "$ROTATION_FILE"
            
            # New History file: Header + newest entries
            tail -n "$LINES_TO_KEEP" "$HISTORY_FILE" > "$TEMP_HISTORY_FILE"
            mv "$TEMP_HISTORY_FILE" "$HISTORY_FILE" 2>/dev/null
            
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_HISTORY_ROTATED" "$LINES_TO_ROTATE" "$ROTATION_FILE")"
        fi
    fi
    
    # Create CSV header if file does not exist
    if [ ! -f "$HISTORY_FILE" ] && [ $DRY_RUN -eq 0 ]; then
       # ===== [ Added Dedup_Rate column ] =====
       echo "Date,Time,Duration_Sec,Size_Bytes,New_Files,New_Dirs,Copy_Errors,Verification_Errors,Deleted_Backups,Dedup_Rate,Status" > "$HISTORY_FILE"
       # ===== [ END: Modified CSV header ] =====
       log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_HISTORY_CREATED" "$HISTORY_FILE")"
    fi

   # Determine status
    COPY_ERRORS=${COPY_ERRORS:-0}
    VERIFY_ERRORS=${VERIFY_ERRORS:-0}

     # Status is Error, if copy errors OR (verification = 1 AND verification errors > 0)
    if [ "${COPY_ERRORS}" -gt 0 ]; then
        BACKUP_STATUS="Error"
        elif [ "${BACKUP_VERIFICATION}" -eq 1 ] && [ "${VERIFY_ERRORS}" -gt 0 ]; then
        BACKUP_STATUS="Error"
        else
        BACKUP_STATUS="Success"
    fi
    
    
    # Add new entry
   # ===== [ Add dedup rate to history entry ] =====
    # Add new entry with deduplication rate
    # Use 0.0 as default if deduplication is disabled or no rate was calculated
    dedup_rate="${BACKUP_DEDUP_RATE:-0.0}"
    HISTORY_ENTRY="$(date '+%Y-%m-%d'),$(date '+%H:%M:%S'),$DURATION,$TOTAL_BACKUP_BYTES,$BACKUP_FILE_COUNT,$BACKUP_DIR_COUNT,$COPY_ERRORS,$VERIFY_ERRORS,$DELETED_COUNT,$dedup_rate,$BACKUP_STATUS"
    # ===== [ END: Modified history entry ] =====
    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_HISTORY_ADD" "$HISTORY_ENTRY")"
    else
        echo "$HISTORY_ENTRY" >> "$HISTORY_FILE"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_HISTORY_ADDED"
        # ===== [ NEW: Log dedup rate ] =====
        if [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_LOG_RATE_SAVED" "$dedup_rate")"
        fi
        # ===== [ END: Log dedup rate ] =====
    fi
else
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_HISTORY_DISABLED"
fi

# Write all data to NAS (important before unmount)
if [ $DRY_RUN -eq 0 ]; then
    sync
fi


# ===== [ Fixed dashboard target path ] =====
# Generate dashboard (external script, optional via DASHBOARD_ENABLE)
DASHBOARD_GEN="${DASHBOARD_GENERATOR}"
OUTPUT_HTML="/tmp/backup_dashboard_$(date '+%Y-%m-%d_%H-%M-%S').html"
ZIPFILE_TMP_HTML="$OUTPUT_HTML"

TOTAL_DELETED_COUNT=$((DELETED_COUNT + DELETED_COUNT_ENCR))

# Dashboard ALWAYS goes to the original base path (not timestamped directory)
# Use DASHBOARD_BASE_PATH which was saved before any path modifications
DASHBOARD_TARGET_PATH="$DASHBOARD_BASE_PATH"

# For dashboard generation display, show appropriate path
DASHBOARD_DISPLAY_PATH="$DASHBOARD_BASE_PATH"
if [ "$BACKUP_ENCRYPTION" -eq 1 ]; then
    # Show encrypted path for info
    DASHBOARD_DISPLAY_PATH="${ENCRYPTION_CIPHERTEXT_DIR}"
fi

if [ "${DASHBOARD_ENABLE:-0}" -eq 1 ]; then
    if [ -f "$DASHBOARD_GEN" ]; then
        source "$DASHBOARD_GEN"
        if type generate_dashboard &>/dev/null; then
            if [ $DRY_RUN -eq 1 ]; then
                log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_DASHBOARD_GEN" "$OUTPUT_HTML")"
                log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_DASHBOARD_COPY" "$DASHBOARD_TARGET_PATH/$DASHBOARD_FILENAME")"
            else
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_DASHBOARD_GEN_START" "$OUTPUT_HTML")"
                   
               # ===== [ Pass folder counts for accurate retention chart ] =====
                # Calculate total existing folders (before deletion)
                TOTAL_EXISTING_FOLDERS=$((EXISTING_FOLDERS_UNENCRYPTED + EXISTING_FOLDERS_ENCRYPTED))
                KEPT_FOLDERS=$((TOTAL_EXISTING_FOLDERS - DELETED_FOLDERS))
                # Calculate Total RAM in MB for dashboard visualization
                RAM_TOTAL_MB=$(free -m | awk 'NR==2{print $2}')
                # --- [ Transform Bytes to readable format ] ---
                DEDUP_SAVED_HUMAN=$(numfmt --to=iec --suffix=B "$DEDUP_SAVED_BYTES")

                # --- [ Calc add. stats for dashboard ] ---
                # Initial values
                AVG_DURATION_HUMAN="0s"
                SUCCESS_RATE_DISPLAY="0%"
                MAX_SPIKE_HUMAN="0 B"

                if [ -f "$HISTORY_PATH" ]; then
                   # We look at the last 30 entries (tail -n 30), but skip the header (tail -n +2)
                   # Columns in CSV: 3=Duration, 4=Size, 11=Status
                    
                    # 1. Calculate average duration
                    AVG_DURATION_S=$(tail -n +2 "$HISTORY_PATH" | tail -n 30 | awk -F',' '{sum+=$3; cnt++} END {if(cnt>0) printf "%.0f", sum/cnt; else print 0}')
                    AVG_DURATION_HUMAN="${AVG_DURATION_S}s"

                    # 2. Calculate success rate
                    TOTAL_30=$(tail -n +2 "$HISTORY_PATH" | tail -n 30 | wc -l)
                    SUCCESS_30=$(tail -n +2 "$HISTORY_PATH" | tail -n 30 | grep -i ",Success" | wc -l)
                    if [ "$TOTAL_30" -gt 0 ]; then
                        SUCCESS_RATE_PCT=$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_30 / $TOTAL_30) * 100}")
                        SUCCESS_RATE_DISPLAY="${SUCCESS_RATE_PCT}%"
                    fi

                    # 3. Max Spike (Largest backup in the last 30 days
                    MAX_SPIKE_BYTES=$(tail -n +2 "$HISTORY_PATH" | tail -n 30 | awk -F',' 'BEGIN{max=0} {if($4>max) max=$4} END {print max}')
                    MAX_SPIKE_HUMAN=$(numfmt --to=iec --suffix=B "$MAX_SPIKE_BYTES")
                fi
                
                
                generate_dashboard "$OUTPUT_HTML" "$BACKUP_SIZE_HUMAN" "$BACKUP_FILE_COUNT" "$BACKUP_DIR_COUNT" "$DASHBOARD_DISPLAY_PATH" "$NAS_IP" "$MASTER_IP" "$TOTAL_DELETED_COUNT" "$COPY_ERRORS" "$VERIFY_ERRORS" "$START" "$END" "$DURATION" "$LOGFILE" "$DEDUP_LOGFILE" "$DELETED_FOLDERS" "$KEPT_FOLDERS" "$RESOURCE_LOGFILE" "$RAM_TOTAL_MB" "$DEDUP_SAVED_HUMAN" "$AVG_DURATION_HUMAN" "$SUCCESS_RATE_DISPLAY" "$MAX_SPIKE_HUMAN" "${DASHBOARD_LINE_NEW_DIRS:-100}" "$TOTAL_BACKUP_BYTES"
                # ===== [ End Dashboard call ] =====
                
                
                DASHBOARD_CODE=$?
                
                if [ $DASHBOARD_CODE -ne 0 ]; then
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_DASHBOARD_FAIL"
                    unset OUTPUT_HTML
                else
                    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_DASHBOARD_GENERATED" "$OUTPUT_HTML")"
                    
                    # Copy dashboard to base path (always /mnt/workstation or equivalent)
                    DASHBOARD_TARGET_PATH="$DASHBOARD_BASE_PATH"  # Always /mnt/workstation
                    cp "$OUTPUT_HTML" "$DASHBOARD_TARGET_PATH/$DASHBOARD_FILENAME"
                    
                    if [ $? -eq 0 ]; then
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_DASHBOARD_SAVED" "$DASHBOARD_TARGET_PATH/$DASHBOARD_FILENAME")"
                        
                        if [ -n "$WEBDAV_PORT" ]; then
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_DASHBOARD_ACCESS" "$NAS_IP" "$WEBDAV_PORT" "$NAS_SHARE" "$DASHBOARD_FILENAME")"
                        else
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_WEBDAV_PORT_MISSING"
                        fi
                        # ===== [ NEW: Copy dedup logfile to NAS if exists ] =====
                    # Copy deduplication logfile to dashboard location
                    if [ -n "$DEDUP_LOGFILE" ] && [ -f "$DEDUP_LOGFILE" ]; then
                       dedup_log_name="$NAME_DEDUP_LOGFILE"
                        cp "$DEDUP_LOGFILE" "$DASHBOARD_TARGET_PATH/$dedup_log_name"
                        if [ $? -eq 0 ]; then
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_DETAILED_LOG_CREATED" "$DASHBOARD_TARGET_PATH/$dedup_log_name")"
                            
                            # Count logged files
                            logged_count=$(wc -l < "$DEDUP_LOGFILE")
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$DEDUP_INFO_LOGGED_FILES" "$logged_count")"
                        else
                            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $DEDUP_ERR_LOG_CREATION_FAILED"
                        fi
                    fi
                    else
                        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_DASHBOARD_NAS_FAIL"
                    fi
                fi
            fi
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_DASHBOARD_FUNC_MISSING_FINAL" "$DASHBOARD_GEN")"
        fi
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_DASHBOARD_NOT_FOUND_FINAL" "$DASHBOARD_GEN")"
    fi
fi
# ===== [ END: Fixed dashboard target path ] =====
# Create ZIP archive for mail delivery
ZIPFILE="/tmp/backup_log_$(date +%Y%m%d_%H%M%S).zip"
ZIPFILE_TMP_LOG="$ZIPFILE"

if [ $DRY_RUN -eq 0 ]; then
    zip -j -q "$ZIPFILE" "$LOGFILE"
    
    if [ -f "$OUTPUT_HTML" ]; then
        zip -j -q "$ZIPFILE" "$OUTPUT_HTML"
    fi
    
    if [ ! -f "$ZIPFILE" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_ZIP_FAIL" "$ZIPFILE")"
    fi
    
    # Synchronize all data to NAS (before unmount)
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_SYNC_NAS_START"
    sync
    sleep 2
fi

# Check routine for required commands (zip, msmtp)
check_command() {
    local cmd="$1"
    local pkg="$2"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_CHECK_CMD_MAIL" "$cmd")"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_MISSING_CMD_MAIL" "$cmd")"
        if [ -n "$pkg" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ERR_MISSING_CMD_PKG_MAIL" "$pkg")"
        fi
        exit 1
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_CMD_FOUND_MAIL" "$cmd")"
    fi
}

if [ "$SEND_MAIL" -eq 1 ]; then
    check_command "zip" "zip"
    check_command "msmtp" "msmtp"
fi

# Mail delivery with msmtp (with MIME attachments)
if [ "${SEND_MAIL:-0}" -eq 1 ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_MAIL_SEND_START" "$EMAIL")"
    
    SCRIPT_NAME=$(basename "$0" .sh)
    ZIPFILE="/tmp/${SCRIPT_NAME}_$(date '+%d.%m.%Y_%H-%M-%S').zip"
    ZIPFILE_TMP_ZIP="$ZIPFILE"
    
    if [ $DRY_RUN -eq 1 ]; then
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MAIL_ZIP" "$ZIPFILE")"
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MAIL_SEND" "$EMAIL")"
        log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MAIL_SUBJECT" "$EMAIL_SUBJECT")"
        if [ -n "$OUTPUT_HTML" ]; then
            log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_MAIL_ATTACH" "$OUTPUT_HTML")"
        fi
    else
        /usr/bin/zip -j "$ZIPFILE" "$LOGFILE"
        ZIP_CODE=$?

        if [ $ZIP_CODE -ne 0 ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_LOG_ZIP_FAILED"
        else
            # Prepare HTML file name
            HTML_NAME=""
            if [ -n "$OUTPUT_HTML" ] && [ -f "$OUTPUT_HTML" ]; then
                HTML_NAME=$(basename "$OUTPUT_HTML")
            fi

            # Prepare dynamic text
            ATTACHMENTS="$MAIL_ATTACH_LOG"
            DASHBOARD_TEXT=""

            if [ "$DASHBOARD_ENABLE" = "1" ]; then
                ATTACHMENTS="$ATTACHMENTS"$'\n'"$MAIL_ATTACH_DASH"
                if [ -n "$WEBDAV_PORT" ]; then
                    DASHBOARD_TEXT=$(cat <<-LINK

$MAIL_DASH_ACCESS_HEADER

http://$NAS_IP:$WEBDAV_PORT/$NAS_SHARE/$DASHBOARD_FILENAME


$MAIL_DASH_HINT
LINK
)
                fi
            fi
            
            # Send mail with attachments (MIME multipart)
            sudo -u $PI_USER env HOME=$HOME_PI PATH=/usr/bin:/bin /usr/bin/msmtp --from="$EMAIL" "$EMAIL" <<MAIL
Subject: $EMAIL_SUBJECT
To: $EMAIL
From: $EMAIL
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: 7bit

$(printf "$MAIL_BODY_HEADER" "$NAS_IP")

$(printf "%s" "$ATTACHMENTS")

$(printf "%s" "$DASHBOARD_TEXT")

--BOUNDARY
Content-Type: application/zip; name="$(basename "$ZIPFILE")"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$(basename "$ZIPFILE")"

$(base64 "$ZIPFILE")

$(if [ -n "$HTML_NAME" ]; then
cat <<HTML
--BOUNDARY
Content-Type: text/html; name="$HTML_NAME"; charset="utf-8"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$HTML_NAME"

$(base64 "$OUTPUT_HTML")
HTML
fi)

--BOUNDARY--
MAIL

            CODE=$?
            if [ $CODE -ne 0 ]; then
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ERR_MAIL_SEND_FAIL"
            else
                log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_MAIL_SEND_SUCCESS" "$EMAIL")"
            fi
        fi
    fi
else
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $MSG_MAIL_ZIP_SKIP"
fi

# Clean up temporary files
if [ $DRY_RUN -eq 0 ]; then
    if [ -f "$ZIPFILE_TMP_ZIP" ]; then
        rm -f "$ZIPFILE_TMP_ZIP"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_TMP_ZIP_DEL" "$ZIPFILE_TMP_ZIP")"
    fi
    if [ -f "$ZIPFILE_TMP_HTML" ]; then
        rm -f "$ZIPFILE_TMP_HTML"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_TMP_DASH_DEL" "$ZIPFILE_TMP_HTML")"
    fi
    # ===== [ Cleanup dedup logfile ] =====
    # Remove temporary deduplication logfile
    if [ -n "$DEDUP_LOGFILE" ] && [ -f "$DEDUP_LOGFILE" ]; then
        # DISABLED CLEANUP: Keep logfile on NAS for review
        # rm -f "$DEDUP_LOGFILE"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$MSG_TMP_DEDUP_DEL" "$DEDUP_LOGFILE")"
    fi
    # ===== [ END: Cleanup dedup logfile ] =====
fi

    # ===== [ Copy Main Logfile to NAS ] =====
    # Copy the current logfile to the NAS root directory (mirroring local behavior).
    # This ensures bmus.log exists on both the Pi and the NAS.
if [ $DRY_RUN -eq 0 ] && [ -f "$LOGFILE" ]; then
    # We use DASHBOARD_BASE_PATH to ensure it goes to the root mount point,
    # and not inside a specific timestamped backup folder (if dedup is active).
    TARGET_LOG_PATH="${DASHBOARD_BASE_PATH:-$BACKUP_PATH}/bmus.log"
    
    cp "$LOGFILE" "$TARGET_LOG_PATH"
    # We do not log this action to the file itself to keep source and dest identical
fi
# ===== [ END: Copy Main Logfile to NAS ] =====

    # =========================================================================
    # === [ Cleanup Resource Log ] ===
    # =========================================================================
    if [ -f "$RESOURCE_LOGFILE" ]; then
        rm -f "$RESOURCE_LOGFILE"
        # Optional: log cleanup, kept silent to avoid log clutter
    fi

# --- [ ENCRYPTION: Unmount encrypted filesystem ] ---
if [ "$BACKUP_ENCRYPTION" -eq 1 ]; then
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_FINALIZING"
    umount_encrypted_filesystem "$ENCRYPTION_PLAINTEXT_MOUNT"
    BACKUP_PATH="$ORIGINAL_BACKUP_PATH"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_LOG_SECURED"
fi
# --- [ END: Encryption unmount ] ---

# Unmount NAS share - Intelligent path determination
# Determine correct path for unmounting based on enabled features
if [ "$BACKUP_ENCRYPTION" -eq 1 ]; then
    # If encryption is enabled, unmount the original NAS mount point
    UNMOUNT_PATH="${NAS_MOUNT_PATH}"
elif [ "${DEDUP_ENABLE:-0}" -eq 1 ]; then
    # If deduplication is enabled, use the base path (not the timestamped dir)
    UNMOUNT_PATH="${DEDUP_BASE_PATH:-$DASHBOARD_BASE_PATH}"
else
    # Otherwise use the base path
    UNMOUNT_PATH="$DASHBOARD_BASE_PATH"
fi

if [ $DRY_RUN -eq 1 ]; then
    log_echo "[DRY-RUN] $(printf "$MSG_DRY_RUN_UMOUNT_FINAL" "$UNMOUNT_PATH")"
else
    STATUS=$(sudo umount "$UNMOUNT_PATH" 2>&1)
    CODE=$?
    if [ $CODE -ne 0 ]; then
        log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$ERR_UMOUNT_FINAL_FAIL" "$UNMOUNT_PATH" "$STATUS")"
    else
        log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $(printf "$MSG_UMOUNT_SUCCESS_FINAL" "$UNMOUNT_PATH")"
    fi
fi

log_echo "[$(date "+%d.%m.%Y %H:%M:%S")] - $MSG_BACKUP_END"

exit 0