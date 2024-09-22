#!/bin/bash
set -e  # Exit on any command failure

source .env

# Define color codes
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"

# Ensure log directory exists
mkdir -p "$log_directory"

# Define log file location and initialize
current_date=$(date +"%Y%m%d")
log_file="$log_directory/backup_$current_date.log"

# Function to prepend timestamp to log entries
log_with_timestamp() {
    local message="$1"
    local level="$2"
    local color="$3"
    local timestamped_message="$(date +"%Y-%m-%d %H:%M:%S") - $message"

    case "$level" in
        info)
            color="$CYAN"
            ;;
        success)
            color="$GREEN"
            ;;
        error)
            color="$RED"
            ;;
        warning)
            color="$YELLOW"
            ;;
        *)
            color="$RESET"
            ;;
    esac

    # Output to console with color
    echo -e "${color}${timestamped_message}${RESET}"
    # Output to log file without color codes
    echo "$timestamped_message" >> "$log_file"
}

# Start logging
log_with_timestamp "Starting the backup process." info

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_with_timestamp "Docker is not installed or not in PATH." error
    exit 1
fi

# Check if backup directory exists
if [ ! -d "$backup_directory" ]; then
    log_with_timestamp "Backup directory '$backup_directory' does not exist." error
    exit 1
fi

# Check if backup save directory exists
mkdir -p "$backup_save_directory"

# Get IDs of all running Docker containers
containers=$(docker ps --format '{{.ID}}')

# Stop each running container and log actions
for container_id in $containers; do
    log_with_timestamp "Stopping container '$container_id'." info
    docker stop "$container_id" >> "$log_file" 2>&1 || log_with_timestamp "Error stopping container '$container_id'." error
done

# Perform the backup and log actions
log_with_timestamp "Backing up '$backup_directory'..." info
tar -czvf "$backup_save_directory/docker-backup-$current_date.tar.gz" "$backup_directory" >> "$log_file" 2>&1

# Check if the backup command succeeded
if [ $? -eq 0 ]; then
    # Backup succeeded
    backup_status="completed successfully"
    log_with_timestamp "Backup $backup_status." success
else
    # Backup failed
    backup_status="failed"
    log_with_timestamp "Backup $backup_status." error
fi

# Start each container that was previously running and log actions
for container_id in $containers; do
    log_with_timestamp "Starting container '$container_id'." info
    docker start "$container_id" >> "$log_file" 2>&1 || log_with_timestamp "Error starting container '$container_id'." error
done

# Send a notification to Telegram based on the backup status
log_with_timestamp "Sending notification via Telegram..." info

# Determine the status and corresponding emoji/message
if [ "$backup_status" = "completed successfully" ]; then
    STATUS_EMOJI="✅"
    STATUS_TEXT="Success"
    LOG_MESSAGE="Backup was successful."
else
    STATUS_EMOJI="❌"
    STATUS_TEXT="Failed"
    LOG_MESSAGE="Backup failed."
fi

# Construct the full message
FULL_MESSAGE="$STATUS_EMOJI <b>Docker Backup</b>
<b>Status:</b> $STATUS_TEXT
$(date)"

# Send the message to Telegram
curl -s -X POST $TG_URL -d chat_id=$TG_ID -d text="$FULL_MESSAGE" -d parse_mode="HTML" >> "$log_file" 2>&1

# Log the result
log_with_timestamp "Notification sent to Telegram: $LOG_MESSAGE" ${backup_status:+"success"} || log_with_timestamp "Notification sent to Telegram: $LOG_MESSAGE" error

# Find and delete files older than 35 days in the target directory and log actions
log_with_timestamp "Deleting files older than 35 days from '$backup_save_directory'..." info
find "$backup_save_directory" -type f -mtime +35 -exec rm -rf {} \; >> "$log_file" 2>&1

# Print a message indicating the operation is complete and log it
log_with_timestamp "Files older than 35 days in '$backup_save_directory' have been deleted." success
log_with_timestamp "Backup completed." success
