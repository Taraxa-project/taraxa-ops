#!/bin/bash

# Basic script to prepare a Ubuntu machine to run Taraxa Node using docker.
# This is initial developed to be used as startup script for cloud virtual machines to help new users to get a node running.

TARAXA_NODE_PATH=/var/taraxa

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
cd ~/taraxa-ops-master/taraxa_compose
sudo docker-compose up -d