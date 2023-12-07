#!/bin/bash

NODETYPE="testnet"

if [[ "$0" == "mainnet" || "$1" == "mainnet" || "$2" == "mainnet" ]]; then
    NODETYPE="mainnet"
fi

if [[ "$0" == "light" || "$1" == "light" || "$2" == "light" ]]; then
    NODETYPE+="-light"
fi

SHELL_LOG_PREFIX='[taraxa-oneclick-aws]'

BASE_NAME=taraxa-node-oneclick
TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick-aws
AWS_PATH=${TARAXA_ONE_CLICK_PATH}/aws/bin/aws
USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
# SSH KEY to connect to crated instance
AWS_KEY_NAME="taraxa-node-keypair"
# t2.xlarge - 4 CPU + 16 GB RAM + EBS SSD
AWS_INSTANCE=t2.xlarge
# just in case no default region is configured
export AWS_DEFAULT_REGION=us-east-1

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

function check_deps() {
    if ! [ -x "$(command -v jq)" -a -x "$(command -v unzip)" ]; then
        echo $SHELL_LOG_PREFIX installing depencies
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get install -y unzip jq
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install jq unzip
        elif [ -x "$(command -v brew)" ]; then
            # skip for unzip on mac
            brew install jq
        else
            echo "$SHELL_LOG_PREFIX Error! You should install jq and unzip on your system"
            exit 1
        fi
    fi
}

check_deps

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS" == "darwin" ]; then
    AWS_PATH=/usr/local/bin/aws
    if ! [ -x "$(command -v aws)" ]; then
        echo "$SHELL_LOG_PREFIX begin to download aws cli..."
        curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o AWSCLIV2.pkg
        sudo installer -pkg AWSCLIV2.pkg -target /
    else
        echo $SHELL_LOG_PREFIX awscli already installed
    fi
elif [ "$OS" == "linux" ]; then
    echo "$SHELL_LOG_PREFIX begin to download aws cli..."
    ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
    case "$ARCH" in
        "x86_64" ) ARCH="x86_64";;
        "arm64"  ) ARCH="aarch64";;
        *) echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your ARCH $ARCH."
           exit 2 ;;
    esac
    if ! [ -x $AWS_PATH ]; then
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-${OS}-${ARCH}.zip" -o awscli2.zip
        unzip awscli2.zip
        $TARAXA_ONE_CLICK_PATH/aws/install -i $TARAXA_ONE_CLICK_PATH/aws/installed -b $TARAXA_ONE_CLICK_PATH/aws/bin
    else
        echo $SHELL_LOG_PREFIX aws cli already installed
    fi
else
    echo "$SHELL_LOG_PREFIX sorry, the script is not suitable for your operating system."
    exit 1
fi

AWS_CLI_INSTALLED=$($AWS_PATH --version | grep aws-cli)

if [ -z "$AWS_CLI_INSTALLED" ]; then
  echo "Sorry, install seems to have failed!"
  echo "Please follow instructions at https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html \
  to find a solution for your setup, or try another cloud provider"
  exit 3
fi

# Test if AWS is configured
$AWS_PATH s3 ls &> /dev/null
if [ $? -ne 0 ]; then
    echo "$SHELL_LOG_PREFIX awscli is not configured please configure"
    $AWS_PATH configure
fi

# Get current bootstrap script
curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${USERDATA_SCRIPT}
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX download bootstrap script failed! You can try again."
    exit 1
else
    echo "$SHELL_LOG_PREFIX download bootstrap script success!"
fi

# Set the node type in the ubuntu install script
SCRIPT_CONTENT=$(cat "${USERDATA_SCRIPT}")
SCRIPT_CONTENT=${SCRIPT_CONTENT//"REPLACEWITHNODETYPE"/"$NODETYPE"}
echo "$SCRIPT_CONTENT" > ${USERDATA_SCRIPT}


# Setting random region
REGIONS=($($AWS_PATH ec2 describe-regions --output json \
| jq '.Regions[] | select(.OptInStatus=="opt-in-not-required" or .OptInStatus=="opted-in") | .RegionName' \
| sed 's/"//g'))
export AWS_DEFAULT_REGION=${REGIONS[$RANDOM % ${#REGIONS[@]}]}
echo "$SHELL_LOG_PREFIX Creating taraxa node in $AWS_DEFAULT_REGION region"

# Find ubuntu focal image
AWS_IMAGE_AMI=$($AWS_PATH ec2 describe-images \
--filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20210621" | \
jq ".Images[0] | .ImageId" | sed 's/"//g')
#echo "SELECTED $AWS_IMAGE_AMI"

# access keypair generation
AWS_KEY_PATH=$TARAXA_ONE_CLICK_PATH/${AWS_KEY_NAME}_${AWS_DEFAULT_REGION}_private.pem
echo "$SHELL_LOG_PREFIX generating key-pair to access your node"
$AWS_PATH ec2 describe-key-pairs --key-name $AWS_KEY_NAME &> /dev/null || \
$AWS_PATH ec2 create-key-pair --key-name $AWS_KEY_NAME --query 'KeyMaterial' --output text > $AWS_KEY_PATH
chmod 400 $AWS_KEY_PATH
echo "$SHELL_LOG_PREFIX WARNING! please save file $AWS_KEY_PATH it will be required to connect to your node via SSH later"

$AWS_PATH ec2 create-security-group --group-name TaraxaNodeSecurityGroup --description "Security Group for Taraxa node" &> /dev/null
# Export SSH and all ports required for the taraxa node
$AWS_PATH ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol tcp --port 22 --cidr 0.0.0.0/0 &> /dev/null
$AWS_PATH ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol tcp --port 3000 --cidr 0.0.0.0/0 &> /dev/null
$AWS_PATH ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol tcp --port 7777 --cidr 0.0.0.0/0 &> /dev/null
$AWS_PATH ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol tcp --port 8777 --cidr 0.0.0.0/0 &> /dev/null
$AWS_PATH ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol tcp --port 10002 --cidr 0.0.0.0/0 &> /dev/null
$AWS_PATH ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol udp --port 10002 --cidr 0.0.0.0/0 &> /dev/null

# RUN IT
$AWS_PATH ec2 run-instances --image-id $AWS_IMAGE_AMI --key-name $AWS_KEY_NAME --security-groups TaraxaNodeSecurityGroup \
  --instance-type $AWS_INSTANCE \
  --user-data file://$USERDATA_SCRIPT --count 1 --output json > $TARAXA_ONE_CLICK_PATH/created_instance_data.json

if [ $? -ne 0 ]; then
   echo $SHELL_LOG_PREFIX Error creating EC2 instance on $AWS_DEFAULT_REGION region.
   exit 4
fi

INSTANCE_ID=$(jq ".Instances[0] | .InstanceId" $TARAXA_ONE_CLICK_PATH/created_instance_data.json | sed 's/"//g')
echo -n $SHELL_LOG_PREFIX Node creation request is approved, waiting 20 seconds while node is starting
for i in `seq 1 20`; do echo -n '.'; sleep 1; done
echo

PUBLIC_IP=$($AWS_PATH ec2 describe-instances --filter "Name=instance-id,Values=$INSTANCE_ID" --output json | \
jq ".Reservations[0].Instances[0].PublicIpAddress" | sed 's/"//g')

echo $SHELL_LOG_PREFIX Node $INSTANCE_ID is created in $AWS_DEFAULT_REGION region with public IP $PUBLIC_IP
echo $SHELL_LOG_PREFIX You can try to connect to your node with 
echo
echo ssh -i $AWS_KEY_PATH -l ubuntu $PUBLIC_IP
echo
echo $SHELL_LOG_PREFIX You also can check status of the node with command 
echo $AWS_PATH ec2 describe-instance-status --instance-id $INSTANCE_ID --region $AWS_DEFAULT_REGION
echo
echo $SHELL_LOG_PREFIX To delete created instance, run
echo $AWS_PATH ec2 terminate-instances --instance-id $INSTANCE_ID --region $AWS_DEFAULT_REGION
echo
echo $SHELL_LOG_PREFIX Completed
