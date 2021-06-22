import click
import digitalocean
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
import random
import string
import time
from eth_account import Account
from eth_utils.curried import keccak

DROPLET_BASE_NAME = "taraxa-node-oneclick"
DROPLET_SIZE = "c-4"
DROPLET_IMAGE = "ubuntu-20-04-x64"
DROPLET_USER_DATA_SCRIPT = "https://raw.githubusercontent.com/Taraxa-project/taraxa-ops/master/scripts/ubuntu-install-and-run-node.sh"


@click.group()
def cli():
    """DigitalOcean Testnet CLI"""
    pass


@cli.command()
@click.option('--nodes', default=1, help='Number of nodes')
@click.option('--project', default=None, help='Project')
@click.option('--explorer-key', default=None, help='Explorer private key for delegation')
def create(nodes, project=None, explorer_key=None):
    if explorer_key is None:
        print("The explorer key is required.")
        quit(1)

    manager = get_manager()

    check_auth(manager)
    project = check_project(manager, project)
    user_data = get_user_data()

    regions = get_regions(manager)

    droplets = []
    for i in range(0, nodes):
        name = ''.join(random.choice(string.ascii_letters) for x in range(6))
        region = random.choice(regions)
        droplet = digitalocean.Droplet(name=f'{DROPLET_BASE_NAME}-{name}',
                                       region=region,
                                       image=DROPLET_IMAGE,
                                       size_slug=DROPLET_SIZE,
                                       user_data=user_data,
                                       backups=False)
        droplet.create()
        droplet.load()
        project.assign_resource([f'do:droplet:{droplet.id}'])

        droplets.append(droplet)

    print('Waiting for droplets to start...')
    droplets = wait_for_droplets(droplets)

    print('Checking droplets wallets...')
    wallets = {}
    while True:
        completed = []
        for droplet in droplets:
            droplet.load()

            try:
                response = requests.get(
                    f'http://{droplet.ip_address}:3000/api/address')
                if response.ok:
                    wallet_json = response.json()
                    wallet = wallet_json['value']
                    completed.append(wallet)
                    wallets[droplet.name] = wallet

                    account = Account.from_key(explorer_key)
                    sig = account.signHash(keccak(hexstr=wallet))
                    sig_hex = sig.signature.hex()

                    delegate_response = requests.get(
                        f'https://explorer.testnet.taraxa.io/api/delegate/0x{wallet}?sig={sig_hex}')

            except:
                print(
                    f'Droplet {droplet.name} not ready yet')

            time.sleep(10)

        if len(completed) == len(droplets):
            break

    print(wallets)


@cli.command()
def projects():
    manager = get_manager()

    check_auth(manager)
    projects = manager.get_all_projects()

    if len(projects) == 0:
        print(f'No projects found.')
        quit(1)

    print("Projects:")
    for project in projects:
        print(f'{project.name}')


def get_manager():
    manager = digitalocean.Manager()

    retry = Retry(connect=3)
    adapter = HTTPAdapter(max_retries=retry)
    manager._session.mount('https://', adapter)

    return manager


def check_auth(manager):
    try:
        manager.get_account()
    except:
        print("Could not authenticate you.")
        print(
            "Export the API key (DIGITALOCEAN_ACCESS_TOKEN=xxxx) before running the script.")
        quit(1)


def check_project(manager, project):
    projects = manager.get_all_projects()

    if project is None:
        project = manager.get_default_project()
    else:
        np = None
        for p in projects:
            if p.name == project:
                np = p
                break

        if np is None:
            print(f'Project {project} not found.')
            quit(1)

        project = np
    return project


def get_regions(manager):
    regions = []
    for region in manager.get_all_regions():
        if DROPLET_SIZE in region.sizes:
            regions.append(region.slug)

    return regions


def get_user_data():
    user_data = None
    try:
        user_data = requests.get(DROPLET_USER_DATA_SCRIPT).text
    except:
        print(
            f'Could not fetch user data script from {DROPLET_USER_DATA_SCRIPT}')
        quit(1)

    return user_data


def wait_for_droplets(droplets):
    while True:
        completed = []
        for droplet in droplets:
            actions = droplet.get_actions()
            for action in actions:
                action.load()
                if action.status == 'completed':
                    completed.append(droplet.id)

            time.sleep(1)

        if len(completed) == len(droplets):
            break
    return droplets


def wait_for_wallets():
    pass


if __name__ == '__main__':
    cli()
