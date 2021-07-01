#!/bin/bash

SHELL_LOG_PREFIX='[oneclick-vultr]'

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick

VCLI_PATH=${TARAXA_ONE_CLICK_PATH}/vultr-cli
VCLI_VERSION=2.5.3

DROPLET_USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
DROPLET_BASE_NAME=taraxa-node-oneclick
# Ubuntu 20.04 x64
DROPLET_IMAGE_ID=387
DROPLET_PLAN_ID="vc2-4c-8gb"
DROPLET_REGION_ID="ams"
DROPLET_SCRIPT_NAME="taraxa-node-oneclick"

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

# Get vultr-cli (we want it to always overwrite it)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
echo "$SHELL_LOG_PREFIX begin to download vultr cli..."
if [ "$OS" == "darwin" ]; then
    OS="macOs"
elif [ "$OS" == "linux" ]; then
    OS="linux"
else
    echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your operating system."
    exit 1
fi
curl -fsSL https://github.com/vultr/vultr-cli/releases/download/v${VCLI_VERSION}/vultr-cli_${VCLI_VERSION}_${OS}_64-bit.tar.gz | tar -xz
if [ $? != 0 ] || [ ! -f "$VCLI_PATH" ]; then
    echo "$SHELL_LOG_PREFIX download vultr cli failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download vultr cli success!"
fi


if [[ -z $VULTR_API_KEY ]]; then
    echo "$SHELL_LOG_PREFIX You need to export a valid VULTR_API_KEY"
    read -s -p "$SHELL_LOG_PREFIX Enter you VULTR_API_KEY(will be hidden) > " VULTR_API_KEY
    echo ""
    export VULTR_API_KEY=$VULTR_API_KEY
    $VCLI_PATH account || { echo "$SHELL_LOG_PREFIX Invalid Token." ; exit 1 ; }
fi

# Get current bootstrap script
curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${DROPLET_USERDATA_SCRIPT}
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX download bootstrap script failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download bootstrap script success!"
fi

# base64 script
echo | base64 -w0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    # GNU coreutils base64, '-w' supported
    DROPLET_USERDATA_SCRIPT=$(cat "${DROPLET_USERDATA_SCRIPT}" | base64 -w 0)
else
    DROPLET_USERDATA_SCRIPT=$(cat "${DROPLET_USERDATA_SCRIPT}" | base64)
fi

# Get Plan
echo "$SHELL_LOG_PREFIX begin to get plans list..."
DROPLET_PLAN_LIST=$($VCLI_PATH plans list)
DROPLET_PLAN_NUMBER=$(echo "$DROPLET_PLAN_LIST" | awk 'END{print}')
if [ "$DROPLET_PLAN_NUMBER" == 0 ]; then
    echo "$SHELL_LOG_PREFIX no plan to choose, exiting..."
    exit 1
fi
DROPLET_PLAN_LIST_CHOICE=$(echo "$DROPLET_PLAN_LIST" | awk -v DROPLET_PLAN_NUMBER="$DROPLET_PLAN_NUMBER" '{if(NR>0&&NR<=DROPLET_PLAN_NUMBER+1) print $0}')
echo "$DROPLET_PLAN_LIST_CHOICE"
echo "$SHELL_LOG_PREFIX choose plan: $DROPLET_PLAN_ID"
# filter available region list
DROPLET_PLAN_LIST_SELECT=$(echo "$DROPLET_PLAN_LIST" | awk '{if($1~/^'"$DROPLET_PLAN_ID"'$/)print}' | awk '{for(i=9;i<=NF;i++)print $i}' | awk '{gsub(/[\[|\]]/,"");print}')

# Get Zone
LENGTH=0
for item in ${DROPLET_PLAN_LIST_SELECT[*]}
do
    LENGTH=$(($LENGTH + 1))
done
RANDOM_NUMBER=$(($RANDOM % $LENGTH + 1))
echo "$SHELL_LOG_PREFIX Select random number: $RANDOM_NUMBER"
LENGTH=0
for item in ${DROPLET_PLAN_LIST_SELECT[*]}
do
    LENGTH=$(($LENGTH + 1))
    if [ "$LENGTH" == "$RANDOM_NUMBER" ]; then
        DROPLET_REGION_ID=$item
    fi
done
echo "$SHELL_LOG_PREFIX Select random region: $DROPLET_REGION_ID"

RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 4 ; echo '')
DROPLET_NAME=${DROPLET_BASE_NAME}-$RND_STR

# Check or create startup script
echo "$SHELL_LOG_PREFIX get script list..."
DROPLET_SCRIPT_LIST=$($VCLI_PATH script list)
DROPLET_SCRIPT_NUMBER=$(echo "$DROPLET_SCRIPT_LIST" | awk 'END{print}')
DROPLET_SCRIPT_ID=$(echo "$DROPLET_SCRIPT_LIST" | awk '{if($5~/^'"$DROPLET_SCRIPT_NAME"'$/) print $1}')
if [ "$DROPLET_SCRIPT_NUMBER" == 0 ] || [ -z "$DROPLET_SCRIPT_ID" ]; then
    echo "$SHELL_LOG_PREFIX begin to create script..."
    DROPLET_SCRIPT_CREATE=$(${VCLI_PATH} script create --name ${DROPLET_SCRIPT_NAME} --type boot --script ${DROPLET_USERDATA_SCRIPT})
    echo "$DROPLET_SCRIPT_CREATE"
    DROPLET_SCRIPT_ID=$(echo "$DROPLET_SCRIPT_CREATE" | awk 'NR==2{print $1}')
fi
echo "$SHELL_LOG_PREFIX We will use this script, ID: $DROPLET_SCRIPT_ID"

# Create Droplet
${VCLI_PATH} instance create --host ${DROPLET_NAME} \
    --os ${DROPLET_IMAGE_ID} \
    --region ${DROPLET_REGION_ID} \
    --plan $DROPLET_PLAN_ID \
    --script-id ${DROPLET_SCRIPT_ID}
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX failed to deploy..."
    exit 1
else
    echo "$SHELL_LOG_PREFIX successful!"
fi