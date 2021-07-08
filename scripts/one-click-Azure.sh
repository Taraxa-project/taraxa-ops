#!/bin/bash

function install_homebrew () {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $? != 0 ]; then 
    echo "Install failed, sorry."
    exit 1
  else
    echo "Installation success!"
  fi
}

function install_azurecli () {
  brew install azure-cli
  if [ $? != 0 ]; then 
    echo "Install failed, sorry."
    exit 1
  else
    echo "Installation success!"
  fi
}

TARAXA_ONE_CLICK_PATH=${HOME}/taraxa-node-oneclick
NODE_SKU=F4 # 4 core, 8gb ram
NODE_BASE_NAME=taraxa-node-az-oneclick
NODE_BOOTSTRAP_SCRIPT=${TARAXA_ONE_CLICK_PATH}/bootstrap-node.sh

RND_STR=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 8 ; echo '')
AZ_GROUP_NAME=${NODE_BASE_NAME}-group-$RND_STR
AZ_APP_SERVICE_NAME=${NODE_BASE_NAME}-app-$RND_STR

mkdir -p ${TARAXA_ONE_CLICK_PATH}
cd ${TARAXA_ONE_CLICK_PATH}

echo "Checking for Azure CLI..."
AZ_CLI_INSTALLED=$(az version | grep azure-cli)

if [ -z "$AZ_CLI_INSTALLED" ]; then
  echo "az cli not installed - installing"
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]; then
      echo "Attempting via script"
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      if [ $? != 0 ]; then 
        echo "Sorry, install seems to have failed"
        exit 1
      else
        echo "Success"
      fi
    else

      echo "Installing via script"
      curl -L https://aka.ms/InstallAzureCli | bash
      if [ $? != 0 ]; then 
        echo "Sorry, install seems to have failed."
        exit 1
      else
        echo "Success!"
      fi
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    BREW_INSTALLED=$(brew --version | grep Homebrew)
    if [ -z "$BREW_INSTALLED" ]; then 
      echo "Homebrew not detected, attempting to install"
      XCODE_CLT_INSTALLED=$(xcode-select --version)
      if [ -z "$XCODE_CLT_INSTALLED" ]; then 
        echo "XCode Command Line Tools not detected, attempting install those first"
        xcode-select --install

        if [ $? != 0 ]; then
          echo "Install failed, please try to install the tools manually"
          exit 1
        else 
          echo "Xcode command line tools installed!"
          install_homebrew
          install_azurecli
        fi
      else
        echo "Xcode command line tools found"
        install_homebrew
        install_azurecli
      fi
    else
      echo "Found homebrew, installing azure-cli"
      install_azurecli
    fi
  else
    echo "Your OS is currently not supported"
    exit 1
  fi
else
  echo "az cli installed"
fi

AZ_CLI_INSTALLED=$(az version | grep azure-cli)

if [ -z "$AZ_CLI_INSTALLED" ]; then
  echo "Sorry, install seems to have failed!"
  echo "Please follow instructions at microsoft azure to find a solution for your setup, or try another cloud provider"
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
