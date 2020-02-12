#!/bin/bash

set -e

DOMAIN=$1
TFS_USER=$2
TFS_TOKEN=$3
INFRA_REPO=$4
INFRA_DIR="/tmp/cleanup"

echo "[cleanup-cron] START: $(date) >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

echo "[cleanup-cron] Clonning infra repo '$INFRA_REPO' to '$INFRA_DIR'"
git clone $INFRA_REPO $INFRA_DIR

echo "[cleanup-cron] Starting cleanup script"
sudo /tmp/cleanup/cleanup.sh $DOMAIN $TFS_USER $TFS_TOKEN

echo "[cleanup-cron] Removing infra dir: $INFRA_DIR"
rm -rf $INFRA_DIR

echo "[cleanup-cron] DONE: $(date) <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
