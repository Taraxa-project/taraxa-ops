#!/bin/bash

# Basic script to prepare a Ubuntu machine to run Taraxa Node using docker.
# This is initial developed to be used as startup script for cloud virtual machines to help new users to get a node running.

TARAXA_NODE_PATH=/opt/taraxa-node
TARAXA_NODE_DOCKER_IMAGE=taraxa/taraxa-node:latest
TARAXA_FAUCET_ADDRESS=${TARAXA_NODE_BOOT_NODE_ADDRESS}
TARAXA_FAUCET_PORT=5000
TARAXA_LOCAL_RPC_PORT=7777
TARAXA_LOCAL_NODE_ADDRESS=localhost

# Install docker and tools
sudo apt-get remove -y docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install -y \
	apt-transport-https \
	ca-certificates \
	curl \
	gnupg-agent \
	software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
	"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) \
	stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io git jq npm

# Install taraxa-cli
npm install -g taraxa-cli

# Get taraxa-ops repo
git clone https://github.com/Taraxa-project/taraxa-ops.git /opt/taraxa-ops/

#Generate config
taraxa -n testnet -d $TARAXA_NODE_PATH

# Pull Taraxa-Node
sudo docker pull ${TARAXA_NODE_DOCKER_IMAGE}

# Run Taraxa-Node
sudo docker run -d --name taraxa-node \
	-v ${TARAXA_NODE_PATH}:/taraxa \
	-e DEBUG=1 \
    -p 10002:10002 \
	-p 7777:7777 \
	-p 8777:8777 \
	-p 10002:10002/udp \
    --restart always \
	${TARAXA_NODE_DOCKER_IMAGE} --conf_taraxa /taraxa/conf/testnet.json

# Ask for coins
MY_ADDRESS=$(grep Address /opt/ethereum-generate-wallet/generated-account.txt | cut -d':' -f2 | sed 's/     0x//g')
curl -d '{"address": "'${MY_ADDRESS}'"}' -H "Content-Type: application/json" -X POST http://${TARAXA_FAUCET_ADDRESS}:${TARAXA_FAUCET_PORT}/nodes/new

# Wait if port isn't ready
nc -z localhost ${TARAXA_LOCAL_RPC_PORT} || sleep 10

# Add Transaction to self
export RECV_ADDRESS=${MY_ADDRESS}
export RPC_PORT=${TARAXA_LOCAL_RPC_PORT}
export NODE=${TARAXA_LOCAL_NODE_ADDRESS}
#python3 /opt/taraxa-ops/scripts/send_coins_to_self.py
#nohup python3 /opt/taraxa-ops/scripts/send_coins_to_self.py > send_coins_to_self.log &

# Add scripts folder to PATH for root user
echo 'export PATH=$PATH:/opt/taraxa-ops/scripts' >> /root/.profile
