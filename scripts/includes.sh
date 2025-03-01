#!/bin/bash

ENV_FILE="/.env"
CRON_CONFIG_FILE="${HOME}/crontabs"
BACKUP_DIR="/portainer/backup"
RESTORE_DIR="/portainer/restore"

########################################
# Print colorful message.
########################################
function color() {
    case $1 in
        red)     echo -e "\033[31m$2\033[0m" ;;
        green)   echo -e "\033[32m$2\033[0m" ;;
        yellow)  echo -e "\033[33m$2\033[0m" ;;
        blue)    echo -e "\033[34m$2\033[0m" ;;
        none)    echo "$2" ;;
    esac
}

########################################
# Check storage system connection success.
########################################
function check_rclone_connection() {
    # check if the configuration exists
    rclone ${RCLONE_GLOBAL_FLAG} config show "${RCLONE_REMOTE_NAME}" > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        color red "rclone configuration information not found"
        color blue "Please configure rclone first, check README.md#backup"
        exit 1
    fi

    # check connection
    local ERROR_COUNT=0

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        rclone ${RCLONE_GLOBAL_FLAG} lsd "${RCLONE_REMOTE_X}" > /dev/null
        if [[ $? != 0 ]]; then
            color red "storage system connection failure $(color yellow "[${RCLONE_REMOTE_X}]")"
            ((ERROR_COUNT++))
        fi
    done

    if [[ "${ERROR_COUNT}" -gt 0 ]]; then
        if [[ "$1" == "all" ]]; then
            color red "storage system connection failure exists"
            exit 1
        fi
    fi
}

########################################
# Get environment variable value.
########################################
function get_env() {
    local VAR="$1"
    local VAR_FILE="${VAR}_FILE"
    local VAR_DOTENV="DOTENV_${VAR}"
    local VAR_DOTENV_FILE="DOTENV_${VAR_FILE}"
    local VALUE=""

    if [[ -n "${!VAR:-}" ]]; then
        VALUE="${!VAR}"
    elif [[ -n "${!VAR_FILE:-}" ]]; then
        VALUE="$(cat "${!VAR_FILE}")"
    elif [[ -n "${!VAR_DOTENV_FILE:-}" ]]; then
        VALUE="$(cat "${!VAR_DOTENV_FILE}")"
    elif [[ -n "${!VAR_DOTENV:-}" ]]; then
        VALUE="${!VAR_DOTENV}"
    fi

    export "${VAR}=${VALUE}"
}

########################################
# Get RCLONE_REMOTE_LIST variables.
########################################
function get_rclone_remote_list() {
    RCLONE_REMOTE_LIST=()

    local i=0
    local RCLONE_REMOTE_NAME_X_REFER
    local RCLONE_REMOTE_DIR_X_REFER
    local RCLONE_REMOTE_X

    # for multiple remotes
    while true; do
        RCLONE_REMOTE_NAME_X_REFER="RCLONE_REMOTE_NAME_${i}"
        RCLONE_REMOTE_DIR_X_REFER="RCLONE_REMOTE_DIR_${i}"
        get_env "${RCLONE_REMOTE_NAME_X_REFER}"
        get_env "${RCLONE_REMOTE_DIR_X_REFER}"

        if [[ -z "${!RCLONE_REMOTE_NAME_X_REFER}" || -z "${!RCLONE_REMOTE_DIR_X_REFER}" ]]; then
            break
        fi

        RCLONE_REMOTE_X=$(echo "${!RCLONE_REMOTE_NAME_X_REFER}:${!RCLONE_REMOTE_DIR_X_REFER}" | sed 's@\(/*\)$@@')
        RCLONE_REMOTE_LIST=(${RCLONE_REMOTE_LIST[@]} "${RCLONE_REMOTE_X}")

        ((i++))
    done
}

########################################
# Export environment variables from file.
########################################
function export_env_file() {
    if [[ -f "${ENV_FILE}" ]]; then
        set -a
        source "${ENV_FILE}"
        set +a
    fi
}

########################################
# Initialization environment variables.
########################################
function init_env() {
    # export
    export_env_file

    # DATA_DIR
    get_env DATA_DIR
    DATA_DIR="${DATA_DIR:-"/data"}"

    # BACKUP_FILE_SUFFIX
    get_env BACKUP_FILE_SUFFIX
    BACKUP_FILE_SUFFIX="${BACKUP_FILE_SUFFIX:-"portainer-backup"}"

    # TIMEZONE
    get_env TIMEZONE
    TIMEZONE="${TIMEZONE:-"UTC"}"

    # CRON
    get_env CRON
    CRON="${CRON:-"5 * * * *"}"

    # RCLONE_REMOTE_NAME
    get_env RCLONE_REMOTE_NAME
    RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-"PortainerBackup"}"
    RCLONE_REMOTE_NAME_0="${RCLONE_REMOTE_NAME}"

    # RCLONE_REMOTE_DIR
    get_env RCLONE_REMOTE_DIR
    RCLONE_REMOTE_DIR="${RCLONE_REMOTE_DIR:-"/PortainerBackup/"}"
    RCLONE_REMOTE_DIR_0="${RCLONE_REMOTE_DIR}"

    # get RCLONE_REMOTE_LIST
    get_rclone_remote_list

    # RCLONE_GLOBAL_FLAG
    get_env RCLONE_GLOBAL_FLAG
    RCLONE_GLOBAL_FLAG="${RCLONE_GLOBAL_FLAG:-""}"

    # ZIP_ENABLE
    get_env ZIP_ENABLE
    if [[ "${ZIP_ENABLE^^}" == "FALSE" ]]; then
        ZIP_ENABLE="FALSE"
    else
        ZIP_ENABLE="TRUE"
    fi

    # ZIP_PASSWORD
    get_env ZIP_PASSWORD
    ZIP_PASSWORD="${ZIP_PASSWORD:-""}"

    # ZIP_TYPE
    get_env ZIP_TYPE
    if [[ "${ZIP_TYPE^^}" == "7Z" ]]; then
        ZIP_TYPE="7Z"
    else
        ZIP_TYPE="ZIP"
    fi

    # BACKUP_KEEP_DAYS
    get_env BACKUP_KEEP_DAYS
    BACKUP_KEEP_DAYS=${BACKUP_KEEP_DAYS:-"0"}

    # BACKUP_FILE_DATE
    get_env BACKUP_FILE_DATE
    BACKUP_FILE_DATE="${BACKUP_FILE_DATE:-"%Y%m%d"}"
    
    # BACKUP_FILE_DATE_SUFFIX
    get_env BACKUP_FILE_DATE_SUFFIX
    BACKUP_FILE_DATE_SUFFIX="${BACKUP_FILE_DATE_SUFFIX:-""}"
    
    # Define the final date format
    BACKUP_FILE_DATE_FORMAT="${BACKUP_FILE_DATE}${BACKUP_FILE_DATE_SUFFIX}"
}

########################################
# Send notification.
########################################
function send_notification() {
    local STATUS="$1"
    local MESSAGE="$2"

    color blue "${MESSAGE}"
}
