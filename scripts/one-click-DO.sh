#!/bin/bash

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick
DOCTL_PATH=${TARAXA_ONE_CLICK_PATH}/doctl
DOCTL_VERSION=1.59.0
DROPLET_USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
DROPLET_SIZE=c-4
DROPLET_BASE_NAME=taraxa-node-oneclick
DROPLET_IMAGE=ubuntu-20-04-x64
DROPLET_VOLUME_SIZE=250GiB

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

# Get doctl (we want it to always overwrite it)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
curl -fsSL https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-${OS}-amd64.tar.gz | tar -xzv

# Verify doctl permissions
$DOCTL_PATH account get
RETURN=$?

if [ "$RETURN" != 0 ]; then
    echo "You need to export a valid DIGITALOCEAN_ACCESS_TOKEN"
    echo "Enter you DIGITALOCEAN_ACCESS_TOKEN: (will be hidden)"
    read -s DIGITALOCEAN_ACCESS_TOKEN
    export DIGITALOCEAN_ACCESS_TOKEN=$DIGITALOCEAN_ACCESS_TOKEN
    $DOCTL_PATH account get || { echo "Invalid Token." ; exit 1 ; }
fi

# Get current bootstrap script
curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/prepare/do.sh --output ${DROPLET_USERDATA_SCRIPT}

# Get random Zone
REGIONS=($($DOCTL_PATH compute region list | grep true | awk '{ print $1}'))
DROPLET_REGION=${REGIONS[$RANDOM % ${#REGIONS[@]}]}

RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 4 ; echo '')
DROPLET_NAME=${DROPLET_BASE_NAME}-$RND_STR

# Create Volume
${DOCTL_PATH} compute volume create ${DROPLET_NAME} \
    --region ${DROPLET_REGION} \
    --size $DROPLET_VOLUME_SIZE

VOLUME_ID=($($DOCTL_PATH compute volume list | grep $DROPLET_NAME | awk '{print $1}'))

# Create Droplet
${DOCTL_PATH} compute droplet create ${DROPLET_NAME} \
    --image ${DROPLET_IMAGE} \
    --region ${DROPLET_REGION} \
    --size $DROPLET_SIZE \
    --volumes ${VOLUME_ID} \
    --user-data-file ${DROPLET_USERDATA_SCRIPT}

