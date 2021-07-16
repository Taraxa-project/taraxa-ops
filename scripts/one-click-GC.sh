#!/bin/bash

GOOGLE_CLOUD_SDK_VERSION=348.0.0

ARCH=$(uname -m)

GOOGLE_CLOUD_INSTALL_PATH=${HOME}/google-cloud-sdk

function install_with_apt () {
    echo "Attempting via apt"
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install google-cloud-sdk
}

function install_centos () {
    echo "Attempting via dnf"
    sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
    sudo dnf install google-cloud-sdk
}

function install_manually_linux () {
    echo "Installing via general install"
    mkdir -p ${GOOGLE_CLOUD_INSTALL_PATH}
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz
    tar -xvzf google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz -C ${GOOGLE_CLOUD_INSTALL_PATH}
}

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick

# TODO 
NODE_SKU=F4 # 4 core, 8gb ram 
NODE_BASE_NAME=taraxa-node-gc-oneclick
NODE_BOOTSTRAP_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-node.sh

RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 8 ; echo '')
AZ_GROUP_NAME=${NODE_BASE_NAME}-group-$RND_STR
AZ_APP_SERVICE_NAME=${NODE_BASE_NAME}-app-$RND_STR

echo "Checking for Python..."
PYTHON_INSTALLED=$(python --version | grep Python)
PYTHON3_INSTALLED=$(python3 --version | grep Python)

if [ -z "$PYTHON_INSTALLED" ] && [ -z "$PYTHON3_INSTALLED" ]; then
    echo "You need to have either Python 3.5 to 3.8 installed or, not recommended, Python 2.7.9 or higher"
    exit 1
else
    echo "Found $PYTHON3_INSTALLED $PYTHON_INSTALLED"
fi

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

echo "Checking for Google Cloud SDK CLI..."
GC_CLI_INSTALLED=$(gcloud version | grep 'Google Cloud SDK')

echo "DEBUG arch: $ARCH p2: $PYTHON_INSTALLED p3: $PYTHON3_INSTALLED cli: $GC_CLI_INSTALLED"

if [ -z "$GC_CLI_INSTALLED" ]; then
    echo "Attempting to install Google Cloud SDK CLI"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	if [ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]; then
	    install_with_apt
	    gcloud version
	    if [ $? != 0 ]; then 
		echo "Sorry, install seems to have failed, trying another method"
		install_manually_linux
		if [ $? != 0 ]; then 
		    echo "Sorry, install seems to have failed."
		    exit 1
		else
		    echo "Success!"
		fi
	    else
		echo "Success"
	    fi
	else
	    echo "Installing via script"
	    install_manually_linux
	    if [ $? != 0 ]; then 
		echo "Sorry, install seems to have failed."
		exit 1
	    else
		echo "Success!"
	    fi
	fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-darwin-${ARCH}.tar.gz
	
    else
	echo "Your OS is currently not supported, sorry!"
	exit 1
    fi
fi

if [ 1 -eq 0 ]; then

GC_CLI_INSTALLED=$(gcloud version | grep 'Google Cloud SDK')

if [ -z "$GC_CLI_INSTALLED" ]; then
  echo "Sorry, install seems to have failed!"
  echo "Please follow instructions at Google Cloud SDK page to find a solution for your setup, or try another cloud provider"
  exit 1
fi

echo "A browser window will pop up. Please provide your Azure account credentials to log in. (Do check the url corresponds to login.microsoftonline.com)"
echo "If you have not created an Azure account, please do so now."

# pop up a login window
az login

if [ $? != 0 ]; then 
  echo "Error logging in"
  exit 1
fi

# find a random location
LOCATIONS=($(az account list-locations | grep name | awk -F : '{match($2, /[a-z]+/); print substr($2, RSTART, RLENGTH)}'))

if [ $? != 0 ]; then 
  echo "Error finding location"
  exit 1
fi

AZ_LOCATION=${LOCATIONS[$RANDOM % ${#LOCATIONS[@]}]}

echo "Setting you up at a location: ${AZ_LOCATION}"

echo "Creating a resource group ${AZ_GROUP_NAME}"

# it's not guaranteed that every location can create a group, so loop until we get one that can (should not take long unless RNG)
while true; do

FAILURE=$(az group create --name ${AZ_GROUP_NAME} --location ${AZ_LOCATION} | grep LocationNotAvailableForResourceGroup)

if [ -z "$FAILURE" ]; then
    break
fi 

done

echo "Creating an App Service ${AZ_APP_SERVICE_NAME}"

az vm create --resource-group ${AZ_GROUP_NAME} --name ${AZ_APP_SERVICE_NAME} --image UbuntuLTS --generate-ssh-keys --size Standard_F4

if [ $? != 0 ]; then 
  echo "Error creating resource group"
  exit 1
fi

echo "Take note of the publicIPAddress given above, that is your node's public address"

echo "Bootstrapping your node"

# we can just directly get the script from github
az vm extension set \
  --resource-group ${AZ_GROUP_NAME} \
  --vm-name ${AZ_APP_SERVICE_NAME} --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh"],"commandToExecute": "./ubuntu-install-and-run-node.sh"}' > /dev/null

if [ $? != 0 ]; then 
  echo "Error creating VM"
  exit 1
fi

# open ports
az vm open-port --resource-group ${AZ_GROUP_NAME} --name ${AZ_APP_SERVICE_NAME} --port 3000,7777,8777,10002 > /dev/null

if [ $? != 0 ]; then 
  echo "Error opening ports"
  exit 1
fi

echo "Complete! Use ssh <your-nodes-ip> to login and run sudo docker ps to make sure your node is up and running"
fi
