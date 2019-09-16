# taraxa-ops
Taraxa node operation master repository

# Runing Taraxa-node at Digital Ocean
You only need a Digital Ocean account to be able to run a Taraxa-node against the testnet.
Follow this instructions to get a Digital Ocean account https://www.digitalocean.com/docs/getting-started/sign-up/

## One Click Install
You need a Digital Ocean API token to use One Click Install.
Follow [here](https://www.digitalocean.com/docs/api/create-personal-access-token/) to get it.

You may export your token as the env var `DIGITALOCEAN_ACCESS_TOKEN` or insert it when script ask for it.

To have your Taraxa-node Runing just run:
```
$ bash -c "$(wget -O -  https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/one-click-DO.sh)"
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
