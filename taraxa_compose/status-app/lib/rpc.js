const axios = require("axios");

function request(name, params = [], id = 0) {
  return {
    jsonrpc: "2.0",
    id,
    method: name,
    params: params,
  };
}

async function send(request) {
  const response = await axios.post(process.env.NEXT_PUBLIC_RPC, request);
  return response.data?.result || {};
}

async function nodeStatus() {
  return send(request("get_node_status"));
}

async function accountAddress() {
  return send(request("get_account_address"));
}

async function netVersion() {
  return send(request("net_version"));
}

async function netPeerCount() {
  return send(request("net_peerCount"));
}

async function blockNumber() {
  return send(request("eth_blockNumber"));
}

async function dagBlockLevel() {
  return send(request("taraxa_dagBlockLevel"));
}

async function dagBlockPeriod() {
  return send(request("taraxa_dagBlockPeriod"));
}

module.exports = {
  request,
  send,
  nodeStatus,
  accountAddress,
  netVersion,
  netPeerCount,
  blockNumber,
  dagBlockLevel,
  dagBlockPeriod,
};
