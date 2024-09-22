#!/bin/bash
set -e  # Exit on any command failure

source .env

# Path to where the Export should be saved to
PATHCONFIG="/home/ubuntu/backup/opnsense"

# Variable for unique naming for daily export
DATE=$(date +%Y%m%d%H%M%S)

# Define the backup file path
BACKUP_FILE="${PATHCONFIG}/config-${HOST}-${DATE}.xml"

# Make the API request for config as XML and capture the error message
if ! ERROR_MESSAGE=$(curl -u "${KEY}:${SECRET}" "https://${HOST}/api/core/backup/download/this" --create-dirs -o "$BACKUP_FILE" 2>&1); then
  # If curl fails, send a failure notification
  FULL_MESSAGE="❌ <b>OPNSense Backup</b>
<b>Status:</b> Failed

<code>$ERROR_MESSAGE</code>

$(date)"

  # Send the message to Telegram
  curl -X POST $TG_URL -d chat_id=$TG_ID -d text="$FULL_MESSAGE" -d parse_mode="HTML"
  exit 1
fi

# Send a notification to Telegram based on the backup status
FULL_MESSAGE="✅ <b>OPNSense Backup</b>
<b>Status:</b> Success
$(date)"

# Send the message to Telegram
curl -X POST $TG_URL -d chat_id=$TG_ID -d text="$FULL_MESSAGE" -d parse_mode="HTML"

# Check the backup destination for backups older than 35 days
find "${PATHCONFIG}" -type f -name "config-${HOST}-*.xml" -mtime +35 -delete
