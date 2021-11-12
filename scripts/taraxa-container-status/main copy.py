#!/usr/bin/env python

import os
import socket
import requests
import json
import logging
import time
import slack
from queue import Queue

SLACK_TOKEN = os.environ['SLACK_TOKEN']
SLACK_CHANNEL = os.environ['SLACK_CHANNEL']
CHECK_PERIOD = 10
NOTIFICATION_REPEAT = 30
RPC_URL = "http://127.0.0.1:7777"
HOSTNAME = socket.gethostname()


def rpc(data):
    request = None
    try:
        request = requests.post(RPC_URL, data=json.dumps(data))
    except Exception as e:
        print(e)
    return request


def get_current_block():
    request = {
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": ["latest", False],
        "id": 1
    }
    json_reply = rpc(request)

    if json_reply == None:
        return 0

    json_reply = json_reply.json()
    return int(json_reply['result']['number'], 16)

def send_notification(current_status, latest_block):
    logging.info("Sending Slack notification")

    if current_status:
        message = ":white_check_mark: {} node is up and running :white_check_mark:".format(
            HOSTNAME)
    else:
        message = ":fire: {} node is down (no network progress). Latest block is {} :fire:".format(
            HOSTNAME, latest_block)

    logging.info(
        "Slack: {}".format(message))

    # slack_client.chat_postMessage(
    #     channel=SLACK_CHANNEL, text=message)


def main():
    logging.basicConfig(level=logging.INFO)
    logging.info('Started')

    slack_client = slack.WebClient(token=SLACK_TOKEN)

    logging.info('Giving the node a chance to start...') 
    time.sleep(CHECK_PERIOD)

    latest_block = get_current_block()
    is_network_up = False
    last_notification_time = int(time.time())

    while True:
        time.sleep(CHECK_PERIOD)

        current_block = get_current_block()
        logging.info("Current block: {}".format(current_block))

        if current_block <= latest_block:
            logging.error("No network progress")
            current_status = False
        else:
            current_status = True

        logging.info("Network status: {}".format(
            "UP" if current_status else "DOWN"))

        network_status_changed = current_status != is_network_up
        network_is_still_down = int(time.time(
        )) - last_notification_time >= NOTIFICATION_REPEAT and current_status == False

        if network_status_changed or network_is_still_down:
            send_notification(current_status, latest_block)
            last_notification_time = int(time.time())

        latest_block = current_block
        is_network_up = current_status


if __name__ == '__main__':
    main()
