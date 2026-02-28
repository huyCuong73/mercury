#!/bin/bash
# ============================================================================
# join_network.sh — New validator joins an already-running chain
# ============================================================================
# Use this when the chain IS ALREADY RUNNING and you want to add a new validator.
# Do NOT use this for initial chain bootstrap (use deploy.sh for that).
#
# Usage:
#   ./deploy/join_network.sh \
#       --moniker "validator-5" \
#       --peer "NODE_ID@10.0.0.1:26656" \
#       --genesis-from "10.0.0.1"
#
# Or run without arguments — the script will prompt for each step.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/network.conf" 2>/dev/null || true

# ------------- Defaults from network.conf (if available) -------------
CHAINID="${CHAIN_ID:-mercury_9001-1}"
KEYRING="${KEYRING:-test}"
KEYALGO="${KEYALGO:-eth_secp256k1}"
CHAINDIR="${CHAIN_HOME:-$HOME/.mercuryd}"
BASEFEE="${BASEFEE:-10000000}"

# ------------- Parse arguments -------------
MONIKER=""
PEER=""
GENESIS_SOURCE=""
KEYNAME=""
SKIP_BUILD=false
SKIP_SYNC_WAIT=false

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --moniker NAME           Validator name (e.g. validator-5)
  --keyname NAME           Key name (default: derived from moniker)
  --peer PEER_STRING       Peer to connect to (format: NODE_ID@IP:26656)
                           Can be passed multiple times or comma-separated
  --genesis-from IP        IP of a running node to copy genesis from
  --chain-id ID            Chain ID (default: $CHAINID)
  --home PATH              Home directory (default: $CHAINDIR)
  --no-build               Skip make install
  --skip-sync-wait         Don't wait for sync to complete
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --moniker)        MONIKER="$2"; shift 2 ;;
    --keyname)        KEYNAME="$2"; shift 2 ;;
    --peer)           PEER="${PEER:+$PEER,}$2"; shift 2 ;;
    --genesis-from)   GENESIS_SOURCE="$2"; shift 2 ;;
    --chain-id)       CHAINID="$2"; shift 2 ;;
    --home)           CHAINDIR="$2"; shift 2 ;;
    --no-build)       SKIP_BUILD=true; shift ;;
    --skip-sync-wait) SKIP_SYNC_WAIT=true; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown: $1"; usage; exit 1 ;;
  esac
done

CONFIG_TOML=$CHAINDIR/config/config.toml
APP_TOML=$CHAINDIR/config/app.toml
GENESIS=$CHAINDIR/config/genesis.json

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "==========================================="
echo "  🔗 MERCURY — JOIN EXISTING NETWORK"
echo "==========================================="
echo ""

# ============================================================================
# Step 1: Gather information (prompt if not passed via arguments)
# ============================================================================

if [ -z "$MONIKER" ]; then
  read -rp "📛 Moniker for the new validator (e.g. validator-5): " MONIKER
fi

if [ -z "$KEYNAME" ]; then
  # Derive keyname from moniker: "validator-5" → "validator5"
  KEYNAME=$(echo "$MONIKER" | tr -d '-')
fi

if [ -z "$GENESIS_SOURCE" ]; then
  echo ""
  echo "Need to copy genesis.json from a running node."
  read -rp "📡 IP of a running node (e.g. 10.0.0.1): " GENESIS_SOURCE
fi

if [ -z "$PEER" ]; then
  echo ""
  echo "Need at least 1 peer to connect to the network."
  echo "Get node ID with: mercuryd comet show-node-id --home ~/.mercuryd"
  echo "Format: NODE_ID@IP:26656"
  read -rp "🔗 Peer string: " PEER
fi

echo ""
echo "📋 Configuration:"
echo "   Moniker:  $MONIKER"
echo "   Key name: $KEYNAME"
echo "   Chain ID: $CHAINID"
echo "   Home:     $CHAINDIR"
echo "   Genesis:  from $GENESIS_SOURCE"
echo "   Peers:    $PEER"
echo ""

# ============================================================================
# Step 2: Build binary
# ============================================================================

if [ "$SKIP_BUILD" = false ]; then
  echo "🔨 Step 1/6: Building mercuryd..."
  cd "$SCRIPT_DIR/.."
  make install
fi

command -v mercuryd >/dev/null 2>&1 || { echo "❌ mercuryd not found in PATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "❌ jq not installed: sudo apt install -y jq"; exit 1; }

# ============================================================================
# Step 3: Init node
# ============================================================================

echo ""
echo "⛓️  Step 2/6: Initializing node..."

if [ -d "$CHAINDIR" ]; then
  echo "⚠️  Existing data found at $CHAINDIR"
  read -rp "Remove and reinitialize? [y/n]: " ow
  if [[ "$ow" != "y" && "$ow" != "Y" ]]; then
    echo "Aborted."; exit 0
  fi
  rm -rf "$CHAINDIR"
fi

mercuryd config set client chain-id "$CHAINID" --home "$CHAINDIR"
mercuryd config set client keyring-backend "$KEYRING" --home "$CHAINDIR"
mercuryd init "$MONIKER" --chain-id "$CHAINID" --home "$CHAINDIR" -o

# ============================================================================
# Step 4: Copy genesis from a running node
# ============================================================================

echo ""
echo "📥 Step 3/6: Copying genesis.json from $GENESIS_SOURCE..."

# Try RPC first (no SSH needed)
if curl -sf "http://${GENESIS_SOURCE}:26657/genesis" > /dev/null 2>&1; then
  echo "   Downloading via RPC..."
  curl -sf "http://${GENESIS_SOURCE}:26657/genesis" | jq '.result.genesis' > "$GENESIS"
  echo "   ✅ Genesis downloaded via RPC"
else
  # Fallback: use SCP
  echo "   RPC not available, trying SCP..."
  SSH_USER="${SSH_USER:-root}"
  scp $SSH_OPTS "${SSH_USER}@${GENESIS_SOURCE}:${CHAINDIR}/config/genesis.json" "$GENESIS"
  echo "   ✅ Genesis copied via SCP"
fi

# ============================================================================
# Step 5: Create key
# ============================================================================

echo ""
echo "🔑 Step 4/6: Creating key $KEYNAME..."
mercuryd keys add "$KEYNAME" \
  --keyring-backend "$KEYRING" \
  --algo "$KEYALGO" \
  --home "$CHAINDIR" 2>&1 | tee /tmp/mercury_key_output.txt

MY_ADDR=$(mercuryd keys show "$KEYNAME" -a --keyring-backend "$KEYRING" --home "$CHAINDIR")

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  ⚠️  SAVE THE MNEMONIC SHOWN ABOVE!                ║"
echo "║                                                    ║"
echo "║  Address: $MY_ADDR"
echo "╚════════════════════════════════════════════════════╝"

# ============================================================================
# Step 6: Configure networking
# ============================================================================

echo ""
echo "🌐 Step 5/6: Configuring networking..."

# Peers
sed -i "s/persistent_peers = \"\"/persistent_peers = \"${PEER}\"/" "$CONFIG_TOML"

# Listen on all interfaces
sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "$CONFIG_TOML"

# Faster timeouts
sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"

# Prometheus
sed -i 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"

# JSON-RPC
sed -i 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' "$APP_TOML"
sed -i 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' "$APP_TOML"
sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
sed -i 's/enable = false/enable = true/g' "$APP_TOML"
sed -i 's/enable-indexer = false/enable-indexer = true/g' "$APP_TOML"

# Firewall
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 26656/tcp comment "Mercury P2P" 2>/dev/null || true
  sudo ufw allow 26657/tcp comment "Mercury RPC" 2>/dev/null || true
  sudo ufw allow 8545/tcp comment "Mercury JSON-RPC" 2>/dev/null || true
  sudo ufw allow 8546/tcp comment "Mercury WS" 2>/dev/null || true
fi

# Systemd service
echo "🔧 Installing systemd service..."
MERCURYD_PATH=$(which mercuryd)
sudo tee /etc/systemd/system/mercuryd.service > /dev/null <<SERVICEEOF
[Unit]
Description=Mercury Blockchain Node ($MONIKER)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=$MERCURYD_PATH start \\
    --pruning nothing \\
    --log_level info \\
    --minimum-gas-prices=0amercury \\
    --evm.min-tip=0 \\
    --home $CHAINDIR \\
    --json-rpc.api eth,txpool,personal,net,debug,web3 \\
    --chain-id $CHAINID
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SERVICEEOF

sudo systemctl daemon-reload
sudo systemctl enable mercuryd

# ============================================================================
# Step 7: Start + Sync + Print validator registration command
# ============================================================================

echo ""
echo "🚀 Step 6/6: Starting node and syncing..."
sudo systemctl start mercuryd

if [ "$SKIP_SYNC_WAIT" = true ]; then
  echo "⏭️  Skipping sync wait."
else
  echo "⏳ Waiting for node to sync with the network..."
  echo "   (This may take a few minutes depending on block count)"
  echo ""

  SYNCING=true
  while $SYNCING; do
    sleep 5
    STATUS=$(curl -sf http://localhost:26657/status 2>/dev/null) || { echo "   Starting up..."; continue; }
    CATCHING_UP=$(echo "$STATUS" | jq -r '.result.sync_info.catching_up')
    LATEST_HEIGHT=$(echo "$STATUS" | jq -r '.result.sync_info.latest_block_height')
    echo -ne "   Block: $LATEST_HEIGHT | Syncing: $CATCHING_UP    \r"

    if [ "$CATCHING_UP" = "false" ]; then
      SYNCING=false
      echo ""
      echo "   ✅ Sync complete! Block height: $LATEST_HEIGHT"
    fi
  done
fi

# ============================================================================
# Validator registration instructions
# ============================================================================

echo ""
echo "==========================================="
echo "  📋 NODE IS RUNNING AND SYNCED!"
echo ""
echo "  To register as a VALIDATOR, you need to:"
echo ""
echo "  1. Receive tokens (ask an existing validator to send):"
echo "     mercuryd tx bank send <FROM_KEY> $MY_ADDR \\"
echo "       100000000000000000000000000amercury \\"
echo "       --keyring-backend $KEYRING --chain-id $CHAINID -y"
echo ""
echo "  2. Once you have tokens, run the registration command:"
echo "==========================================="
echo ""

PUBKEY=$(mercuryd comet show-validator --home "$CHAINDIR")

cat <<REGEOF

# === COPY AND RUN THIS COMMAND AFTER RECEIVING TOKENS ===

mercuryd tx staking create-validator \\
    --amount=1000000000000000000000amercury \\
    --pubkey='$PUBKEY' \\
    --moniker="$MONIKER" \\
    --commission-rate="0.10" \\
    --commission-max-rate="0.20" \\
    --commission-max-change-rate="0.01" \\
    --min-self-delegation="1" \\
    --gas=auto \\
    --gas-adjustment=1.5 \\
    --gas-prices=${BASEFEE}amercury \\
    --from=$KEYNAME \\
    --keyring-backend=$KEYRING \\
    --chain-id=$CHAINID \\
    --home=$CHAINDIR \\
    -y

# === VERIFY AFTER REGISTRATION ===

# List all validators:
mercuryd q staking validators --home $CHAINDIR -o json | jq '.validators[] | {moniker: .description.moniker, status: .status, tokens: .tokens}'

# Check your validator:
mercuryd q staking validator \$(mercuryd keys show $KEYNAME --bech val -a --keyring-backend $KEYRING --home $CHAINDIR) --home $CHAINDIR

REGEOF

echo ""
echo "🎉 Done! View logs: sudo journalctl -u mercuryd -f"
