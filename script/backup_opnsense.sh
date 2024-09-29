#!/bin/bash
source $HOME/.env

DATE=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${opnsense_backup}/config-${OPN_HOST}-${DATE}.xml"

notify() {
  local status="$1"
  local message="$2"
  curl -X POST "$TG_URL" -d chat_id="$TG_ID" -d text="$message" -d parse_mode="Markdown"
}

if ! ERROR=$(curl -u "${OPN_KEY}:${OPN_SECRET}" "https://${OPN_HOST}/api/core/backup/download/this" --create-dirs -o "$BACKUP_FILE" 2>&1); then
  notify "Failed" "$(printf "❌ *OPNSense Backup*  \n*Status:* Failed  \n\n\`%s\`  \n\n%s" "$ERROR" "$(date)")"
  exit 1
fi

notify "Success" "$(printf "✅ *OPNSense Backup*  \n*Status:* Success  \n%s" "$(date)")"
find "${opnsense_backup}" -type f -name "config-${OPN_HOST}-*.xml" -mtime +30 -delete
