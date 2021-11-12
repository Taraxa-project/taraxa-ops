#!/usr/bin/env python

import os
import socket
import requests
import json
import logging
import time
import slack

SLACK_TOKEN = os.environ['SLACK_TOKEN']
SLACK_CHANNEL = os.environ['SLACK_CHANNEL']
CHECK_PERIOD = 5
NOTIFICATION_REMINDER = 20000
RPC_URL = "http://127.0.0.1:7777"
HOSTNAME = socket.gethostname()


def all_the_same(elements):
    return len(elements) < 1 or len(elements) == elements.count(elements[0])


def get_current_block():
    response = None
    try:
        response = requests.post(RPC_URL, data=json.dumps({
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": ["latest", False],
            "id": 1
        }))
    except Exception as e:
        print(e)

    if response == None:
        return response

    json_response = response.json()
    return int(json_response['result']['number'], 16)


def main():
    logging.basicConfig(level=logging.INFO)
    logging.info('Started')

    logging.info('Giving the node a chance to start...')
    time.sleep(CHECK_PERIOD)

    slack_client = slack.WebClient(token=SLACK_TOKEN)

    q = []
    last_block = get_current_block()
    last_status = None
    last_notification_time = 0

    while True:
        time.sleep(CHECK_PERIOD)

        now = int(time.time())
        current_block = get_current_block()
        logging.info("Current block: {}".format(current_block))

        if current_block is None:
            current_block = 0
            current_status = "DOWN"
        else:
            if current_block <= last_block:
                current_status = "DOWN_NP"
            else:
                current_status = "UP"

        logging.info("Network status: {}".format(current_status))

        if len(q) == 3:
            q.pop(0)

        q.append(current_status)
        print(q)

        can_send_notification = len(q) == 3 and all_the_same(
            q) and current_status != last_status
        can_send_reminder = len(q) == 3 and all_the_same(
            q) and now - last_notification_time >= NOTIFICATION_REMINDER

        if can_send_notification or can_send_reminder:
            logging.info("Sending Slack notification")

            switcher = {
                "UP": ":white_check_mark: {} node is up and running :white_check_mark:".format(HOSTNAME),
                "DOWN": ":fire: {} node is down (RPC not responding) :fire:".format(HOSTNAME),
                "DOWN_NP": ":fire: {} node is down (no network progress). Last block is {} :fire:".format(HOSTNAME, last_block),
            }

            message = switcher.get(current_status)

            logging.info(
                "Slack: {}".format(message))

            # slack_client.chat_postMessage(
            #     channel=SLACK_CHANNEL, text=message)

            last_notification_time = now

            last_status = current_status
            
        last_block = current_block


if __name__ == '__main__':
    main()
