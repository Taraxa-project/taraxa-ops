#!/bin/bash

# Basic script to prepare a Ubuntu machine to run Taraxa Node using docker.
# This is initial developed to be used as startup script for cloud virtual machines to help new users to get a node running.

# nodetype should be one of the cases below:
# mainnet, mainnet-light, testnet, testnet-light
NODETYPE="REPLACEWITHNODETYPE"

case $NODETYPE in

	"mainnet")
		echo "Will create a mainnet node"
		;;

	"mainnet-light")
		echo "Will create a mainnet light node"
		;;

	"testnet")
		echo "Will create a testnet node"
		;;

	"testnet-light")
		echo "Will create a testnet light node"
		;;
esac

# Install Docker
wget -O get-docker.sh https://get.docker.com
sudo sh get-docker.sh
sudo apt install -y docker-compose
rm -f get-docker.sh

# Download Taraxa Scripts
cd ~/
wget https://github.com/Taraxa-project/taraxa-ops/archive/refs/heads/master.zip
sudo apt install -y unzip
unzip master.zip
rm -f master.zip

# Start Taraxa container
case nodetype in

	"mainnet")
		cd ~/taraxa-ops-master/taraxa_compose_mainnet
		sudo docker compose -f docker-compose.yml up -d
		;;

	"mainnet-light")
		cd ~/taraxa-ops-master/taraxa_compose_mainnet
		sudo docker compose -f docker-compose.light.yml up -d
		;;

	"testnet")
		cd ~/taraxa-ops-master/taraxa_compose
		sudo docker compose -f docker-compose.yml up -d
		;;

	"testnet-light")
		cd ~/taraxa-ops-master/taraxa_compose
		sudo docker compose -f docker-compose.light.yml up -d
		;;
esac