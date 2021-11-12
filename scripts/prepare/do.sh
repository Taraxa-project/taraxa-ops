#!/bin/bash

VOLUME=`ls /dev/disk/by-id | awk '{print $1}'`

sudo mkfs.ext4 /dev/disk/by-id/${VOLUME}
sudo mkdir -p /var/lib/docker

sudo mount -o discard,defaults,noatime /dev/disk/by-id/${VOLUME} /var/lib/docker
echo "/dev/disk/by-id/${VOLUME} /var/lib/docker ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab

wget -O ubuntu-install-and-run-node.sh https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh
sudo sh ubuntu-install-and-run-node.sh
rm -f ubuntu-install-and-run-node.sh