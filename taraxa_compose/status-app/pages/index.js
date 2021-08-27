import Head from "next/head";
import { useState, useEffect, useRef } from "react";
import axios from "axios";

export default function Home() {
  const [nodeAddress, setNodeAddress] = useState("");
  const [copy, setCopy] = useState("Copy");
  const [isSynced, setIsSynced] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);
  const [dposNodeVotes, setDposNodeVotes] = useState(0);
  const [peerPbftBlockCount, setPeerPbftBlockCount] = useState(0);
  const [pbftBlocks, setPbftBlocks] = useState(0);
  const [dagBlocks, setDagBlocks] = useState(0);
  const [transactions, setTransactions] = useState(0);
  const [peers, setPeers] = useState(0);
  const [blocksHistory, setBlocksHistory] = useState([]);

  useEffect(() => {
    axios.get(`/api/address`).then((response) => {
      setNodeAddress(response.data?.value || "");
    });
  }, []);

  useEffect(() => {
    const updateStatus = () => {
      axios.get(`/api/status`).then((response) => {
        if (!response.data) {
          return;
        }
        const status = response.data;
        setIsSynced(status?.synced);
        setDposNodeVotes(status?.dpos_node_votes);
        setPbftBlocks(status?.pbft_size);
        setDagBlocks(status?.blk_executed);
        setTransactions(status?.trx_executed);
        setPeers(status?.peer_count);

        setBlocksHistory((bh) => {
          let n = [...bh];
          n.unshift(status?.pbft_size);
          return n.slice(0, 5);
        });

        setPeerPbftBlockCount(
          Math.ceil(
            status?.network?.peers
              ?.filter((peer) => peer.dag_synced)
              .reduce((acc, curr) => acc + curr.pbft_size, 0) /
              status?.peer_count
          )
        );
      });
    };

    updateStatus();

    let checkInterval = setInterval(() => {
      updateStatus();
    }, 3000);

    return () => {
      clearInterval(checkInterval);
    };
  }, []);

  useEffect(() => {
    let uniqueBlocks = [...new Set(blocksHistory)];
    if (uniqueBlocks.length > 1) {
      setIsSyncing(true);
    } else {
      setIsSyncing(false);
    }
  }, [blocksHistory]);

  let syncedPercent = Math.round((pbftBlocks / peerPbftBlockCount) * 100);
  if (isNaN(syncedPercent)) {
    syncedPercent = 0;
  }
  if (syncedPercent < 0) {
    syncedPercent = 0;
  }
  if (syncedPercent > 100) {
    syncedPercent = 100;
  }

  const inputRef = useRef(null);

  const copyText = (event) => {
    event.preventDefault();

    var copyText = inputRef.current;

    copyText.select();
    copyText.setSelectionRange(0, 99999);
    document.execCommand("copy");

    setCopy("Copied");

    setTimeout(() => {
      setCopy("Copy");
    }, 3000);
  };

  let status = "";

  if (isSynced) {
    status = "SYNCED";
    if (dposNodeVotes > 0) {
      status += " - PARTICIPATING IN CONSENSUS";
    }
  } else {
    status = "NOT SYNCED";

    if (isSyncing) {
      status += " - IS SYNCING";
    } else {
      status += " - NOT SYNCING";
    }
  }

  return (
    <div className="container">
      <Head>
        <title>Taraxa Node Status :: {status}</title>
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main>
        <h1 className="title">Taraxa Node Status</h1>

        <p className="description">{status}</p>

        <div className="progress-bar">
          <div
            className="progress-bar-inner"
            style={{ width: `${syncedPercent}%` }}
          ></div>
          <span>{syncedPercent}%</span>
        </div>

        <div className="grid">
          <div className="card">
            <h3>&rarr; {pbftBlocks}</h3>
            <p>Number of PBFT Blocks</p>
          </div>

          <div className="card">
            <h3>&rarr; {dagBlocks}</h3>
            <p>Number of DAG Blocks</p>
          </div>

          <div className="card">
            <h3>&rarr; {transactions}</h3>
            <p>Number of transactions</p>
          </div>

          <div className="card">
            <h3>&rarr; {peers}</h3>
            <p>Number of Peers</p>
          </div>
        </div>

        {nodeAddress !== "" && (
          <div className="address-container">
            <label for="address">Node Address:</label>
            <div className="address-box">
              <input
                id="address"
                ref={inputRef}
                type="text"
                value={"0x" + nodeAddress}
                readOnly={true}
              />
              <a href="#" onClick={copyText}>
                {copy}
              </a>
            </div>
            <div className="address">
              <a
                href="https://community.taraxa.io/nodes"
                target="_blank"
                rel="noopener noreferrer"
              >
                Register your node in our Community Site
              </a>
            </div>
          </div>
        )}
      </main>

      <footer>
        <a href="https://taraxa.io" target="_blank" rel="noopener noreferrer">
          Powered by Taraxa.io
        </a>
      </footer>

      <style jsx>{`
        .container {
          min-height: 100vh;
          padding: 0 0.5rem;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
        }

        main {
          padding: 5rem 0;
          flex: 1;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
        }

        footer {
          width: 100%;
          height: 100px;
          border-top: 1px solid #eaeaea;
          display: flex;
          justify-content: center;
          align-items: center;
        }

        footer a {
          display: flex;
          justify-content: center;
          align-items: center;
        }

        a {
          color: #15ac5b;
          text-decoration: none;
        }

        .title {
          margin: 0;
          line-height: 1.15;
          font-size: 4rem;
        }

        .title,
        .description {
          text-align: center;
        }

        .description {
          line-height: 1.5;
          font-size: 1.5rem;
        }

        .grid {
          display: flex;
          align-items: center;
          justify-content: center;
          flex-wrap: wrap;

          max-width: 800px;
          margin-top: 3rem;
        }

        .card {
          margin: 1rem;
          flex-basis: 45%;
          padding: 1.5rem;
          text-align: left;
          color: inherit;
          text-decoration: none;
          border: 1px solid #eaeaea;
          border-radius: 10px;
          transition: color 0.3s ease, border-color 0.3s ease;
        }

        .card:hover,
        .card:focus,
        .card:active,
        .card.active {
          color: #15ac5b;
          border-color: #15ac5b;
        }

        .card h3 {
          margin: 0 0 1rem 0;
          font-size: 1.5rem;
        }

        .card p {
          margin: 0;
          font-size: 1.25rem;
          line-height: 1.5;
        }

        @media (max-width: 600px) {
          .grid {
            width: 100%;
            flex-direction: column;
          }

          .card {
            margin: 0;
            margin-top: 0.5rem;
            margin-bottom: 0.5rem;
            width: 100%;
          }
        }

        .progress-bar {
          position: relative;
          width: 100%;
          background-color: lightgray;
          height: 50px;
        }

        .progress-bar span {
          position: absolute;
          display: block;
          width: 100px;
          height: 50px;
          left: calc(50% - 50px);
          top: 0;
          color: #fff;
          font-weight: bold;
          text-align: center;
          line-height: 50px;
        }

        .progress-bar-inner {
          width: 25%;
          background-color: #15ac5b;
          height: 50px;
        }

        .address-container {
          width: 100%;
          padding: 1rem;
          margin-top: 3rem;
          background: lightgray;
        }

        .address-container label,
        .address-container input {
          display: block;
          margin-bottom: 0.5rem;
        }

        .address {
          width: 100%;
        }

        .address a,
        .address a:link,
        .address a:active,
        .address a:hover {
          display: block;
          width: 100%;
          height: 50px;
          background-color: #15ac5b;
          color: #fff;
          font-weight: bold;
          line-height: 50px;
          padding: 0 0.5em;
        }

        .address-box {
          width: 100%;
          position: relative;
        }

        .address-box input {
          width: 100%;
          font-size: 1.5em;
          padding: 0.5em;
          height: 50px;
          border: 1px solid #15ac5b;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .address-box input:focus {
          outline: none;
        }

        .address-box a,
        .address-box a:link,
        .address-box a:active,
        .address-box a:hover {
          position: absolute;
          display: block;
          height: 50px;
          line-height: 50px;
          color: #15ac5b;
          right: 1em;
          top: 0;
        }
      `}</style>

      <style jsx global>{`
        html,
        body {
          padding: 0;
          margin: 0;
          font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto,
            Oxygen, Ubuntu, Cantarell, Fira Sans, Droid Sans, Helvetica Neue,
            sans-serif;
        }

        * {
          box-sizing: border-box;
        }
      `}</style>
    </div>
  );
}
