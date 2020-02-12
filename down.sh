#!/bin/bash

set -e

BRANCH=$1
DOMAIN=$2
TFS_USER=$3
TFS_TOKEN=$4

GBGLIS_DIR="/home/ironjab/gbglis/$BRANCH"
NGINX_DIR="/home/ironjab/nginx/conf.d"
NGINX_CONTAINER_NAME="global-nginx"
BASE_URL="http://192.168.160.166:8080/tfs/DMDL/"
HOOK_URL="${BASE_URL}_apis/hooks/subscriptions"

echo "[down] START"

# [1] REMOVE TFS SERVICE HOOKS
#############################################################################################
echo "[down] Removing TFS service hooks for: $BRANCH"

apt update -qq && apt install -y -qq jq

remove_hook() {
    local HOOK_ID=$1
    echo "[down] Removing hook: $HOOK_ID"
    STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" -XDELETE -H "Accept: api-version=1.0" -u :$TFS_TOKEN $HOOK_URL/$HOOK_ID)
    if [[ $STATUS_CODE -eq 204 ]]; then
        echo "[down] Hook '$HOOK_ID' successfully removed"
    else
        echo "[down] ERROR: Hook '$HOOK_ID' didn't remove, status code: $STATUS_CODE"
        exit 1
    fi
}

echo "[down] Finding hooks for: $BRANCH"
# export -f remove_hook
# curl -s -H "Accept: application/json; api-version=1.0" -H "Content-Type:application/json" -XGET -u :$TFS_TOKEN $HOOK_URL | jq -c --arg BRANCH "$BRANCH" '.value[] | select(.publisherInputs.branch | contains($BRANCH)) | .id' |xargs -n1 bash -c 'remove_hook "$@"' _
HOOK_IDS=$(curl -s -H "Accept: application/json; api-version=1.0" -H "Content-Type:application/json" -XGET -u :$TFS_TOKEN $HOOK_URL | jq -c --arg BRANCH "$BRANCH" '[ .value[] | select(.publisherInputs.branch | contains($BRANCH)) | .id ]')

echo "[down] Found hooks ids: $HOOK_IDS"
for HOOK_ID in $(echo $HOOK_IDS | jq -r ".[]"); do
    remove_hook $HOOK_ID
done
#############################################################################################

# [2] REMOVE NGINX CONFS
#############################################################################################
echo "[down] Removing nginx confs for: $BRANCH"
echo "[down] Removing WEB nginx config: $NGINX_DIR/$BRANCH.$DOMAIN.conf"
[ -f $NGINX_DIR/$BRANCH.$DOMAIN.conf ] && rm $NGINX_DIR/$BRANCH.$DOMAIN.conf
echo "[down] Removing API nginx config: $NGINX_DIR/$BRANCH-api.$DOMAIN.conf"
[ -f $NGINX_DIR/$BRANCH-api.$DOMAIN.conf ] && rm $NGINX_DIR/$BRANCH-api.$DOMAIN.conf
echo "[down] Removing IDENTITY nginx config: $NGINX_DIR/$BRANCH-identity.$DOMAIN.conf"
[ -f $NGINX_DIR/$BRANCH-identity.$DOMAIN.conf ] && rm $NGINX_DIR/$BRANCH-identity.$DOMAIN.conf
echo "[down] Restarting nginx"
docker kill -s HUP $NGINX_CONTAINER_NAME
#############################################################################################

# [3] STOP/REMOVE APP
#############################################################################################
echo "[down] Stopping app for: $BRANCH"

if [ -d $GBGLIS_DIR ]; then
    cd $GBGLIS_DIR
    echo "[down] Executing docker-compose down, pwd: $PWD"
    [ -f $GBGLIS_DIR/docker-compose.* ] && docker-compose down
    echo "[down] Removing app dir: $GBGLIS_DIR"
    rm -rf $GBGLIS_DIR
else
    echo "[down] Skipped. Dir: $GBGLIS_DIR does not exists"
fi
#############################################################################################

echo "[down] DONE"
