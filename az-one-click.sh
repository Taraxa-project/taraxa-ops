#!/bin/bash

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick
NODE_SKU=F4 # 4 core, 8gb ram
NODE_BASE_NAME=taraxa-node-az-oneclick
NODE_BOOTSTRAP_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-node.sh

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

echo "Checking for Azure CLI..."
AZ_CLI_INSTALLED=$(az version | grep azure-cli)


if [ -z "$AZ_CLI_INSTALLED" ]; then
       	echo "az cli not installed - installing"	
	curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
	echo "az cli installed"
fi

echo "A browser window will pop up. Please provide your Azure account credentials to log in. (Do check the url corresponds to login.microsoftonline.com)"
echo "If you have not created an Azure account, please do so now."

az login

LOCATIONS=($(az account list-locations | grep name | awk -F : '{match($2, /[a-z]+/); print substr($2, RSTART, RLENGTH)}'))
echo "Setting you up at a location: ${LOCATIONS[$RANDOM % ${#LOCATIONS[@]}]}"

# az group create --name TaraxaNode 
# Get current bootstrap script

curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${NODE_BOOTSTRAP_SCRIPT}

# az vm create 
