#!/bin/bash

. /app/includes.sh

# rclone command
if [[ "$1" == "rclone" ]]; then
    $*
    exit 0
fi

# backup manually
if [[ "$1" == "backup" ]]; then
    color yellow "Manually triggering a backup will only execute the backup script once, and the container will exit upon completion."
    bash "/app/backup.sh"
    exit 0
fi

function configure_timezone() {
    if [[ -n "${TIMEZONE}" && -f "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
        ln -sf "/usr/share/zoneinfo/${TIMEZONE}" "${LOCALTIME_FILE}"
    fi
}

function configure_cron() {
    local FIND_CRON_COUNT="$(grep -c 'backup.sh' "${CRON_CONFIG_FILE}" 2> /dev/null)"
    if [[ "${FIND_CRON_COUNT}" -eq 0 ]]; then
        echo "${CRON} bash /app/backup.sh" >> "${CRON_CONFIG_FILE}"
    fi
}

init_env
check_rclone_connection all
configure_timezone
configure_cron

# foreground run crond
exec /usr/bin/supercronic -passthrough-logs -quiet "${CRON_CONFIG_FILE}"
