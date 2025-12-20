#!/bin/bash

# =========================================================================
# Encryption Functions for BmuS v.24.3
# =========================================================================
# This file provides encryption functionality using gocryptfs
# All user-facing messages use variables from language files
# =========================================================================

# =========================================================================
# FUNCTION: check_encryption_prerequisites
# Check if gocryptfs is installed and password file exists
# =========================================================================
check_encryption_prerequisites() {
    if [ "$ENCRYPTION_METHOD" = "gocryptfs" ]; then
        # Check if gocryptfs is installed
        if ! command -v gocryptfs >/dev/null 2>&1; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_GOCRYPTFS_NOT_INSTALLED"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_INSTALL_GOCRYPTFS"
            return 1
        fi
        
        # Check if password file exists
        if [ ! -f "$ENCRYPTION_PASSWORD_FILE" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_ERR_PASSWORD_FILE_NOT_FOUND" "$ENCRYPTION_PASSWORD_FILE")"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_CREATE_PASSWORD_FILE"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_ERR_CHMOD_PASSWORD_FILE" "$ENCRYPTION_PASSWORD_FILE")"
            return 1
        fi
        
        # Check password file permissions
        PERMS=$(stat -c %a "$ENCRYPTION_PASSWORD_FILE" 2>/dev/null)
        if [ "$PERMS" != "600" ]; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_WARN_PASSWORD_FILE_PERMS" "$PERMS")"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_WARN_FIX_PERMS" "$ENCRYPTION_PASSWORD_FILE")"
        fi
    fi
    
    return 0
}

# =========================================================================
# FUNCTION: init_encrypted_filesystem
# Initialize a new encrypted filesystem (only needed once)
# =========================================================================
init_encrypted_filesystem() {
    local cipher_dir="$1"
    
    # Check if already initialized
    if [ -f "$cipher_dir/gocryptfs.conf" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_INFO_ALREADY_INITIALIZED"
        return 0
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_INITIALIZING" "$cipher_dir")"
    
    # Create cipher directory
    mkdir -p "$cipher_dir"
    
    # Define gocryptfs initialization options
    GOCRYPTFS_INIT_OPTIONS=""
    
    # Check if readable names are desired (READABLE_NAMES=1)
    if [ "${READABLE_NAMES:-0}" -eq 1 ]; then
        GOCRYPTFS_INIT_OPTIONS="-plaintextnames"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_WARN_PLAINTEXT_NAMES_ENABLED" # Warning in Log
    fi
    
    # Initialize with password from file and the defined options
    # The -q (quiet) option remains active
    cat "$ENCRYPTION_PASSWORD_FILE" | tr -d '\n\r' | gocryptfs -init -q $GOCRYPTFS_INIT_OPTIONS "$cipher_dir"
    
    
    
    if [ $? -eq 0 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_SUCCESS_INITIALIZED"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_WARN_BACKUP_MASTER_KEY"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_MASTER_KEY_LOCATION" "$cipher_dir/gocryptfs.conf")"
        return 0
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_INIT_FAILED"
        return 1
    fi
}
# =========================================================================
# FUNCTION: mount_encrypted_filesystem
# Mount an encrypted filesystem to a plaintext mount point
# =========================================================================
mount_encrypted_filesystem() {
    local cipher_dir="$1"
    local plain_dir="$2"
    
    # ===== [ FIX: Sync READABLE_NAMES with GOCRYPTFS_PLAINTEXTNAMES ] =====
    # If READABLE_NAMES is enabled, force plaintextnames for mount
    #if [ "${READABLE_NAMES:-0}" -eq 1 ]; then
    #    GOCRYPTFS_PLAINTEXTNAMES=1
    #fi
    # ===== [ END: Sync ] =====

    # Check if already mounted
    if mountpoint -q "$plain_dir" 2>/dev/null; then
        # Verifiziere, dass es wirklich ein gocryptfs-Mount ist
        if mount | grep -q "gocryptfs.*$plain_dir"; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_ALREADY_MOUNTED" "$plain_dir")"
            return 0
        else
            # Mount-Point exists, but it is not gocryptfs → Unmount
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_WARN_NOT_GOCRYPTFS_MOUNT" "$plain_dir")"
            sudo umount "$plain_dir" 2>/dev/null || true
            
            # Cleanup: Delete content of folder
            if [ -d "$plain_dir" ]; then
                sudo rm -rf "${plain_dir:?}"/* 2>/dev/null || true
            fi
        fi
    fi
    
    # Create plaintext mount point
    if [ ! -d "$plain_dir" ]; then
        mkdir -p "$plain_dir"
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_CREATED_MOUNTPOINT" "$plain_dir")"
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_INFO_MOUNTING"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_CIPHERTEXT" "$cipher_dir")"
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_PLAINTEXT" "$plain_dir")"
    
    # Build gocryptfs options
    #GOCRYPTFS_OPTIONS=""
    #if [ "$GOCRYPTFS_PLAINTEXTNAMES" -eq 1 ]; then
    #    GOCRYPTFS_OPTIONS+=" -plaintextnames"
    #fi

    if [ "${READABLE_NAMES:-0}" -eq 1 ]; then
        GOCRYPTFS_OPTIONS+=" -plaintextnames"
    fi

    # Check gocryptfs version
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_INFO_VERSION_CHECK"
    GOCRYPTFS_VERSION=$(gocryptfs --version 2>&1 | grep -oP 'gocryptfs \K[0-9]+\.[0-9]+' | head -n1)
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_VERSION_DETECTED" "$GOCRYPTFS_VERSION")"

    if [ "$GOCRYPTFS_LONGNAMEMAX" -gt 0 ]; then
        if command -v bc >/dev/null 2>&1; then
            VERSION_OK=$(echo "$GOCRYPTFS_VERSION >= 2.0" | bc -l 2>/dev/null)
        else
            MAJOR_VERSION=$(echo "$GOCRYPTFS_VERSION" | cut -d. -f1)
            if [ "$MAJOR_VERSION" -ge 2 ]; then
                VERSION_OK=1
            else
                VERSION_OK=0
            fi
        fi
        
        if [ "$VERSION_OK" = "1" ]; then
            GOCRYPTFS_OPTIONS+=" -longnamemax $GOCRYPTFS_LONGNAMEMAX"
        else
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_WARN_LONGNAMEMAX_VERSION" "$GOCRYPTFS_VERSION")"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_INFO_LONGNAMEMAX_DISABLED"
        fi
    fi
    
# Mount with password from file
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_INFO_MOUNT_PROCESS_START"

cat "$ENCRYPTION_PASSWORD_FILE" | tr -d '\n\r' | \
    gocryptfs $GOCRYPTFS_OPTIONS "$cipher_dir" "$plain_dir" >> "$LOGFILE" 2>&1 &

local gocryptfs_pid=$!
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_GOCRYPTFS_PID" "$gocryptfs_pid")"

# Wait for mount
local max_wait=10
local waited=0

while [ $waited -lt $max_wait ]; do
    sleep 1
    ((waited++))
    
    # Search for "plain_dir" AND "gocryptfs"
    if mountpoint -q "$plain_dir" 2>/dev/null; then
        if mount | grep "$plain_dir" | grep -q "gocryptfs"; then
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_SUCCESS_MOUNTED"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_MOUNT_VERIFY_SUCCESS" "$waited")"
            return 0
        fi
    fi
done

# Mount failed after timeout
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_MOUNT_SUCCESS_BUT_INACTIVE"

# Debug informations
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_DEBUG_HEADER"
log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_DEBUG_MOUNT_STATUS"
mount | grep -E "(backup|gocryptfs)" >> "$LOGFILE" 2>&1 || echo "$ENC_DEBUG_NO_MOUNT_FOUND" >> "$LOGFILE"

log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_DEBUG_GOCRYPTFS_PROCESSES"
ps aux | grep "[g]ocryptfs" >> "$LOGFILE" 2>&1 || echo "$ENC_DEBUG_NO_PROCESS_FOUND" >> "$LOGFILE"

log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_DEBUG_MOUNTPOINT_TEST"
mountpoint "$plain_dir" >> "$LOGFILE" 2>&1

log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_DEBUG_DIR_CONTENT"
ls -la "$plain_dir" >> "$LOGFILE" 2>&1 || echo "$ENC_DEBUG_DIR_NOT_READABLE" >> "$LOGFILE"

log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_DEBUG_END"

return 1
}

# =========================================================================
# FUNCTION: umount_encrypted_filesystem
# Unmount an encrypted filesystem
# =========================================================================
umount_encrypted_filesystem() {
    local plain_dir="$1"
    
    # Check if mounted
    if ! mountpoint -q "$plain_dir" 2>/dev/null; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_NOT_MOUNTED" "$plain_dir")"
        return 0
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_UNMOUNTING" "$plain_dir")"
    
    # Sync before unmount
    sync
    sleep 2
    
    # Unmount
    fusermount -u "$plain_dir"
    
    if [ $? -eq 0 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_SUCCESS_UNMOUNTED"
        return 0
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_UNMOUNT_FAILED"
        return 1
    fi
}

# =========================================================================
# FUNCTION: encrypt_sql_dump
# Encrypt a SQL dump file with GPG
# =========================================================================
encrypt_sql_dump() {
    local input_file="$1"
    local output_file="$2"
    
    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_ERR_INPUT_FILE_NOT_FOUND" "$input_file")"
        return 1
    fi
    
    log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_ENCRYPTING_GPG" "$input_file")"
    
    # Encrypt with GPG
    gpg --homedir "$GPG_HOMEDIR" \
        --batch --yes \
        --recipient "$GPG_RECIPIENT" \
        --encrypt \
        --output "$output_file" \
        "$input_file"
    
    if [ $? -eq 0 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_SUCCESS_ENCRYPTED_GPG" "$output_file")"
        # Remove plaintext original
        rm -f "$input_file"
        return 0
    else
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_ERR_GPG_FAILED"
        return 1
    fi
}

# =========================================================================
# FUNCTION: show_encryption_status
# Display current encryption status
# =========================================================================
show_encryption_status() {
    log_echo ""
    log_echo "═══════════════════════════════════════════════════════════════"
    log_echo "                    $ENC_TITLE_STATUS"
    log_echo "═══════════════════════════════════════════════════════════════"
    
    if [ "$BACKUP_ENCRYPTION" -eq 1 ]; then
        log_echo "$(printf "$ENC_INFO_ENABLED" "$ENCRYPTION_METHOD")"
        log_echo "$(printf "$ENC_INFO_CIPHER_DIR" "$ENCRYPTION_CIPHERTEXT_DIR")"
        log_echo "$(printf "$ENC_INFO_PLAIN_MOUNT" "$ENCRYPTION_PLAINTEXT_MOUNT")"
        
        if mountpoint -q "$ENCRYPTION_PLAINTEXT_MOUNT" 2>/dev/null; then
            log_echo "$ENC_STATUS_MOUNTED"
        else
            log_echo "$ENC_STATUS_NOT_MOUNTED"
        fi
        
        if [ -f "$ENCRYPTION_CIPHERTEXT_DIR/gocryptfs.conf" ]; then
            log_echo "$ENC_STATUS_MASTER_KEY_PRESENT"
        else
            log_echo "$ENC_STATUS_MASTER_KEY_MISSING"
        fi
    else
        log_echo "$ENC_INFO_DISABLED"
    fi
    
    log_echo "═══════════════════════════════════════════════════════════════"
    log_echo ""
}

# ===== [ MODIFIED DATE-BASED FOLDER MANAGEMENT ] =====
# ===== [ MODIFIED: Prevent double nesting with deduplication ] =====
# =========================================================================
# FUNCTION: get_encrypted_backup_path
# Returns the correct encrypted backup path based on configuration
# - If DEDUP_ENABLE=1: returns base path (dedup creates nested structure)
# - If BACKUP_USE_DATE_FOLDERS=1 (no dedup): returns /encrypted/YYYY-MM-DD/
# - Otherwise: returns /encrypted/
# =========================================================================
get_encrypted_backup_path() {
    local base_path="$1"
    local use_date_folders="${BACKUP_USE_DATE_FOLDERS:-0}"
    local dedup_enabled="${DEDUP_ENABLE:-0}"
    
    # If deduplication is enabled, return base path only
    # Dedup will create the nested YYYY-MM-DD/YYYY-MM-DD_HH-MM-SS structure
    if [ "$dedup_enabled" -eq 1 ]; then
        log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $ENC_INFO_DEDUP_HANDLES_STRUCTURE"
        echo "$base_path"
        return 0
    fi
    
    # If no dedup but date folders enabled, create date folder
    if [ "$use_date_folders" -eq 1 ]; then
        local date_folder=$(date '+%Y-%m-%d')
        local full_path="$base_path/$date_folder"
        
        # Create date folder if it doesn't exist
        if [ ! -d "$full_path" ]; then
            mkdir -p "$full_path"
            log_echo "[$(date '+%d.%m.%Y %H:%M:%S')] - $(printf "$ENC_INFO_DATE_FOLDER_CREATED" "$full_path")"
        fi
        
        echo "$full_path"
    else
        # Flat structure
        echo "$base_path"
    fi
}
# ===== [ END: Prevent double nesting with deduplication ] =====