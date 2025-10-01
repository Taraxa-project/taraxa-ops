# Taraxa Node Running Repository
Taraxa node operation master repository

![Image of Taraxa Californicum](https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/taraxa_californicum.png)


# Running Taraxa-node with docker-compose

Clone the repository to your machine that has Docker installed.

Run the following command to start taraxa-node in a terminal:

```
cd taraxa_compose
docker-compose up
```

It can also be started as a background service:

```
cd taraxa_compose
docker-compose up -d
```

# Snapshot Management

The Taraxa node automatically downloads the latest blockchain snapshot on first start to speed up synchronization. The snapshot-puller container handles this process before the node starts.

## Default Behavior

By default, the snapshot-puller will:
- Check if the data directory already exists and has content
- If data exists, skip snapshot download and use existing data
- If data directory is empty, download the latest snapshot for your network and node type

## Configuration Options

You can customize the snapshot behavior using environment variables in your docker-compose.yml:

### Network Selection
```yaml
environment:
  - NETWORK=mainnet  # Options: mainnet (default) or testnet
```

### Node Type
```yaml
environment:
  - NODE_TYPE=light  # Options: light (default) or full
```

### Custom Snapshot URL
To use a specific snapshot instead of the latest:
```yaml
environment:
  - SNAPSHOT_URL=https://storage.googleapis.com/taraxa-snapshot/mainnet-light-db-block-19951895-20250723-044758.tar.gz
```

### Force Fresh Snapshot Download
If you have a corrupted database or want to start fresh, use the `DELETE_DATA` flag to remove existing data and download a new snapshot:
```yaml
environment:
  - DELETE_DATA=true  # Options: true or false (default)
```

**Warning:** Setting `DELETE_DATA=true` will permanently delete all existing blockchain data in your data directory before downloading a fresh snapshot.

## Light Node Performance Considerations

When running a light node (with `--light` flag), the initial pruning can take a significant amount of time as it processes and prunes historical data. If you don't want to wait for the long initial sync, you can:

1. Run your node **without** the `--light` flag (full node mode)
2. Periodically use `DELETE_DATA=true` to remove old data and download a fresh snapshot

This approach allows you to save disk space by regularly refreshing with the latest snapshot instead of maintaining full historical data, while avoiding the long sync times associated with light node initialization.

## Example Configurations

### Standard Light Node Configuration
```yaml
snapshot-puller:
  image: alpine:latest
  volumes:
    - ./data:/opt/taraxa_data/data
    - ./snapshot-init.sh:/snapshot-init.sh:ro
  environment:
    - NETWORK=mainnet
    - NODE_TYPE=light
    - DELETE_DATA=false
  command: /bin/sh /snapshot-init.sh
```

### Periodic Snapshot Refresh (Alternative to Light Node)
For users who want to save space without waiting for light node sync:
```yaml
snapshot-puller:
  image: alpine:latest
  volumes:
    - ./data:/opt/taraxa_data/data
    - ./snapshot-init.sh:/snapshot-init.sh:ro
  environment:
    - NETWORK=mainnet
    - NODE_TYPE=full
    - DELETE_DATA=true  # Set to true when you want to refresh with latest snapshot
  command: /bin/sh /snapshot-init.sh

node:
  # Run without --light flag for faster startup
  # Manually refresh snapshot periodically by setting DELETE_DATA=true and restarting
```

**Important:** After the snapshot is downloaded and your node is confirmed to be running successfully, it is **highly advisable to set `DELETE_DATA=false`**. Only switch it back to `true` when you intentionally want to force delete the data and download a fresh snapshot. Leaving `DELETE_DATA=true` permanently could result in unintended data loss on container restarts.

# Running Taraxa-node at Digital Ocean
You only need a Digital Ocean account to be able to run a Taraxa-node against the testnet.
Follow this instructions to get a Digital Ocean account https://www.digitalocean.com/docs/getting-started/sign-up/

## One Click Install
You need a Digital Ocean API token to use One Click Install.
Follow [here](https://www.digitalocean.com/docs/api/create-personal-access-token/) to get it.

You may export your token as the env var `DIGITALOCEAN_ACCESS_TOKEN` or insert it when script ask for it.

To have your Taraxa-node Runing just run:
```
$ bash -c "$(curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/one-click-DO.sh)"
```

Each time you run the script, a new droplet will be launched at Digital Ocean.

## Running it manually
Now lets create our `taraxa-node` droplet.

### Create the droplet
#TODO: Verify recommended resources

1.  From the  **Create**  menu in the top right of the  [control panel](https://cloud.digitalocean.com/), click  **Droplets**.
2.  Choose the Ubuntu 18.04.3 (LTS) x64 image.
3.  Choose a  [plan and size](https://www.digitalocean.com/docs/droplets/#plans-and-pricing)  for your Droplet, which determines its RAM, disk space, and vCPUs as well as its price. Learn more about  [how to choose the right Droplet plan](https://www.digitalocean.com/docs/droplets/resources/choose-plan/). We recommend at least 2GB of RAM.
5.  Choose a  [datacenter region](https://www.digitalocean.com/docs/droplets/#regional-availability). It can be any one available.
6.  Select additional options `User Data` and add this [script](https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh) content to the `User Data` field bellow.
7.  Choose an  [SSH key](https://www.digitalocean.com/docs/droplets/how-to/add-ssh-keys/), if you’ve added one. If you choose not to use SSH keys, your Droplet’s password will be emailed to you after creation.
8.  Enter a name and click  **Create**. We suggest `taraxa-node`

### Connect to Droplets

To connect by using a terminal on Linux, macOS, or Windows Subsystem for Linux:

1.  Open your terminal, and enter the command  `ssh root@203.0.113.0`.
    Substitute in your Droplet’s IP address after the `@`.
2.  Press  `ENTER`  and answer  `yes`  to the prompt that confirms the connection.
3.  If you’re not using SSH keys, enter your password when prompted.

Windows users can alternatively  [connect with PuTTY](https://www.digitalocean.com/docs/droplets/how-to/connect-with-ssh/putty/).
When you’ve logged in, your command prompt changes and you’ll see a welcome screen.

### Read Taraxa-node logs
Run this command after connected to the Droplet.

```
docker logs taraxa-node
```

If you wish to tail the logs, add `-f` to the command above. **Ctrl**-**C** is needed to stop the tail.

# Interacting with your node and the Network.
#TODO

# Running Taraxa-node at AWS
You only need an EC2 instance at AWS in order to run a Taraxa-node. To get started with AWS EC2 see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html

## One Click Install
You need an AWS account with configured credentials. If you'd like the ability to ssh into your EC2 instance you will need to setup an ssh key for use with EC2, follow these [instructions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair).

To have your Taraxa-node running just run:
```
$ bash -c "$(curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/one-click-AWS.sh)"
```
or if you already have an ssh key to use with your Taraxa-node, run the command and pass in the name of your ssh key:
```
$ bash -c "$(curl -fsSL https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/one-click-AWS.sh)" {KEYNAME}
```
Each time you run the script a new ec2 instance will be created.
