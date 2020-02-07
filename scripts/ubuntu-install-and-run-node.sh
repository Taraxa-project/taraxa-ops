#!/bin/bash

# Basic script to prepare a Ubuntu machine to run Taraxa Node using docker.
# This is initial developed to be used as startup script for cloud virtual machines to help new users to get a node running.

TARAXA_NODE_PATH=/opt/taraxa-node
TARAXA_NODE_BOOT_NODE_ADDRESS=35.193.111.190
TARAXA_NODE_CONF_PATH=${TARAXA_NODE_PATH}/conf_taraxa.json
TARAXA_NODE_DB_PATH=${TARAXA_NODE_PATH}/taraxadb
TARAXA_NODE_DOCKER_IMAGE=taraxa/taraxa-node:latest
TARAXA_FAUCET_ADDRESS=${TARAXA_NODE_BOOT_NODE_ADDRESS}
TARAXA_FAUCET_PORT=5000
TARAXA_LOCAL_RPC_PORT=7777
TARAXA_LOCAL_NODE_ADDRESS=localhost

TARAXA_NODE_CONF=$(cat <<EOF
{
  "node_secret": "TARAXA_NODE_NODE_SECRET",
  "vrf_secret": "TARAXA_NODE_VRF_SECRET",
  "db_path": "/taraxadb",
  "dag_processing_threads": 6,
  "network_address": "0.0.0.0",
  "network_listen_port": 10002,
  "network_simulated_delay": 0,
  "network_transaction_interval": 500,
  "network_encrypted" : 0,
  "network_performance_log" : 0,
  "network_bandwidth": 160,
  "network_ideal_peer_count" : 10,
  "network_max_peer_count" : 15,
  "network_sync_level_size" : 3,
  "network_boot_nodes": [
    {
      "id": "7b1fcf0ec1078320117b96e9e9ad9032c06d030cf4024a598347a4623a14a421d4f030cf25ef368ab394a45e920e14b57a259a09c41767dd50d1da27b627412a",
      "ip": "TARAXA_NODE_BOOT_NODE_ADDRESS",
      "port": 10002
    }
  ],
  "network_id": "testnet",
  "rpc_port": 7777,
  "ws_port": 8777,
  "test_params": {
    "block_proposer": [
      0,
      1,
      4000,
      4500
    ],
    "pbft": [
      2000,
      20,
      10000,
      5,
      1,
      10,
      0
    ]
  }
}
EOF
)

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
sudo apt-get install -y docker-ce docker-ce-cli containerd.io git jq

# Generate account
git clone https://github.com/vkobel/ethereum-generate-wallet.git /opt/ethereum-generate-wallet/
cd /opt/ethereum-generate-wallet
./ethereum-wallet-generator.sh > generated-account.txt

TARAXA_NODE_NODE_SECRET=$(grep Private /opt/ethereum-generate-wallet/generated-account.txt | cut -d':' -f2  | sed 's/ //g')
# Temporary hack to generate the VRF key
sudo docker pull ${TARAXA_NODE_DOCKER_IMAGE}
TARAXA_NODE_VRF_SECRET=$(sudo docker run --rm --entrypoint "/bin/bash" ${TARAXA_NODE_DOCKER_IMAGE} -c "./crypto_test --gtest_filter=CryptoTest.vrf_proof_verify | grep 'VRF' | awk ' NR==2 {print \$5}'")

# Get taraxa-ops repo
git clone https://github.com/Taraxa-project/taraxa-ops.git /opt/taraxa-ops/

#Generate config
sudo mkdir -p ${TARAXA_NODE_PATH}
echo ${TARAXA_NODE_CONF} | sudo tee ${TARAXA_NODE_CONF_PATH}
sudo sed -i s/TARAXA_NODE_BOOT_NODE_ADDRESS/${TARAXA_NODE_BOOT_NODE_ADDRESS}/g $TARAXA_NODE_CONF_PATH
sudo sed -i s/TARAXA_NODE_NODE_SECRET/${TARAXA_NODE_NODE_SECRET}/g $TARAXA_NODE_CONF_PATH
sudo sed -i s/TARAXA_NODE_VRF_SECRET/${TARAXA_NODE_VRF_SECRET}/g $TARAXA_NODE_CONF_PATH

# Pull Taraxa-Node
sudo docker pull ${TARAXA_NODE_DOCKER_IMAGE}

# Run Taraxa-Node
sudo docker run -d --name taraxa-node \
	-v ${TARAXA_NODE_DB_PATH}:/taraxadb \
	-v ${TARAXA_NODE_CONF_PATH}:/config/conf_taraxa.json \
	-e DEBUG=1 \
  -p 10002:10002 \
	-p 7777:7777 \
	-p 8777:8777 \
	-p 10002:10002/udp \
    --restart always \
	${TARAXA_NODE_DOCKER_IMAGE} --log-verbosity "3" --log-channels PBFT_CHAIN PBFT_MGR --conf_taraxa /config/conf_taraxa.json

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
