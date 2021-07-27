#!/bin/bash

CPU_COUNT=4
MEMORY=8
GCP_ZONE=us-central1-a
GCP_IMAGE_FAMILY=ubuntu-2004-lts
GCP_DISK_TYPE=pd-ssd
GCP_DISK_SIZE=20GB

if ! [[ -x "$(command -v gcloud)" ]]; then
  curl https://sdk.cloud.google.com > install.sh
  bash install.sh --disable-prompts
  gcloud components install beta --quiet
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ $OS == 'linux' ]]; then
  source $HOME/.bashrc
elif [[ "$OS" == 'darwin' ]]; then
  source $HOME/google-cloud-sdk/path.bash.inc
fi

if ! (gcloud auth list | grep -A5 ACTIVE | grep \*); then
  gcloud auth login --no-launch-browser
fi

echo 'Please enter Google Billing ID to be used for the Taraxa node project. e.g: A0PDF1-BMXF03-CFS491'
read -p 'Billing account: ' BILLING_ACC

if ! (gcloud beta billing accounts list | grep $BILLING_ACC)
 then echo "Unable to find billing ID $BILLING_ACC"; exit 1
fi


((RND=RANDOM|RANDOM))
PROJECT_NAME=(taraxa-${RND: -3})

gcloud projects create --name="$PROJECT_NAME" --quiet

PROJECT_ID=$(gcloud projects list | grep $PROJECT_NAME | awk '{print $1}')

echo 'Project ID: $PROJECT_ID'

echo 'Linking your billing account to project $PROJECT_ID'
gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ACC

echo 'Enabling Compute API'
gcloud services enable compute.googleapis.com --project=$PROJECT_ID

echo 'Configuring firewall'
gcloud compute firewall-rules create allow-taraxa \
	--allow tcp:3000,tcp:7777,tcp:8777,tcp:10002,udp:10002 \
    --project=$PROJECT_ID 

echo 'Creating instance'
gcloud compute instances create taraxa-node-1 \
	--project=$PROJECT_ID \
    --custom-cpu=$CPU_COUNT \
    --custom-memory=$MEMORY \ 
	--zone=$GCP_ZONE \
	--image-project=ubuntu-os-cloud \
	--image-family=$GCP_IMAGE_FAMILY \
	--boot-disk-type=$GCP_DISK_TYPE \
	--boot-disk-size=$GCP_DISK_SIZE

echo 'Installing Taraxa node'
gcloud compute ssh taraxa-node-1 --project=$PROJECT_ID \
	-- 'curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ubuntu-install-and-run-node.sh; chmod +x ubuntu-install-and-run-node.sh;  ./ubuntu-install-and-run-node.sh'
