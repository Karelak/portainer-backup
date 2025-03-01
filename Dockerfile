# syntax=docker/dockerfile:1

# *********************************************************************
#    ___   ___   ___   ___ ___                
#   / __| /_\ \ / /_\ / __| __|               
#   \__ \/ _ \ V / _ \ (_ | _|                
#   |___/_/_\_\_/_/_\_\___|___| ___   ___ ___ 
#   / __|/ _ \| __|_   _\ \    / /_\ | _ \ __|
#   \__ \ (_) | _|  | |  \ \/\/ / _ \|   / _| 
#   |___/\___/|_|   |_|   \_/\_/_/ \_\_|_\___|
# 
#  -------------------------------------------------------------------
#                         PORTAINER-BACKUP
#          https://github.com/SavageSoftware/portainer-backup
#  -------------------------------------------------------------------
#
#  This Dockerfile creates an Alpine-based Linux docker image
#  with the PORTAINER-BACKUP utility installed.  This is useful
#  for creating a Docker container to perform scheduled backups
#  of a portainer server.
#
# *********************************************************************
#       COPYRIGHT SAVAGESOFTWARE,LLC, @ 2022, ALL RIGHTS RESERVED
# *********************************************************************
FROM rclone/rclone:1.69.1

ARG USER_NAME="backuptool"
ARG USER_ID="1100"

ENV LOCALTIME_FILE="/tmp/localtime"

COPY scripts/*.sh /app/

RUN chmod +x /app/*.sh \
  && mkdir -m 777 /portainer \
  && apk add --no-cache 7zip bash curl supercronic tzdata zip \
  && ln -sf "${LOCALTIME_FILE}" /etc/localtime \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}"

ENTRYPOINT ["/app/entrypoint.sh"]
