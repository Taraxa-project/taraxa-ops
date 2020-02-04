#!/usr/bin/python3

import json
import os
import requests
import time

RECV_ADDRESS = os.environ['RECV_ADDRESS']
COINS_TO_SEND = os.getenv('COINS_TO_SEND', '1000000')
RPC_PORT = os.getenv('RPC_PORT', '7777')
NODE = os.getenv('NODE', 'localhost')
NONCE = os.getenv('NONCE', '0')
TPS_RATE = os.getenv('TPS_RATE', '1')

def rpc(node, data):
    request = None
    try:
        request = requests.post("http://{}:{}".format(node, RPC_PORT), data=json.dumps(data))
    except Exception as e:
        print(e)
    return request

def jsonrpc_cmd_create_test_coin_trx(number, recv, tps_rate, nonce):
    request = {"jsonrpc":"2.0", \
               "id":0, \
               "method": "create_test_coin_transactions", \
               "params":[{ \
                 "delay": int(1000000//int(tps_rate)), \
                 "number": int(number), \
                 "nonce": int(nonce), \
                 "receiver": recv}] \
                }
    return request

def jsonrpc_cmd_get_account_balance(account):
    request = { "jsonrpc": "2.0", \
        "id":0, \
        "method": "get_account_balance", \
        "params": [{ \
          "address": account}] \
        }
    return request

def send_get_account_balance(node_name, address):
    try:
        json_reply = rpc (node_name, jsonrpc_cmd_get_account_balance(address))
        if json_reply == None:
            return 0
        json_reply = json_reply.json()

        result = json_reply["result"]
        balance = result["value"]
        return int(balance)
    except Exception as e:
        print(e)
        return 0

def send_coins_to_self(number, recv, tps_rate, nonce, node_name):
    try:
        request = jsonrpc_cmd_create_test_coin_trx(number, recv, tps_rate, nonce)
        print("Request: {}".format(request))
        json_reply = rpc(node_name, request)
        print("JSON reply: {}".format(json_reply))
    except Exception as e:
        print(e)
    return


while send_get_account_balance(NODE, RECV_ADDRESS) == 0:
    time.sleep(5)  

send_coins_to_self(COINS_TO_SEND,RECV_ADDRESS, TPS_RATE, NONCE, NODE)