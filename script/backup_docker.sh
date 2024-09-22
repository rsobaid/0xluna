#!/bin/bash
set -e

source .env

mkdir -p "$log_directory"

current_date=$(date +"%Y%m%d")
log_file="$log_directory/backup_$current_date.log"

log_with_timestamp() {
    local message="$1"
    local level="$2"
    local timestamped_message="$(date +"%Y-%m-%d %H:%M:%S") - $message"

    echo "$timestamped_message"
    echo "$timestamped_message" >> "$log_file"
}

log_with_timestamp "Starting the backup process." "info"

if ! command -v docker &> /dev/null; then
    log_with_timestamp "Docker is not installed or not in PATH." "error"
    exit 1
fi

mkdir -p "$docker_backup"
containers=$(docker ps --format '{{.ID}}')

for container_id in $containers; do
    log_with_timestamp "Stopping container '$container_id'." "info"
    if ! docker stop "$container_id" >> "$log_file" 2>&1; then
        log_with_timestamp "Error stopping container '$container_id'." "error"
    fi
done

log_with_timestamp "Backing up '$docker_dir'..." "info"
if tar -czvf "$docker_backup/docker-$current_date.tar.gz" "$docker_dir" >> "$log_file" 2>&1; then
    backup_status="completed successfully"
    log_with_timestamp "Backup $backup_status." "success"
else
    backup_status="failed"
    log_with_timestamp "Backup $backup_status." "error"
fi

for container_id in $containers; do
    log_with_timestamp "Starting container '$container_id'." "info"
    if ! docker start "$container_id" >> "$log_file" 2>&1; then
        log_with_timestamp "Error starting container '$container_id'." "error"
    fi
done

log_with_timestamp "Sending notification via Telegram..." "info"
STATUS_EMOJI=$([[ "$backup_status" == "completed successfully" ]] && echo "✅" || echo "❌")
STATUS_TEXT=$([[ "$backup_status" == "completed successfully" ]] && echo "Success" || echo "Failed")

FULL_MESSAGE=$(printf "%s *Docker Backup*  \n*Status:* %s  \n%s" "$STATUS_EMOJI" "$STATUS_TEXT" "$(date)")
curl -s -X POST "$TG_URL" -d "chat_id=$TG_ID" -d "text=$FULL_MESSAGE" -d "parse_mode=Markdown" >> "$log_file" 2>&1

log_with_timestamp "Notification sent to Telegram: Backup $backup_status." ${backup_status:+"success"} || log_with_timestamp "Notification sent to Telegram: Backup $backup_status." "error"

log_with_timestamp "Deleting files older than 35 days from '$docker_backup'..." "info"
find "$docker_backup" -type f -mtime +35 -exec rm -rf {} \; >> "$log_file" 2>&1

log_with_timestamp "Files older than 35 days in '$docker_backup' have been deleted." "success"
log_with_timestamp "Backup completed." "success"
