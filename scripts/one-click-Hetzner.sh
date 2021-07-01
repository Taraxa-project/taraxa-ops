#!/bin/bash

SHELL_LOG_PREFIX='[taraxa-oneclick-hetzner]'

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick

HCLOUD_PATH=${TARAXA_ONE_CLICK_PATH}/hcloud
HCLOUD_VERSION=1.24.0

HCLOUD_USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
HCLOUD_BASE_NAME=taraxa-node-oneclick
# Ubuntu 20.04 x64
HCLOUD_IMAGE_ID=ubuntu-20.04
# cpx31 - shared 4 CPU + 8 GB RAM + 160 GB NVMe
HCLOUD_PLAN_ID="cpx31"
HCLOUD_LOCATION="1"

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

# Get hcloud script
echo "$SHELL_LOG_PREFIX begin to download hcloud cli..."

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
EXT="tar.gz"
if [ "$OS" == "darwin" ]; then
    OS="macos"
    EXT="zip"
elif [ "$OS" == "linux" ]; then
    OS="linux"
elif [ "$OS" == "freebsd" ]; then
    OS="freebsd"
elif [ "$OS" == "windows" ]; then
    OS="windows"
    EXT="zip"
else
    echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your operating system."
    exit 1
fi

ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
case "$ARCH" in
    "x86_64" ) ARCH="amd64";;
    "arm64"  ) ARCH="arm64";;
    "i686"   ) ARCH="386" ;;
esac

curl -fsSL https://github.com/hetznercloud/cli/releases/download/v${HCLOUD_VERSION}/hcloud-${OS}-${ARCH}.${EXT} | tar -xz

if [ $? != 0 ] || [ ! -f "$HCLOUD_PATH" ]; then
    echo "$SHELL_LOG_PREFIX download hcloud cli failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download hcloud cli success!"
    chmod +x $HCLOUD_PATH
fi
if [[ -z $HCLOUD_TOKEN ]]; then 
    $HCLOUD_PATH context list | grep -q taraxa-oneclick-access 
    if [ $? -eq 0 ]; then
        echo "$SHELL_LOG_PREFIX Found taraxa-oneclick-access context using it"
        $HCLOUD_PATH context use taraxa-oneclick-access
    else
        echo "$SHELL_LOG_PREFIX Not found taraxa-oneclick-access context, creating it"
        $HCLOUD_PATH context create taraxa-oneclick-access
    fi
else
        echo "$SHELL_LOG_PREFIX Found HCLOUD_TOKEN env variable using it"
fi;
$HCLOUD_PATH server list > /dev/null || { echo "$SHELL_LOG_PREFIX Invalid Token." ; exit 1 ; }

# Get current bootstrap script
curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${HCLOUD_USERDATA_SCRIPT}
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX download bootstrap script failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download bootstrap script success!"
fi

# Get Location
echo -n "$SHELL_LOG_PREFIX select random location... "
HCLOUD_LOCATION=`$HCLOUD_PATH location list | grep -v DESCRIPTION | awk 'BEGIN{ srand() } rand() * NR < 1 { name = $2 } END { print name  }'`
echo $HCLOUD_LOCATION

RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 4 ; echo '')
HCLOUD_NAME=${HCLOUD_BASE_NAME}-$RND_STR

# Create server
${HCLOUD_PATH} server create --name ${HCLOUD_NAME} \
    --image ${HCLOUD_IMAGE_ID} \
    --location ${HCLOUD_LOCATION} \
    --type $HCLOUD_PLAN_ID \
    --user-data-from-file ${HCLOUD_USERDATA_SCRIPT}
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX failed to deploy..."
    exit 1
else
    echo "$SHELL_LOG_PREFIX successful!"
    $HCLOUD_PATH server list | grep $HCLOUD_NAME
fi 
