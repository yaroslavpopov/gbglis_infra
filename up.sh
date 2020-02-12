#!/bin/bash

set -e

BRANCH=$1
DOMAIN=$2
TFS_USER=$3
TFS_TOKEN=$4

JENKINS_TOKEN="11843f2e9da9e2dfa8c5559c1a259e5b11"
JENKINS_USER="admin"
JENKINS_URL="http://192.168.161.240:8320"
BASE_URL="http://192.168.160.166:8080/tfs/DMDL/"
REPO_URL="${BASE_URL}_git/GBGLIS"
HOOK_URL="${BASE_URL}_apis/hooks/subscriptions"
PROJECT_ID="327ebaa7-1ccd-48e3-90d5-96f8caa03664"    # curl ${BASE_URL}_apis/git/repositories -u :$TFS_TOKEN
REPOSITORY_ID="5fd70a75-7cc0-4596-9089-a84966188769" # curl ${BASE_URL}_apis/git/repositories -u :$TFS_TOKEN
GBGLIS_DIR="/home/ironjab/gbglis"
NGINX_DIR="/home/ironjab/nginx/conf.d"
NGINX_CONTAINER_NAME="global-nginx"
GBGLIS_JOB="$JENKINS_URL/job/GBGLIS/job/$BRANCH"
INFRA_DIR=$(dirname "$(readlink -f "$0")") 

echo "[up] START"

# [1] CHECK JOB
#############################################################################################
echo "[up] Validate branch name"

urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c"
        esac
    done
}

if [ $BRANCH != $(urlencode $BRANCH) ]; then
        echo "[up] ERROR: INVALID BRANCH NAME: $BRANCH"
        exit 1
fi

echo "[up] Сhecking existence of the job: $GBGLIS_JOB"
JOB_STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" $GBGLIS_JOB/api/json --user $JENKINS_USER:$JENKINS_TOKEN)
if [[ $JOB_STATUS_CODE -eq 404 ]]; then
        echo "[up] ERROR: Job doesn't exist: $GBGLIS_JOB"
        exit 1
fi
#############################################################################################

# [2] PREPARE DIR
#############################################################################################
echo "[up] Preparing branch dir: $GBGLIS_DIR/$BRANCH"

random_port() {
        read LOWERPORT UPPERPORT </proc/sys/net/ipv4/ip_local_port_range
        while :; do
                PORT="$(shuf -i $LOWERPORT-$UPPERPORT -n 1)"
                ss -lpn | grep -q ":$PORT " || break
        done
        echo $PORT
}

if [ -d "$GBGLIS_DIR/$BRANCH" ]; then
        echo "[up] ERROR: Dir already exists: $GBGLIS_DIR/$BRANCH"
        exit 1
fi

git -c http.extraheader="AUTHORIZATION: Basic $(echo -n $TFS_USER:$TFS_TOKEN | base64 -w0)" clone -b $BRANCH --single-branch $REPO_URL "$GBGLIS_DIR/$BRANCH"

cd "$GBGLIS_DIR/$BRANCH"
cp .env.sample .env
sed -i -e "s@{{BRANCH_NAME}}@${BRANCH}@g" .env
for SEDVAR in WEB_HOST_PORT API_HOST_PORT IDENTITY_HOST_PORT; do
        eval "$SEDVAR=$(random_port)"
        sed -i -e "s@{{$SEDVAR}}@$(eval echo \$$SEDVAR)@g" .env
done

echo "[up] .env:"
cat .env
echo ""

WEBENV_FILE="LIS.Web/src/environments/environment.feature.ts"
if [ ! -f $WEBENV_FILE ] || ! grep -q https://$BRANCH.$DOMAIN $WEBENV_FILE; then
        cp "$INFRA_DIR/GBGLIS/$WEBENV_FILE.tmpl" $WEBENV_FILE
        sed -i -e "s@{{BRANCH}}@${BRANCH}@g" $WEBENV_FILE
        sed -i -e "s@{{DOMAIN}}@${DOMAIN}@g" $WEBENV_FILE
        git config --global user.name "jenkins"
        git config --global user.email "jenkins@ironjab.com"
        git add $WEBENV_FILE
        git commit -am "[cicd] update web environment.feature.ts"
        git -c http.extraheader="AUTHORIZATION: Basic $(echo -n $TFS_USER:$TFS_TOKEN | base64 -w0)" push origin $BRANCH
fi

echo "[up] $WEBENV_FILE:"
cat $WEBENV_FILE
echo ""
#############################################################################################

# [3] TRIGGER JOB
#############################################################################################
echo "[up] Triggering job: $GBGLIS_JOB"

apt update -qq && apt install -y -qq jq

echo -n "[up] Waiting executors"
while true; do
        COMPUTER_INFO=$(curl -X GET $JENKINS_URL/computer/api/json -u $JENKINS_USER:$JENKINS_TOKEN 2>/dev/null)
        TOTAL_EXECUTORS=$(echo $COMPUTER_INFO | jq .totalExecutors)
        BUSY_EXECUTORS=$(echo $COMPUTER_INFO | jq .busyExecutors)
        if [[ $BUSY_EXECUTORS -eq $TOTAL_EXECUTORS ]]; then
                echo -n "."
                sleep 5
        else
                break
        fi
done
echo ""

GBGLIS_JOB_BUILD_ID=$(curl -X GET $GBGLIS_JOB/api/json -u $JENKINS_USER:$JENKINS_TOKEN 2>/dev/null | jq '.nextBuildNumber')
curl -X POST "$GBGLIS_JOB/buildWithParameters?FORCE_BUILD=true" -u $JENKINS_USER:$JENKINS_TOKEN
echo "[up] Starting Job:$GBGLIS_JOB with Build number: $GBGLIS_JOB_BUILD_ID"

# Wait until the build is up and running
echo -n "[up] Waiting up and running"
while true; do
        GBGLIS_JOB_STATUS_CODE=$(curl --write-out %{http_code} --silent --output /dev/null $GBGLIS_JOB/$GBGLIS_JOB_BUILD_ID/api/json -u $JENKINS_USER:$JENKINS_TOKEN)
        if [[ $GBGLIS_JOB_STATUS_CODE -eq 404 ]]; then
                echo -n "."
                sleep 2
        else
                break
        fi
done
echo ""

echo -n "[up] Waiting completion"
while true; do
        GBGLIS_JOB_RUNNING=$(curl -X GET $GBGLIS_JOB/$GBGLIS_JOB_BUILD_ID/api/json -u $JENKINS_USER:$JENKINS_TOKEN 2>/dev/null | jq -r '.building')
        if [ "$GBGLIS_JOB_RUNNING" == "true" ]; then
                echo -n "."
                sleep 2
        else
                break
        fi
done
echo ""

GBGLIS_JOB_STATUS=$(curl -X GET $GBGLIS_JOB/$GBGLIS_JOB_BUILD_ID/api/json -u $JENKINS_USER:$JENKINS_TOKEN 2>/dev/null | jq -r '.result')
if [ "$GBGLIS_JOB_STATUS" != "SUCCESS" ]; then
        echo "[up] ERROR: Job failed, status: $GBGLIS_JOB_STATUS"
        exit 1
fi
#############################################################################################

# [4] CONFIGURE GLOBAL NGINX
#############################################################################################
echo "[up] Configuring global nginx"

create_nginx_config() {
        local SN_PREFIX=$1
        local PORT=$2

        local SERVER_NAME=$SN_PREFIX.$DOMAIN
        local CONF="$NGINX_DIR/$SERVER_NAME.conf"

        cp "$INFRA_DIR/nginx/default.conf" $CONF

        sed -i -e "s@{{DOMAIN}}@${DOMAIN}@g" $CONF
        sed -i -e "s@{{SERVER_NAME}}@${SERVER_NAME}@g" $CONF
        sed -i -e "s@{{PORT}}@${PORT}@g" $CONF

        echo "[up] $CONF:"
        cat $CONF
        echo ""
}

echo "[up] Creating WEB nginx config"
create_nginx_config $BRANCH $WEB_HOST_PORT
echo "[up] Creating API nginx config"
create_nginx_config $BRANCH-api $API_HOST_PORT
echo "[up] Creating IDENTITY nginx config"
create_nginx_config $BRANCH-identity $IDENTITY_HOST_PORT

echo "[up] Restarting nginx"
docker kill -s HUP $NGINX_CONTAINER_NAME
#############################################################################################

# [5] CREATE SERVICE HOOK
#############################################################################################
echo "[up] Creating TFS service hook"

service_hook_data() {
        cat <<EOF
{
  "publisherId": "tfs",
  "eventType": "git.push",
  "consumerId": "jenkins",
  "consumerActionId": "triggerGenericBuild",
  "publisherInputs": {
    "branch": "$BRANCH",
    "projectId": "$PROJECT_ID",
    "repository": "$REPOSITORY_ID"
  },
  "consumerInputs": {
    "buildName": "GBGLIS/$BRANCH",
    "serverBaseUrl": "$JENKINS_URL",
    "username": "$JENKINS_USER",
    "useTfsPlugin": "built-in",
    "password": "$JENKINS_TOKEN",
    "buildParameterized": "true"
  },
}
EOF
}

HOOK_STATUS_CODE=$(curl -s -H "Accept: application/json; api-version=1.0" -H "Content-Type:application/json" --data "$(service_hook_data)" -XPOST -u :$TFS_TOKEN $HOOK_URL)
if [[ $HOOK_STATUS_CODE -eq 404 ]]; then
        echo "[up] ERROR: Can't create service hook: $HOOK_STATUS_CODE"
        exit 1
fi
#############################################################################################
echo "[up] DONE"

echo "[up] GO TO https://$BRANCH.$DOMAIN"
