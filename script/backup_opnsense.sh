#!/bin/bash
set -e

source .env

DATE=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${opnsense_backup}/config-${HOST}-${DATE}.xml"

notify() {
  local status="$1"
  local message="$2"
  curl -X POST "$TG_URL" -d chat_id="$TG_ID" -d text="$message" -d parse_mode="Markdown"
}

if ! ERROR=$(curl -u "${KEY}:${SECRET}" "https://${HOST}/api/core/backup/download/this" --create-dirs -o "$BACKUP_FILE" 2>&1); then
  notify "Failed" "$(printf "❌ *OPNSense Backup*  \n*Status:* Failed  \n\n\`%s\`  \n\n%s" "$ERROR" "$(date)")"
  exit 1
fi

notify "Success" "$(printf "✅ *OPNSense Backup*  \n*Status:* Success  \n%s" "$(date)")"
find "${opnsense_backup}" -type f -name "config-${HOST}-*.xml" -mtime +35 -delete
