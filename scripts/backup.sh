#!/bin/bash

. /app/includes.sh

function clear_dir() {
    rm -rf "${BACKUP_DIR}"
}

function backup_init() {
    NOW="$(date +"${BACKUP_FILE_DATE_FORMAT}")"
    # backup portainer data
    BACKUP_FILE_DATA="${BACKUP_DIR}/portainer.${NOW}.tar"
    
    # create backup dir
    mkdir -p "${BACKUP_DIR}"
}

function backup() {
    # backup portainer data
    color blue "backup portainer data"
    tar cf "${BACKUP_FILE_DATA}" -C "${DATA_DIR}" .
    if [[ $? != 0 ]]; then
        color red "backup failed"
        send_notification "failure" "Backup failed at $(date +"%Y-%m-%d %H:%M:%S %Z")."
        exit 1
    fi
}

function backup_package() {
    UPLOAD_FILE="${BACKUP_FILE_DATA}"

    # zip
    if [[ "${ZIP_ENABLE}" == "TRUE" ]]; then
        local CMD=""
        local EXT=""

        # use different zip command according to ZIP_TYPE
        if [[ "${ZIP_TYPE}" == "7Z" ]]; then
            CMD="7z a"
            EXT="7z"
            
            # password
            if [[ -n "${ZIP_PASSWORD}" ]]; then
                CMD="${CMD} -p${ZIP_PASSWORD}"
            fi
        else
            CMD="zip"
            EXT="zip"
            
            # password
            if [[ -n "${ZIP_PASSWORD}" ]]; then
                CMD="${CMD} -P ${ZIP_PASSWORD}"
            fi
        fi

        color blue "packaging backup files"
        
        # package name = <BACKUP_FILE_SUFFIX>.<DATE>.<EXT>
        local PACKAGE_FILE="${BACKUP_DIR}/${BACKUP_FILE_SUFFIX}.${NOW}.${EXT}"
        
        if [[ "${ZIP_TYPE}" == "7Z" ]]; then
            ${CMD} "${PACKAGE_FILE}" "${BACKUP_FILE_DATA}" > /dev/null
        else
            ${CMD} "${PACKAGE_FILE}" "${BACKUP_FILE_DATA}" > /dev/null
        fi
        
        if [[ $? != 0 ]]; then
            color red "package backup files failed"
            send_notification "failure" "Package failed at $(date +"%Y-%m-%d %H:%M:%S %Z")."
            exit 1
        fi
        
        UPLOAD_FILE="${PACKAGE_FILE}"
    fi
}

function upload() {
    # check file exists
    if [[ ! -f "${UPLOAD_FILE}" ]]; then
        color red "upload file not found"
        send_notification "failure" "File upload failed at $(date +"%Y-%m-%d %H:%M:%S %Z"). Reason: Upload file not found."
        exit 1
    fi

    # upload
    local HAS_ERROR="FALSE"

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        color blue "upload backup file to storage system $(color yellow "[${RCLONE_REMOTE_X}]")"

        rclone ${RCLONE_GLOBAL_FLAG} copy "${UPLOAD_FILE}" "${RCLONE_REMOTE_X}"
        if [[ $? != 0 ]]; then
            color red "upload failed"
            HAS_ERROR="TRUE"
        fi
    done

    if [[ "${HAS_ERROR}" == "TRUE" ]]; then
        send_notification "failure" "File upload failed at $(date +"%Y-%m-%d %H:%M:%S %Z")."
        exit 1
    fi
}

function clear_history() {
    if [[ "${BACKUP_KEEP_DAYS}" -gt 0 ]]; then
        for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
        do
            color blue "delete ${BACKUP_KEEP_DAYS} days ago backup files $(color yellow "[${RCLONE_REMOTE_X}]")"

            mapfile -t RCLONE_DELETE_LIST < <(rclone ${RCLONE_GLOBAL_FLAG} lsf "${RCLONE_REMOTE_X}" --min-age "${BACKUP_KEEP_DAYS}d")

            for RCLONE_DELETE_FILE in "${RCLONE_DELETE_LIST[@]}"
            do
                color yellow "deleting \"${RCLONE_DELETE_FILE}\""

                rclone ${RCLONE_GLOBAL_FLAG} delete "${RCLONE_REMOTE_X}/${RCLONE_DELETE_FILE}"
                if [[ $? != 0 ]]; then
                    color red "delete \"${RCLONE_DELETE_FILE}\" failed"
                fi
            done
        done
    fi
}

color blue "running the backup program at $(date +"%Y-%m-%d %H:%M:%S %Z")"

init_env
send_notification "start" "Start backup at $(date +"%Y-%m-%d %H:%M:%S %Z")"

check_rclone_connection any

clear_dir
backup_init
backup
backup_package
upload
clear_dir
clear_history

send_notification "success" "The file was successfully uploaded at $(date +"%Y-%m-%d %H:%M:%S %Z")."

color none ""
