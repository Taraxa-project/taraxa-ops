#!/bin/bash

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick-aws
USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
# Ubuntu Server 18.04 LTS 64bit (x86)
UBUNTU_AMI='ami-06d51e91cea0dac8d'
EC2_KEY='awskey'

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if ! [ -x "$(command -v aws)" ]; then
    echo 'aws cli is not installed, attempting to install'
    pip3 install awscli --upgrade --user || exit 1
fi    

# Test if AWS is configured
aws s3 ls &> /dev/null
if [ $? -ne 0 ]; then
    echo 'awscli is not configured please configure'
    aws configure
fi

# Get bootstrap script
curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${USERDATA_SCRIPT}


aws ec2 create-security-group --group-name TaraxaNodeSecurityGroup --description "Security Group for Taraxa node"
aws ec2 authorize-security-group-ingress --group-name TaraxaNodeSecurityGroup --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 run-instances   --image-id $UBUNTU_AMI --key-name $EC2_KEY --security-groups TaraxaNodeSecurityGroup --instance-type t2.micro  \
  --user-data file://$USERDATA_SCRIPT --count 1