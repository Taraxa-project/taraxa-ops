#!/bin/bash

# this will probably change at some point
GOOGLE_CLOUD_SDK_VERSION=348.0.0

ARCH=$(uname -m)

GOOGLE_CLOUD_INSTALL_PATH=${HOME}/google-cloud-sdk
GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION=false

function install_with_apt () {
    echo "Attempting via apt"
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install google-cloud-sdk
}

function install_with_dnf () {
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
    echo "Installing to $GOOGLE_CLOUD_INSTALL_PATH"
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz
    tar -xvzf google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz --strip-components=1 -C ${GOOGLE_CLOUD_INSTALL_PATH}
}

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick
STARTUP_SCRIPT=${TARAXA_ONE_CLICK_PATH}/startup-script.sh

# TODO 
NODE_SKU=e2-standard-4 # 4 core, 16gb ram 
NODE_BASE_NAME=taraxa-node

RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 8 ; echo '')
GC_PROJECT_NAME=${NODE_BASE_NAME}-project-$RND_STR
GC_COMPUTE_ENGINE=${NODE_BASE_NAME}-compute-$RND_STR

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

echo "DEBUG arch: $ARCH p2: $PYTHON_INSTALLED p3: $PYTHON3_INSTALLED cli: $GC_CLI_INSTALLED manual: $GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION path: $GOOGLE_CLOUD_INSTALL_PATH"


if [ -z "$GC_CLI_INSTALLED" ]; then
    echo "Attempting to install Google Cloud SDK CLI"
    mkdir -p ${GOOGLE_CLOUD_INSTALL_PATH}
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
		    GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION=true
		fi
	    else
		echo "Success"
	    fi
	elif [ "$(grep -Ei 'rhel fedora' /etc/*release)" ]; then
	    install_with_dnf
	    if [ $? != 0 ]; then 
		echo "Sorry, install seems to have failed, trying another method"
		install_manually_linux
		if [ $? != 0 ]; then 
		    echo "Sorry, install seems to have failed."
		    exit 1
		else
		    echo "Success!"
		    GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION=true
		fi
		
	    else
		echo "Success!"
	    fi
	else
	    echo "Installing via script"
	    install_manually_linux
	    if [ $? != 0 ]; then 
		echo "Sorry, install seems to have failed."
		exit 1
	    else
		echo "Success!"
		GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION=true
	    fi
	fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	//curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-darwin-${ARCH}.tar.gz
	tar -xvzf google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-darwin-${ARCH}.tar.gz --strip-components=1 -C ${GOOGLE_CLOUD_INSTALL_PATH}
	GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION=true
    else
	echo "Your OS is currently not supported, sorry!"
	exit 1
    fi
fi

if [ "$GOOGLE_CLOUD_SDK_MANUAL_INSTALLATION" == "true" ]; then
    GCLOUD_COMMAND=${GOOGLE_CLOUD_INSTALL_PATH}/bin/gcloud
    else
	GCLOUD_COMMAND=gcloud
fi

GC_CLI_INSTALLED=$(${GCLOUD_COMMAND} version | grep 'Google Cloud SDK')

if [ -z "$GC_CLI_INSTALLED" ]; then
  echo "Sorry, install seems to have failed!"
  echo "Please follow instructions at Google Cloud SDK page to find a solution for your setup, or try another cloud provider"
  exit 1
fi

echo "-> A browser window will pop up. Please provide your Google Cloud account credentials to log in."
echo "-> If you have not created a Google Cloud account, please do so now."

# pop up a login window
${GCLOUD_COMMAND} auth login

if [ $? != 0 ]; then 
  echo "! Error logging in"
  exit 1
fi

echo "-> Updating components"

${GCLOUD_COMMAND} config set disable_usage_reporting true
${GCLOUD_COMMAND} components install beta --quiet
${GCLOUD_COMMAND} components update --quiet

echo "-> Creating a project $GC_PROJECT_NAME"

${GCLOUD_COMMAND} projects create ${GC_PROJECT_NAME}

if [ $? != 0 ]; then 
  echo "! Error creating project"
  exit 1
fi

${GCLOUD_COMMAND} config set project ${GC_PROJECT_NAME}

echo "-> Linking the project to a billing account"

BILLING_ACCOUNT=$(${GCLOUD_COMMAND} beta billing accounts list | egrep '(([A-Fa-z0-9]){6}-){2}([A-Fa-z0-9]){6}' | awk '{print substr($0, 0, 20)}')

if [ $? != 0 ]; then 
  echo "!! Error finding a billing account, make sure you've set up one at cloud.google.com"
  exit 1
fi

${GCLOUD_COMMAND} beta billing projects link ${GC_PROJECT_NAME} --billing-account ${BILLING_ACCOUNT}

echo "-> Enabling Compute Engine"

${GCLOUD_COMMAND} services enable compute.googleapis.com --project ${GC_PROJECT_NAME}

if [ $? != 0 ]; then 
  echo "!! Error setting up Compute Engine"
  exit 1
fi

# find a random region and a zone within the region

REGIONS=($(${GCLOUD_COMMAND} compute regions list | awk '{match($0, /([a-z]+-[a-z]+){1}[0-9]{1}/); print substr($0, RSTART, RLENGTH)}'))
GC_REGION=${REGIONS[$RANDOM % ${#REGIONS[@]}]}

echo "-> Setting up node in region $GC_REGION"

ZONES_IN_REGION=($(${GCLOUD_COMMAND} compute zones list --filter ${GC_REGION} | awk '{match($0, /([a-z]+-[a-z]+){1}[0-9]{1}-[a-z]{1}/); print substr($0, RSTART, RLENGTH)}'))
GC_ZONE=${ZONES_IN_REGION[$RANDOM % ${#ZONES_IN_REGION[@]}]}

echo "-> Zone selected $GC_ZONE"

${GCLOUD_COMMAND} config set compute/region ${GC_REGION}
${GCLOUD_COMMAND} config set compute/zone ${GC_ZONE}

curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${STARTUP_SCRIPT}

echo "-> Creating a Compute Engine"

echo "-> Setting up Firewall"
    
${GCLOUD_COMMAND} compute firewall-rules create ${GC_COMPUTE_ENGINE}-deny \
       --action=deny \
       --rules=tcp,udp \
       --priority=1000 \
       --project ${GC_PROJECT_NAME}

${GCLOUD_COMMAND} compute firewall-rules create ${GC_COMPUTE_ENGINE}-fw \
       --action=allow \
       --rules=tcp:22,tcp:3000,tcp:7777,tcp:8777,tcp:10002,udp:10002 \
       --priority=50 \
       --project ${GC_PROJECT_NAME}

${GCLOUD_COMMAND} compute instances create ${GC_COMPUTE_ENGINE} \
       --machine-type ${NODE_SKU} \
       --boot-disk-size 60GB \
       --image-project ubuntu-os-cloud \
       --image-family ubuntu-2004-lts \
       --zone ${GC_ZONE} \
       --metadata-from-file=startup-script=${STARTUP_SCRIPT} \
       --project ${GC_PROJECT_NAME}
       
if [ $? != 0 ]; then 
  echo "!! Error creating Compute Engine"
  exit 1
fi

echo "Take note of the EXTERNAL_IP given above, that is your node's public address"

# we can just directly get the script from github

if [ $? != 0 ]; then 
  echo "Error creating VM"
  exit 1
fi

echo "Complete! To login use gcloud compute ssh ${GC_COMPUTE_ENGINE} and generate your keys and run sudo docker ps to make sure your node is up and running"
echo "Note! It might take a while for the node to start"
echo "Afterwards you can use either above or ssh -i ~/.ssh/google_compute_engine <your-nodes-ip> to login"
