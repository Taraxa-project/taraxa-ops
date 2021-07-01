# DigitalOcean Bulk Tool

## Install

```bash
pip install -r requirements.txt
```

## Usage

You can use the `do-bulk` script to start and delete multiple nodes in Digital Ocean

```
Usage: do-bulk [OPTIONS] COMMAND [ARGS]...

  DigitalOcean Testnet CLI

Options:
  --help  Show this message and exit.

Commands:
  create
  delete
  projects
```

## Examples

To create 10 nodes in the "Leo's Nodes" project and delegate to them you can use:

```bash
./do-bulk create --nodes 10 --project "Leo's Nodes" --explorer-key XXXXX
```

To delete all automatically created nodes in a project:

```bash
./do-bulk delete --project "Leo's Nodes"
```
