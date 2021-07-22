#!/bin/bash

SHELL_LOG_PREFIX='[oneclick-scaleway]'

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick

SCWCLI_PATH=${TARAXA_ONE_CLICK_PATH}/scw
SCWCLI_VERSION=2.3.1

JQCLI_PATH=${TARAXA_ONE_CLICK_PATH}/jq

DROPLET_BASE_NAME=taraxa-node-oneclick
# Ubuntu 20.04 Focal Fossa
DROPLET_IMAGE_ID="ubuntu_focal"
DROPLET_REGION_ID="fr-par-1"
# DEV1-L: 4C/8G/80GB NVMe/400Mbps 
DROPLET_INSTANCE_TYPE_ID="DEV1-L"
DROPLET_SCRIPT_NAME="taraxa-node-oneclick"

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

# Get scaleway-cli (we want it to always overwrite it)
ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
case "$ARCH" in
    "x86_64" ) ARCH="x86_64";;
    "arm64"  ) ARCH="arm64";;
    "i686"   ) ARCH="386" ;;
esac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS" == "darwin" ]; then
    OS="darwin"
    if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86_64" ]; then
        echo "$SHELL_LOG_PREFIX sorry, scaleway cli doesn't support your $OS $ARCH."
        exit 1
    fi
elif [ "$OS" == "linux" ]; then
    OS="linux"
    if [ "$ARCH" != "386" ] && [ "$ARCH" != "x86_64" ]; then
        echo "$SHELL_LOG_PREFIX sorry, scaleway cli doesn't support your $OS $ARCH."
        exit 1
    fi
else
    echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your operating system."
    exit 1
fi
echo "$SHELL_LOG_PREFIX begin to download scaleway cli..."
curl -fsSL https://github.com/scaleway/scaleway-cli/releases/download/v${SCWCLI_VERSION}/scw-${SCWCLI_VERSION}-${OS}-${ARCH} -o scw
if [ $? != 0 ] || [ ! -f "$SCWCLI_PATH" ]; then
    echo "$SHELL_LOG_PREFIX download scaleway cli failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download scaleway cli success!"
    chmod a+x $SCWCLI_PATH
fi

# Get jq to handle response data with json
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS" == "darwin" ]; then
    OS="osx-amd64"
elif [ "$OS" == "linux" ]; then
    OS="linux64"
else
    echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your operating system."
    exit 1
fi
echo "$SHELL_LOG_PREFIX begin to download jq json parser..."
curl -fsSL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-${OS} -o jq && chmod a+x jq 
if [ $? != 0 ] || [ ! -f "$JQCLI_PATH" ]; then
    echo "$SHELL_LOG_PREFIX download jq json parser failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download jq json parser success!"
fi
echo '{"note": "Taraxa is an excellent project!"}' | $JQCLI_PATH '.note' > /dev/null || { echo "$SHELL_LOG_PREFIX Jq parser failed, it is possible that the script is not suitable for your operating system." ; exit 1 ; }

# Check permissions
# How to get scaleway AK: https://console.scaleway.com/project/credentials
ACCOUNT_SSH_KEY_LIST=$($SCWCLI_PATH account ssh-key list -o json)
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX begin to init scaleway cli..."
    $SCWCLI_PATH init send-telemetry=false install-autocomplete=false remove-v1-config=true
    if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX Sorry, init scaleway cli error, please try again."
        exit 1
    fi
fi
echo "$SHELL_LOG_PREFIX begin to detect or generate ssh key..."
ACCOUNT_SSH_KEY_NUMBER=$($SCWCLI_PATH account ssh-key list -o json | $JQCLI_PATH 'length')
if [ $ACCOUNT_SSH_KEY_NUMBER == 0 ]; then
    echo "$SHELL_LOG_PREFIX There is no ssh public key in the default project and organization."
	SSH_KEY_PATH=$(echo "$HOME/.ssh/taraxa_node_oneclick_rsa.pub")
    if [ -f $SSH_KEY_PATH ]; then
        echo "$SHELL_LOG_PREFIX found ~/.ssh/taraxa_node_oneclick_rsa.pub, we will use it."
    else
        echo "$SHELL_LOG_PREFIX begin to generate ssh key..."
        ssh-keygen -t rsa -b 4096 -P "" -f ~/.ssh/taraxa_node_oneclick_rsa -C "root"
    fi
    ACCOUNT_SSH_KEY_ADD=$($SCWCLI_PATH account ssh-key add name=taraxa-node-oneclick public-key="$(cat ~/.ssh/taraxa_node_oneclick_rsa.pub)")
	if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX Add ssh public key to your default project failed, please try again..."
        exit 1
    else
        echo "$SHELL_LOG_PREFIX Add ssh public key to your default successfully!"
    fi
else
    echo "$SHELL_LOG_PREFIX Detected ssh public key in the default project and organization, we will use it."
fi

# Get random region
# Note: fr-par-3 is not available to be managed, and I have created a ticket to ask.
DROPLET_REGION_LIST=$($SCWCLI_PATH marketplace image list -o json | $JQCLI_PATH '.[]' | $JQCLI_PATH --arg DROPLET_IMAGE_ID $DROPLET_IMAGE_ID 'select(.label==$DROPLET_IMAGE_ID)' | $JQCLI_PATH --arg DROPLET_INSTANCE_TYPE_ID $DROPLET_INSTANCE_TYPE_ID '.versions[0].local_images[] | select(true==contains({compatible_commercial_types: [$DROPLET_INSTANCE_TYPE_ID]})) | select(.zone!="fr-par-3") | .zone')
if [ $? == 0 ]; then
    echo "$SHELL_LOG_PREFIX Get region successfully..."
    LENGTH=$(echo $DROPLET_REGION_LIST | $JQCLI_PATH -s 'length')
    RANDOM_NUMBER=$(($RANDOM % $LENGTH))
    DROPLET_REGION_ID=$(echo $DROPLET_REGION_LIST | $JQCLI_PATH -r -s --arg RANDOM_NUMBER $RANDOM_NUMBER '.[$RANDOM_NUMBER|tonumber]')
fi
echo "$SHELL_LOG_PREFIX Select random region: $DROPLET_REGION_ID"

# random name suffix
RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 4 ; echo '')
DROPLET_NAME=${DROPLET_BASE_NAME}-$RND_STR

echo "$SHELL_LOG_PREFIX Building cloud-init command..."
DROPLET_USERDATA_SCRIPT=$(cat << EOF
#cloud-config
runcmd:
   - mkdir /taraxa-oneclick
   - curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output /taraxa-oneclick/bootstrap-userdata.sh
   - chmod 755 /taraxa-oneclick/bootstrap-userdata.sh
   - /taraxa-oneclick/bootstrap-userdata.sh
EOF
)
echo "$DROPLET_USERDATA_SCRIPT"

echo "$SHELL_LOG_PREFIX Creating instance server..."
# Create Droplet
${SCWCLI_PATH} instance server create \
    name=${DROPLET_NAME} \
    ip=new \
    image=${DROPLET_IMAGE_ID} \
    zone=${DROPLET_REGION_ID} \
    type=$DROPLET_INSTANCE_TYPE_ID \
    root-volume=l:80G \
    cloud-init="$DROPLET_USERDATA_SCRIPT"
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX Creating instance server failed!"
    exit 1
fi

echo "$SHELL_LOG_PREFIX Congratulation! create instance server successfully!"
sleep 5
$SCWCLI_PATH instance server list zone=$DROPLET_REGION_ID
