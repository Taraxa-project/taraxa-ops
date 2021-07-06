#!/bin/bash

SHELL_LOG_PREFIX='[oneclick-alibaba-cloud]'

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick

ALYCLI_PATH=${TARAXA_ONE_CLICK_PATH}/aliyun
ALYCLI_VERSION=3.0.80

JQCLI_PATH=${TARAXA_ONE_CLICK_PATH}/jq

DROPLET_USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
DROPLET_BASE_NAME=taraxa-node-oneclick
# Ubuntu 20.04 x64
DROPLET_IMAGE_ID="ubuntu_20_04_x64_20G_alibase_20210521.vhd"
DROPLET_REGION_ID="cn-hangzhou"
DROPLET_CPU_CORES=4
DROPLET_MEMORY=8
DROPLET_INSTANCE_TYPE_ID="ecs.c6.xlarge"
DROPLET_SCRIPT_NAME="taraxa-node-oneclick"

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

# Get alibaba cloud cli (we want it to always overwrite it)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS" == "darwin" ]; then
    OS="macosx"
elif [ "$OS" == "linux" ]; then
    OS="linux"
else
    echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your operating system."
    exit 1
fi
echo "$SHELL_LOG_PREFIX begin to download alibaba cloud cli..."
curl -fsSL https://github.com/aliyun/aliyun-cli/releases/download/v${ALYCLI_VERSION}/aliyun-cli-${OS}-${ALYCLI_VERSION}-amd64.tgz | tar -xz
if [ $? != 0 ] || [ ! -f "$ALYCLI_PATH" ]; then
    echo "$SHELL_LOG_PREFIX download alibaba cloud cli failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download alibaba cloud cli success!"
    chmod a+x $ALYCLI_PATH
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
# How to get aliyun AK: https://usercenter.console.aliyun.com/#/manage/ak
if [[ -z $ALY_AK_ID ]] || [[ -z $ALY_AK_SECRET ]]; then
    echo "$SHELL_LOG_PREFIX You need to export two valid environment variables: ALY_AK_ID and ALY_AK_SECRET"
    read -s -p "$SHELL_LOG_PREFIX Enter your ALY_AK_ID(will be hidden) > " ALY_AK_ID
    echo ""
    export ALY_AK_ID=$ALY_AK_ID
    read -s -p "$SHELL_LOG_PREFIX Enter your ALY_AK_SECRET(will be hidden) > " ALY_AK_SECRET
    echo ""
    export ALY_AK_SECRET=$ALY_AK_SECRET
fi
$ALYCLI_PATH configure set \
    --profile akProfile \
    --mode AK \
    --region cn-hangzhou \
    --access-key-id $ALY_AK_ID \
    --access-key-secret $ALY_AK_SECRET

$ALYCLI_PATH ecs DescribeRegions > /dev/null || { echo "$SHELL_LOG_PREFIX Invalid Token." ; exit 1 ; }

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
if [ $? == 0 ]; then
    # GNU coreutils base64, '-w' supported
    DROPLET_USERDATA_SCRIPT=$(cat "${DROPLET_USERDATA_SCRIPT}" | base64 -w 0 | sed 's/=//g')
else
    DROPLET_USERDATA_SCRIPT=$(cat "${DROPLET_USERDATA_SCRIPT}" | base64 | sed 's/=//g')
fi
echo "$SHELL_LOG_PREFIX script: $DROPLET_USERDATA_SCRIPT"


# Check real-name authentication, only someone verified, can purchase ECS instances on Chinese region.
echo "$SHELL_LOG_PREFIX begin to check real-name authentication..."
ALY_CHECK_PERMISSION_RESULT=$($ALYCLI_PATH ecs DescribeAccountAttributes --RegionId "cn-hangzhou" --AttributeName.1 "real-name-authentication" | $JQCLI_PATH -r '.AccountAttributeItems.AccountAttributeItem[0].AttributeValues.ValueItem[0].Value')
echo "$SHELL_LOG_PREFIX check real-name authentication result: $ALY_CHECK_PERMISSION_RESULT"
ALY_REAL_NAME_PERMISSION_FLAG=0
if [ "$ALY_CHECK_PERMISSION_RESULT" == 'yes' ]; then
    echo "$SHELL_LOG_PREFIX We can use ECS instances on Chinese region."
	ALY_REAL_NAME_PERMISSION_FLAG=1
else
    echo "$SHELL_LOG_PREFIX Sorry, Chinese region is not permitted to use. You need finish real-name authentication."
	ALY_REAL_NAME_PERMISSION_FLAG=0
fi

# Get an available random region
echo "$SHELL_LOG_PREFIX begin to get an available random region..."
DROPLET_REGION_LIST=$($ALYCLI_PATH ecs DescribeRegions | $JQCLI_PATH '.Regions.Region[] | .RegionId')
if [ "$ALY_REAL_NAME_PERMISSION_FLAG" == 0 ]; then
    # remove Chinese region
    DROPLET_REGION_LIST=$(echo $DROPLET_REGION_LIST | $JQCLI_PATH 'select(false==startswith("cn-"))')
fi
LENGTH=$(echo $DROPLET_REGION_LIST | $JQCLI_PATH -s 'length')
RANDOM_NUMBER=$(($RANDOM % $LENGTH))
DROPLET_REGION_ID=$(echo $DROPLET_REGION_LIST | $JQCLI_PATH -r -s --arg RANDOM_NUMBER $RANDOM_NUMBER '.[$RANDOM_NUMBER|tonumber]')
echo "$SHELL_LOG_PREFIX Select random region: $DROPLET_REGION_ID"

# Get instance type
DROPLET_RECOMMEND_INSTANCE_DESCRIBE=$($ALYCLI_PATH ecs DescribeRecommendInstanceType --NetworkType vpc --RegionId $DROPLET_REGION_ID --Cores $DROPLET_CPU_CORES --Memory $DROPLET_MEMORY)
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX DescribeRecommendInstanceType Error: $DROPLET_RECOMMEND_INSTANCE_DESCRIBE"
    echo "$SHELL_LOG_PREFIX Sorry, $DROPLET_REGION_ID has no enough stock, please try again..."
    exit 1
fi
DROPLET_RECOMMEND_INSTANCE_TYPE=$(echo $DROPLET_RECOMMEND_INSTANCE_DESCRIBE | $JQCLI_PATH '.Data.RecommendInstanceType[0]')
echo "$SHELL_LOG_PREFIX Select recommend instance type: $DROPLET_RECOMMEND_INSTANCE_TYPE"
DROPLET_INSTANCE_TYPE_ID=$(echo $DROPLET_RECOMMEND_INSTANCE_TYPE | $JQCLI_PATH -r '.InstanceType.InstanceType')
DROPLET_ZONE_ID=$(echo $DROPLET_RECOMMEND_INSTANCE_TYPE | $JQCLI_PATH -r '.ZoneId')

# Get VPC
echo "$SHELL_LOG_PREFIX Query available VPC in $DROPLET_REGION_ID..."
DROPLET_VPC_QUERY=$($ALYCLI_PATH ecs DescribeVpcs --RegionId $DROPLET_REGION_ID | $JQCLI_PATH '.Vpcs.Vpc[0] | select(.Status == "Available")')
DROPLET_VPC_ID=""
DROPLET_VPC_CIDR_BLOCK="172.16.0.0/12"
if [[ -z $DROPLET_VPC_QUERY ]] || [ "$DROPLET_VPC_QUERY" == 'null' ]; then
    echo "$SHELL_LOG_PREFIX No available VPC in $DROPLET_REGION_ID, begin to create VPC..."
    DROPLET_VPC_CREATE=$($ALYCLI_PATH ecs CreateVpc --RegionId $DROPLET_REGION_ID --CidrBlock $DROPLET_VPC_CIDR_BLOCK)
    if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX CreateVpc Error: $DROPLET_VPC_CREATE"
        echo "$SHELL_LOG_PREFIX Create VPC failed, you can try again..."
        exit 1
    else
        DROPLET_VPC_ID=$(echo $DROPLET_VPC_CREATE | $JQCLI_PATH -r '.VpcId')
        echo "$SHELL_LOG_PREFIX Create VPC successful!"
    fi
else
    DROPLET_VPC_ID=$(echo $DROPLET_VPC_QUERY | $JQCLI_PATH -r '.VpcId')
	DROPLET_VPC_CIDR_BLOCK=$(echo $DROPLET_VPC_QUERY | $JQCLI_PATH -r '.CidrBlock')
fi
echo "$SHELL_LOG_PREFIX We will use this VPC: $DROPLET_VPC_ID"

# Get VSwitch
DROPLET_VSWITCH_QUERY=$($ALYCLI_PATH ecs DescribeVSwitches --RegionId $DROPLET_REGION_ID --ZoneId $DROPLET_ZONE_ID | $JQCLI_PATH '.VSwitches.VSwitch[0] | select(.Status == "Available")')
DROPLET_VSWITCH_ID=""
if [[ -z $DROPLET_VSWITCH_QUERY ]] || [ "$DROPLET_VSWITCH_QUERY" == "null" ]; then
    echo "$SHELL_LOG_PREFIX No available VSwitch in $DROPLET_ZONE_ID, begin to create VSwitch..."
	if [[ $DROPLET_ZONE_ID == *a ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.16.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *b ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.17.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *c ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.18.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *d ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.19.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *e ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.20.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *f ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.21.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *g ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.22.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *h ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.23.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *i ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.24.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *j ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.25.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *k ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.26.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *l ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.27.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *m ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.28.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *n ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.29.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *o ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.30.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *p ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.31.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *q ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.32.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *r ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.33.0.0/16"
    elif [[ $DROPLET_ZONE_ID == *s ]]; then
        DROPLET_VPC_SUB_CIDR_BLOCK="172.34.0.0/16"
    else
        echo "$SHELL_LOG_PREFIX Sorry, unknown zone, please contact taraxa devops..."
        exit 1
    fi
    echo "$SHELL_LOG_PREFIX VSwitch VPC Cidr Block: $DROPLET_VPC_SUB_CIDR_BLOCK"
    DROPLET_VSWITCH_CREATE=$($ALYCLI_PATH ecs CreateVSwitch --RegionId $DROPLET_REGION_ID --ZoneId $DROPLET_ZONE_ID --VpcId $DROPLET_VPC_ID --CidrBlock $DROPLET_VPC_SUB_CIDR_BLOCK)
    if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX CreateVSwitch Error: $DROPLET_VSWITCH_CREATE"
        echo "$SHELL_LOG_PREFIX Create VSwitch failed, you can try again..."
        exit 1
    else
        DROPLET_VSWITCH_ID=$(echo $DROPLET_VSWITCH_CREATE | $JQCLI_PATH -r '.VSwitchId')
        echo "$SHELL_LOG_PREFIX Creating VSwitch $DROPLET_VSWITCH_ID..."
        DROPLET_VSWITCH_CREATE_FLAG=0
		for((i=1;i<=3;i++));
        do
            sleep 6
            DROPLET_VSWITCH_CREATE_QUERY=$($ALYCLI_PATH ecs DescribeVSwitches --RegionId $DROPLET_REGION_ID --VSwitchId $DROPLET_VSWITCH_ID | $JQCLI_PATH '.VSwitches.VSwitch[] | select(.Status == "Available")')
            if [[ -n $DROPLET_VSWITCH_CREATE_QUERY ]]; then
                DROPLET_VSWITCH_CREATE_FLAG=1
                break
            fi
        done
		if [ "$DROPLET_VSWITCH_CREATE_FLAG" == 1 ]; then
            echo "$SHELL_LOG_PREFIX Create VSwitch successful!"
        else
            echo "$SHELL_LOG_PREFIX Creating VSwitch has wasting a lot of time, please try again, exiting..."
            exit 1
		fi
    fi
else
    DROPLET_VSWITCH_ID=$(echo $DROPLET_VSWITCH_QUERY | $JQCLI_PATH -r '.VSwitchId')
fi
echo "$SHELL_LOG_PREFIX We will use this VSwitch: $DROPLET_VSWITCH_ID"

# random name suffix
RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 4 ; echo '')
DROPLET_NAME=${DROPLET_BASE_NAME}-$RND_STR

# Create Droplet
DROPLET_INSTANCE_CREATE=$(${ALYCLI_PATH} ecs CreateInstance \
    --InstanceName ${DROPLET_NAME} \
    --HostName ${DROPLET_NAME} \
    --ImageId ${DROPLET_IMAGE_ID} \
    --RegionId ${DROPLET_REGION_ID} \
    --InstanceType $DROPLET_INSTANCE_TYPE_ID \
    --IoOptimized optimized \
    --VSwitchId $DROPLET_VSWITCH_ID \
    --UserData ${DROPLET_USERDATA_SCRIPT})
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX CreateInstance Error: $DROPLET_INSTANCE_CREATE"
    echo "$SHELL_LOG_PREFIX failed to create instance, you can resolve uppon error, and try again..."
    exit 1
fi
DROPLET_INSTANCE_ID=$(echo $DROPLET_INSTANCE_CREATE | $JQCLI_PATH -r '.InstanceId')
echo "$SHELL_LOG_PREFIX Create instance successful! instance id: $DROPLET_INSTANCE_ID"

# Allocate Public IP
echo "$SHELL_LOG_PREFIX Query available eip address..."
DROPLET_EIP_ADDRESS_QUERY=$($ALYCLI_PATH ecs DescribeEipAddresses --RegionId ${DROPLET_REGION_ID} --Status Available)
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX DescribeEipAddresses Error: $DROPLET_EIP_ADDRESS_QUERY"
    exit 1
fi
DROPLET_EIP_ADDRESS_ALLOCATION_ID=$(echo $DROPLET_EIP_ADDRESS_QUERY | $JQCLI_PATH -r '.EipAddresses.EipAddress[0].AllocationId')
if [[ -z $DROPLET_EIP_ADDRESS_ALLOCATION_ID ]] || [ "$DROPLET_EIP_ADDRESS_ALLOCATION_ID" == 'null' ]; then
    DROPLET_EIP_ADDRESS_CREATE=$($ALYCLI_PATH ecs AllocateEipAddress --RegionId $DROPLET_REGION_ID --Bandwidth 1)
    if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX AllocateEipAddress Error: $DROPLET_EIP_ADDRESS_CREATE"
        exit 1
    fi
    DROPLET_EIP_ADDRESS_ALLOCATION_ID=$(echo $DROPLET_EIP_ADDRESS_CREATE | $JQCLI_PATH -r '.AllocationId')
fi
DROPLET_EIP_ADDRESS_ASSOCIATE=$($ALYCLI_PATH ecs AssociateEipAddress --RegionId $DROPLET_REGION_ID --AllocationId $DROPLET_EIP_ADDRESS_ALLOCATION_ID --InstanceId $DROPLET_INSTANCE_ID)
if [ $? != 0 ]; then
	echo "$SHELL_LOG_PREFIX AssociateEipAddress Error: $DROPLET_EIP_ADDRESS_ASSOCIATE"
	exit 1
fi

# wait 3 minute, and try to start instance
echo "$SHELL_LOG_PREFIX try to start instance, it may need to wait 1 minutes..."
for((i=1;i<=6;i++));
do
	sleep 10
	$ALYCLI_PATH ecs StartInstance --InstanceId $DROPLET_INSTANCE_ID
	if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX failed to start instance, try again..."
    else
        echo "$SHELL_LOG_PREFIX Congratulation! start instance successful!"
        echo "$SHELL_LOG_PREFIX Recommend: you can connect ECS instance or send remote commands with Cloud Assistant."
        break
    fi
done
