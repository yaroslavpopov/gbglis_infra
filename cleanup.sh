#!/bin/bash

set -e

DOMAIN=$1
TFS_USER=$2
TFS_TOKEN=$3

GBGLIS_DIR="/home/ironjab/gbglis"
BASE_URL="http://192.168.160.166:8080/tfs/DMDL/"
REPOSITORY_ID="5fd70a75-7cc0-4596-9089-a84966188769" # curl ${BASE_URL}_apis/git/repositories -u :$TFS_TOKEN
INFRA_DIR="/tmp/cleanup"

echo "[cleanup] START"

echo "[cleanup] Checking branches"
REMOVED_BRANCHES=()
for dir in $GBGLIS_DIR/*/; do
    BRANCH=$(basename $dir)
    BRANCH_EXISTS=$(curl -s -XGET ${BASE_URL}_apis/git/repositories/${REPOSITORY_ID}/refs?filter=heads/$BRANCH -u :$TFS_TOKEN | jq ".value[] | select(.name==\"refs/heads/$BRANCH\")")
    if [[ ! $BRANCH_EXISTS ]]; then
        REMOVED_BRANCHES+=($BRANCH)
    fi
done

if [[ ! $REMOVED_BRANCHES ]]; then
    echo "[cleanup] DONE"
    exit 0
fi

echo "[cleanup] Need to destroy ENVs for branches: ${REMOVED_BRANCHES[@]}"
for BRANCH in ${REMOVED_BRANCHES[*]}; do
    echo "[cleanup] Destroying for: $BRANCH"
    $INFRA_DIR/down.sh $BRANCH $DOMAIN $TFS_USER $TFS_TOKEN
done

echo "[cleanup] DONE"
