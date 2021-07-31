#!/bin/bash

SHELL_LOG_PREFIX='[oneclick-linode]'

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick

DROPLET_USERDATA_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-userdata.sh
DROPLET_BASE_NAME=taraxa-node-oneclick
DROPLET_IMAGE_ID="linode/ubuntu20.04"
DROPLET_REGION_ID="ap-west"
# g6-standard-4: 4C/8G/160GB Storage
DROPLET_INSTANCE_TYPE_ID="g6-standard-4"
DROPLET_SCRIPT_NAME="taraxa-node-oneclick"

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

function detect_distro() {
    if [[ $OSTYPE == linux-android* ]]; then
        distro="termux"
    fi
    if [ -z "$distro" ]; then
        distro=$(ls /etc | awk 'match($0, "(.+?)[-_](?:release|version)", groups) {if(groups[1] != "os") {print groups[1]}}' 2> /dev/null)
    fi
    if [ -z "$distro" ]; then
        if [ -f "/etc/os-release" ]; then
            distro="$(source /etc/os-release && echo $ID)"
        elif [[ $OSTYPE == darwin* ]]; then
            distro="darwin"
        else 
            distro="invalid"
        fi
    fi
    echo "$SHELL_LOG_PREFIX detected distro: $distro."
}

function init_environ(){
    declare -a systems; systems=(
        arch
        debian
        ubuntu
        termux
        fedora
        redhat
        SuSE
        sles
        darwin
        alpine
    )
    for ((i=0;i<${#systems[*]};i++))
    do
        if [[ ${systems[$i]} == $distro ]];then
            INDEX=$i
        fi
    done

    declare -a backends; backends=(
        "pacman -S --noconfirm"
        "apt-get -y install"
        "apt -y install"
        "apt -y install"
        "yum -y install"
        "yum -y install"
        "zypper -n install"
        "zypper -n install"
        "brew install"
        "apk add"
    )
    INSTALL="${backends[$INDEX]}"

    if [ "$distro" == "termux" ]; then
        PYTHON="python"
        SUDO=""
    else
        PYTHON="python3"
        SUDO="sudo"
    fi
    PIP="pip"
    echo "$SHELL_LOG_PREFIX install command: $INSTALL, pip command: $PIP"
}

function install_deps(){
    if [ -n "$INSTALL" ];then
        for package in ${packages[@]}; do
            $SUDO $INSTALL $package
        done
    else
        echo "$SHELL_LOG_PREFIX We could not install dependencies."
        echo "$SHELL_LOG_PREFIX Please make sure you have python3, pip(or pip3) and linode-cli installed."
        exit
    fi
}

function download_bootstrap_script(){
    # Get current bootstrap script
    if [ ! -f "$DROPLET_USERDATA_SCRIPT" ]; then
        echo "$SHELL_LOG_PREFIX begin to download bootstrap script..."
        curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh --output ${DROPLET_USERDATA_SCRIPT}
        if [ $? != 0 ] || [ ! -f "$DROPLET_USERDATA_SCRIPT" ]; then
            echo "$SHELL_LOG_PREFIX download bootstrap script failed! You can try again."
            exit 1
        else
            echo "$SHELL_LOG_PREFIX download bootstrap script success!"
        fi
    else
        echo "$SHELL_LOG_PREFIX Found bootstrap script, we will use it."
    fi
    DROPLET_USERDATA_SCRIPT=$(cat "${DROPLET_USERDATA_SCRIPT}")
}

detect_distro
init_environ

# Check python
echo "$SHELL_LOG_PREFIX begin to check python..."
sleep 1
if ! [ -x "$(command -v python)" -o -x "$(command -v python3)" ]; then
    echo "$SHELL_LOG_PREFIX Not found python, begin to install python..."
    packages=($PYTHON $PYTHON-pip)
    install_deps
    if [ -x "$(command -v linode-cli)" ]; then
        echo "$SHELL_LOG_PREFIX Found linode cli, usually, this is problematic. begin to uninstall linode cli..."
        sleep 3
        $PIP uninstall -y linode-cli
    fi
else
    echo "$SHELL_LOG_PREFIX Found python!"
fi

# Check pip or pip3
echo "$SHELL_LOG_PREFIX begin to check pip env..."
sleep 1
if [ -x "$(command -v pip3)" ]; then
    echo "$SHELL_LOG_PREFIX Found pip3!"
	PIP="pip3"
elif [ -x "$(command -v pip)" ]; then
    echo "$SHELL_LOG_PREFIX Found pip!"
	PIP="pip"
else
    echo "$SHELL_LOG_PREFIX Not found pip or pip3, begin to install pip..."
    packages=($PYTHON-pip)
    install_deps
    if [ -x "$(command -v linode-cli)" ]; then
        echo "$SHELL_LOG_PREFIX Found linode cli, usually, this is problematic. begin to uninstall linode cli..."
        sleep 3
        $PIP uninstall -y linode-cli
    fi
fi

# Check linode cli
echo "$SHELL_LOG_PREFIX begin to check linode cli..."
sleep 3
if ! [ -x "$(command -v linode-cli)" ]; then
    echo "$SHELL_LOG_PREFIX Not found linode cli, begin to install linode cli..."
    $PIP install linode-cli
else
    echo "$SHELL_LOG_PREFIX Found linode cli!"
fi

# Check jq
echo "$SHELL_LOG_PREFIX begin to check jq..."
sleep 1
if ! [ -x "$(command -v jq)" ]; then
    echo "$SHELL_LOG_PREFIX Not found jq, begin to install jq..."
    packages=(jq)
    install_deps
else
    echo "$SHELL_LOG_PREFIX Found jq!"
fi

# Init cli and print cli version
linode-cli -v

# Get random region
DROPLET_REGION_LIST=$(linode-cli regions list --json --pretty | jq '.[] | select(true==contains({capabilities: ["Linodes"]})) | select(.status=="ok") | .id')
if [ $? == 0 ]; then
    echo "$SHELL_LOG_PREFIX Get region successfully!"
    LENGTH=$(echo $DROPLET_REGION_LIST | jq -s 'length')
    RANDOM_NUMBER=$(($RANDOM % $LENGTH))
    DROPLET_REGION_ID=$(echo $DROPLET_REGION_LIST | jq -r -s --arg RANDOM_NUMBER $RANDOM_NUMBER '.[$RANDOM_NUMBER|tonumber]')
else
    echo "$SHELL_LOG_PREFIX Sorry, get region failed, you can try again..."
    exit 1
fi
echo "$SHELL_LOG_PREFIX Select random region: $DROPLET_REGION_ID"

# Upload stackscript
download_bootstrap_script
DROPLET_SCRIPT_LIST=$(linode-cli stackscripts list --mine true --label "$DROPLET_SCRIPT_NAME" --json --pretty | jq '.[0]')
if [[ -z $DROPLET_SCRIPT_LIST ]] || [ "$DROPLET_SCRIPT_LIST" == 'null' ]; then
    echo "$SHELL_LOG_PREFIX begin to create stackscript..."
    DROPLET_SCRIPT_CREATE=$(linode-cli stackscripts create --label "$DROPLET_SCRIPT_NAME" --images "$DROPLET_IMAGE_ID" --script "$DROPLET_USERDATA_SCRIPT" --json --pretty | jq '.[0]')
    if [ $? != 0 ]; then
        echo "$SHELL_LOG_PREFIX Sorry, create stackscript failed, you can try again..."
        exit 1
    else
        DROPLET_SCRIPT_ID=$(echo $DROPLET_SCRIPT_CREATE | jq -r '.id')
    fi
else
    DROPLET_SCRIPT_ID=$(echo $DROPLET_SCRIPT_LIST | jq -r '.id')
fi
echo "$SHELL_LOG_PREFIX Select script id: $DROPLET_SCRIPT_ID"

# Get sshkeys
echo "$SHELL_LOG_PREFIX begin to check sshkeys..."
DROPLET_SSHKEY_NAME="sk-taraxa-node-oneclick"
DROPLET_SSHKEY_LIST=$(linode-cli sshkeys list --json --pretty | jq --arg DROPLET_SSHKEY_NAME $DROPLET_SSHKEY_NAME '.[] | select(.label==$DROPLET_SSHKEY_NAME)')
if [ -z "$DROPLET_SSHKEY_LIST" ] || [ "$DROPLET_SSHKEY_LIST" == 'null' ]; then
    echo "$SHELL_LOG_PREFIX There is no ssh public key for Taraxa node, begin to create sshkeys..."
    SSH_KEY_PATH=$(echo "$HOME/.ssh/taraxa_node_oneclick_rsa.pub")
    if [ -f $SSH_KEY_PATH ]; then
        echo "$SHELL_LOG_PREFIX found ~/.ssh/taraxa_node_oneclick_rsa.pub, we will use it."
    else
        echo "$SHELL_LOG_PREFIX begin to generate ssh key..."
        ssh-keygen -t rsa -b 4096 -P "" -f ~/.ssh/taraxa_node_oneclick_rsa -C "root"
    fi
    DROPLET_SSHKEY_CREATE_LIST=$(linode-cli sshkeys create --label "$DROPLET_SSHKEY_NAME" --ssh_key "$(cat ~/.ssh/taraxa_node_oneclick_rsa.pub)" --json --pretty | jq '.[0]')
    DROPLET_SSHKEY_PUBLIC_KEY=$(echo "$DROPLET_SSHKEY_CREATE_LIST" | jq -r '. | .ssh_key')
else
    DROPLET_SSHKEY_PUBLIC_KEY=$(echo "$DROPLET_SSHKEY_LIST" | jq -s -r '.[0] | .ssh_key')
fi
echo "$SHELL_LOG_PREFIX Select ssh public key: $DROPLET_SSHKEY_PUBLIC_KEY"

# random name suffix
RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 4 ; echo '')
DROPLET_NAME=${DROPLET_BASE_NAME}-$RND_STR

ROOT_PASS=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 12 ; echo '')
echo "$SHELL_LOG_PREFIX Note: root_pass is required, so we create a random password: $ROOT_PASS"

echo "$SHELL_LOG_PREFIX Creating instance server..."
# Create Droplet
linode-cli linodes create \
    --booted true \
    --root_pass $ROOT_PASS \
    --type "$DROPLET_INSTANCE_TYPE_ID" \
    --region "$DROPLET_REGION_ID" \
    --image "$DROPLET_IMAGE_ID" \
    --label "$DROPLET_NAME" \
    --tags "$DROPLET_BASE_NAME" \
    --stackscript_id $DROPLET_SCRIPT_ID \
    --authorized_keys "$DROPLET_SSHKEY_PUBLIC_KEY"
if [ $? != 0 ]; then
    echo "$SHELL_LOG_PREFIX Creating instance server failed!"
    exit 1
fi

echo "$SHELL_LOG_PREFIX Congratulation! create instance server successfully!"
