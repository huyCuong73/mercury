#!/bin/bash
# ============================================================================
# Mercury Blockchain — Unified Multi-Node Deploy Script
# ============================================================================
# A single script used on all servers to bootstrap the chain.
#
# Usage:
#   Server 1 (primary):  ./deploy.sh --node 1
#   Server 2:            ./deploy.sh --node 2
#   Server 3:            ./deploy.sh --node 3
#   Server 4:            ./deploy.sh --node 4
#
# Phases:
#   Phase 1: init       — Create key + init node (run on ALL nodes)
#   Phase 2: genesis    — (node 1 only) Collect info from all nodes → build genesis
#   Phase 3: distribute — (node 1 only) SCP final genesis + peer info to all nodes
#   Phase 4: start      — Configure networking + start node (run on ALL nodes)
#
# Run all phases at once:
#   ./deploy.sh --node 1              # Runs all phases sequentially
# Run a specific phase:
#   ./deploy.sh --node 1 --phase init
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/network.conf"

# ------------- Parse arguments -------------
NODE_NUM=""
PHASE="all"
SKIP_BUILD=false

usage() {
  cat <<EOF
Usage: $0 --node <1-${NODE_COUNT}> [--phase <init|genesis|distribute|start|all>] [--no-build]

Options:
  --node N        Node number (1 = primary, 2-${NODE_COUNT} = secondary)
  --phase PHASE   Run a specific phase only (default: all)
  --no-build      Skip 'make install'
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node)       NODE_NUM="$2"; shift 2 ;;
    --phase)      PHASE="$2"; shift 2 ;;
    --no-build)   SKIP_BUILD=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$NODE_NUM" ] || [ "$NODE_NUM" -lt 1 ] || [ "$NODE_NUM" -gt "$NODE_COUNT" ]; then
  echo "❌ --node must be between 1 and $NODE_COUNT"
  usage; exit 1
fi

# ------------- Load config for the current node -------------
eval "MY_IP=\$NODE_${NODE_NUM}_IP"
eval "MY_MONIKER=\$NODE_${NODE_NUM}_MONIKER"
MY_KEYNAME="validator${NODE_NUM}"
IS_PRIMARY=$( [ "$NODE_NUM" -eq 1 ] && echo true || echo false )

CONFIG_TOML=$CHAIN_HOME/config/config.toml
APP_TOML=$CHAIN_HOME/config/app.toml
GENESIS=$CHAIN_HOME/config/genesis.json
TMP_GENESIS=$CHAIN_HOME/config/tmp_genesis.json

# SSH options
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [ -n "${SSH_KEY:-}" ]; then
  SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

echo "==========================================="
echo "  🚀 MERCURY DEPLOY — Node $NODE_NUM ($MY_MONIKER)"
echo "  IP: $MY_IP | Primary: $IS_PRIMARY"
echo "==========================================="

# ------------- Helpers: SSH/SCP wrappers -------------
remote_scp() {
  local src="$1" dst_ip="$2" dst_path="$3"
  scp $SSH_OPTS "$src" "${SSH_USER}@${dst_ip}:${dst_path}"
}

remote_cmd() {
  local ip="$1"; shift
  ssh $SSH_OPTS "${SSH_USER}@${ip}" "export PATH=\$PATH:\$HOME/go/bin:/usr/local/go/bin; $@"
}

remote_fetch() {
  local src_ip="$1" src_path="$2" dst="$3"
  scp $SSH_OPTS "${SSH_USER}@${src_ip}:${src_path}" "$dst"
}

# ============================================================================
# PHASE 1: INIT — Run on ALL nodes
# ============================================================================
phase_init() {
  echo ""
  echo "═══════════════════════════════════════"
  echo "  📦 PHASE 1: INIT (Node $NODE_NUM)"
  echo "═══════════════════════════════════════"

  # Build
  if [ "$SKIP_BUILD" = false ]; then
    echo "🔨 Building mercuryd..."
    cd "$SCRIPT_DIR/.."
    make install
  fi

  command -v mercuryd >/dev/null 2>&1 || { echo "❌ mercuryd not found in PATH"; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "❌ jq not installed: sudo apt install -y jq"; exit 1; }

  # Remove existing data
  if [ -d "$CHAIN_HOME" ]; then
    echo "⚠️  Removing existing data at $CHAIN_HOME..."
    rm -rf "$CHAIN_HOME"
  fi

  # Client config
  echo "📝 Configuring client..."
  mercuryd config set client chain-id "$CHAIN_ID" --home "$CHAIN_HOME"
  mercuryd config set client keyring-backend "$KEYRING" --home "$CHAIN_HOME"

  # Create key
  echo "🔑 Creating key: $MY_KEYNAME..."
  mercuryd keys add "$MY_KEYNAME" \
    --keyring-backend "$KEYRING" \
    --algo "$KEYALGO" \
    --home "$CHAIN_HOME" 2>&1 | tee "$CHAIN_HOME/key_output.txt"

  echo ""
  echo "╔════════════════════════════════════════════╗"
  echo "║  ⚠️  SAVE THE MNEMONIC SHOWN ABOVE!        ║"
  echo "╚════════════════════════════════════════════╝"

  # Init chain
  echo "⛓️  Initializing node..."
  mercuryd init "$MY_MONIKER" --chain-id "$CHAIN_ID" --home "$CHAIN_HOME" -o

  # Save address + node ID for the primary to collect later
  mercuryd keys show "$MY_KEYNAME" -a \
    --keyring-backend "$KEYRING" --home "$CHAIN_HOME" > "$CHAIN_HOME/my_address.txt"
  mercuryd comet show-node-id --home "$CHAIN_HOME" > "$CHAIN_HOME/my_node_id.txt"

  MY_ADDR=$(cat "$CHAIN_HOME/my_address.txt")
  MY_NODE_ID=$(cat "$CHAIN_HOME/my_node_id.txt")

  echo ""
  echo "✅ INIT DONE"
  echo "   Address: $MY_ADDR"
  echo "   Node ID: $MY_NODE_ID"
  echo "   Home:    $CHAIN_HOME"
}

# ============================================================================
# PHASE 2: GENESIS — Run on Node 1 (primary) ONLY
# ============================================================================
phase_genesis() {
  echo ""
  echo "═══════════════════════════════════════"
  echo "  📄 PHASE 2: GENESIS (Node $NODE_NUM)"
  echo "═══════════════════════════════════════"

  if [ "$IS_PRIMARY" != true ]; then
    echo "⏭️  Skipping — this phase runs on Node 1 (primary) only"
    return
  fi

  # --- Collect addresses from all nodes ---
  echo "📡 Collecting addresses from all nodes..."
  declare -A NODE_ADDRS
  declare -A NODE_IDS

  # Node 1 (local)
  NODE_ADDRS[1]=$(cat "$CHAIN_HOME/my_address.txt")
  NODE_IDS[1]=$(cat "$CHAIN_HOME/my_node_id.txt")
  echo "   Node 1: ${NODE_ADDRS[1]} (local)"

  # Nodes 2-N (remote via SSH)
  for i in $(seq 2 $NODE_COUNT); do
    eval "ip=\$NODE_${i}_IP"
    echo -n "   Node $i ($ip): "

    addr=$(remote_cmd "$ip" "cat $CHAIN_HOME/my_address.txt" 2>/dev/null) || {
      echo "❌ Cannot connect. Make sure './deploy.sh --node $i --phase init' was run on server $ip"
      exit 1
    }
    node_id=$(remote_cmd "$ip" "cat $CHAIN_HOME/my_node_id.txt")

    NODE_ADDRS[$i]="$addr"
    NODE_IDS[$i]="$node_id"
    echo "$addr"
  done

  # --- Configure genesis ---
  echo ""
  echo "📝 Configuring genesis..."

  # Token denomination
  jq '.app_state["staking"]["params"]["bond_denom"]="amercury"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="amercury"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="amercury"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state["gov"]["params"]["expedited_min_deposit"][0]["denom"]="amercury"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state["evm"]["params"]["evm_denom"]="amercury"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state["mint"]["params"]["mint_denom"]="amercury"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  # Token metadata
  jq '.app_state["bank"]["denom_metadata"]=[{"description":"The native staking token for mercuryd.","denom_units":[{"denom":"amercury","exponent":0,"aliases":["attomercury"]},{"denom":"mercury","exponent":18,"aliases":[]}],"base":"amercury","display":"mercury","name":"Mercury","symbol":"MERC","uri":"","uri_hash":""}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  # EVM precompiles
  jq '.app_state["evm"]["params"]["active_static_precompiles"]=["0x0000000000000000000000000000000000000100","0x0000000000000000000000000000000000000400","0x0000000000000000000000000000000000000800","0x0000000000000000000000000000000000000801","0x0000000000000000000000000000000000000802","0x0000000000000000000000000000000000000803","0x0000000000000000000000000000000000000804","0x0000000000000000000000000000000000000805","0x0000000000000000000000000000000000000806","0x0000000000000000000000000000000000000807"]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  # ERC20
  jq '.app_state.erc20.native_precompiles=["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state.erc20.token_pairs=[{contract_owner:1,erc20_address:"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",denom:"amercury",enabled:true}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  # Block gas limit
  jq '.consensus.params.block.max_gas="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  # Shorter voting periods for testnet
  sed -i 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$GENESIS"
  sed -i 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$GENESIS"
  sed -i 's/"expedited_voting_period": "86400s"/"expedited_voting_period": "15s"/g' "$GENESIS"

  echo "   ✅ Genesis configured"

  # --- Fund all validators ---
  echo "💰 Funding all validators..."
  for i in $(seq 1 $NODE_COUNT); do
    if [ "$i" -eq 1 ]; then
      mercuryd genesis add-genesis-account "$MY_KEYNAME" 100000000000000000000000000amercury \
        --keyring-backend "$KEYRING" --home "$CHAIN_HOME"
    else
      mercuryd genesis add-genesis-account "${NODE_ADDRS[$i]}" 100000000000000000000000000amercury \
        --home "$CHAIN_HOME"
    fi
    echo "   ✅ Funded node $i: ${NODE_ADDRS[$i]}"
  done

  # --- Create gentx for node 1 ---
  echo "📝 Creating gentx for node 1..."
  mercuryd genesis gentx "$MY_KEYNAME" 1000000000000000000000amercury \
    --gas-prices ${BASEFEE}amercury \
    --keyring-backend "$KEYRING" \
    --chain-id "$CHAIN_ID" \
    --home "$CHAIN_HOME"

  # --- Send genesis to all nodes and collect gentxs ---
  echo ""
  echo "📡 Sending genesis to remote nodes and collecting gentxs..."

  for i in $(seq 2 $NODE_COUNT); do
    eval "ip=\$NODE_${i}_IP"
    echo "   → Node $i ($ip):"

    # Send genesis
    echo "     📤 Sending genesis.json..."
    remote_scp "$GENESIS" "$ip" "$CHAIN_HOME/config/genesis.json"

    # Create gentx on remote
    echo "     📝 Creating gentx..."
    remote_cmd "$ip" "cd $CHAIN_HOME && \
      mercuryd genesis gentx validator${i} 1000000000000000000000amercury \
        --gas-prices ${BASEFEE}amercury \
        --keyring-backend $KEYRING \
        --chain-id $CHAIN_ID \
        --home $CHAIN_HOME"

    # Fetch gentx
    echo "     📥 Fetching gentx..."
    REMOTE_GENTX=$(remote_cmd "$ip" "ls $CHAIN_HOME/config/gentx/ | head -1")
    remote_fetch "$ip" "$CHAIN_HOME/config/gentx/$REMOTE_GENTX" \
      "$CHAIN_HOME/config/gentx/gentx-node${i}.json"

    echo "     ✅ Done"
  done

  # --- Collect all gentxs ---
  echo ""
  echo "📦 Collecting gentxs..."
  mercuryd genesis collect-gentxs --home "$CHAIN_HOME"

  echo "🔍 Validating genesis..."
  mercuryd genesis validate-genesis --home "$CHAIN_HOME"

  # --- Build peer string ---
  PEERS=""
  for i in $(seq 1 $NODE_COUNT); do
    eval "ip=\$NODE_${i}_IP"
    if [ "$i" -eq 1 ]; then
      nid="${NODE_IDS[1]}"
    else
      nid="${NODE_IDS[$i]}"
    fi
    if [ -n "$PEERS" ]; then PEERS="${PEERS},"; fi
    PEERS="${PEERS}${nid}@${ip}:26656"
  done
  echo "$PEERS" > "$CHAIN_HOME/peers.txt"

  echo ""
  echo "✅ GENESIS DONE"
  echo "   Validators: $NODE_COUNT"
  echo "   Peers: $PEERS"
}

# ============================================================================
# PHASE 3: DISTRIBUTE — Run on Node 1 (primary) ONLY
# ============================================================================
phase_distribute() {
  echo ""
  echo "═══════════════════════════════════════"
  echo "  📤 PHASE 3: DISTRIBUTE (Node $NODE_NUM)"
  echo "═══════════════════════════════════════"

  if [ "$IS_PRIMARY" != true ]; then
    echo "⏭️  Skipping — this phase runs on Node 1 (primary) only"
    return
  fi

  PEERS=$(cat "$CHAIN_HOME/peers.txt")

  for i in $(seq 2 $NODE_COUNT); do
    eval "ip=\$NODE_${i}_IP"
    echo "📤 Distributing to Node $i ($ip)..."

    # Send final genesis
    remote_scp "$GENESIS" "$ip" "$CHAIN_HOME/config/genesis.json"

    # Send peers string
    remote_scp "$CHAIN_HOME/peers.txt" "$ip" "$CHAIN_HOME/peers.txt"

    echo "   ✅ Done"
  done

  echo ""
  echo "✅ DISTRIBUTE DONE — Genesis and peers sent to all nodes"
}

# ============================================================================
# PHASE 4: START — Run on ALL nodes
# ============================================================================
phase_start() {
  echo ""
  echo "═══════════════════════════════════════"
  echo "  🚀 PHASE 4: START (Node $NODE_NUM)"
  echo "═══════════════════════════════════════"

  # --- Configure networking ---
  echo "🌐 Configuring networking..."

  # Faster timeouts for testnet
  sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
  sed -i 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
  sed -i 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
  sed -i 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
  sed -i 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
  sed -i 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
  sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"

  # Listen on all interfaces
  sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "$CONFIG_TOML"

  # Prometheus
  sed -i 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"

  # JSON-RPC + APIs
  sed -i 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' "$APP_TOML"
  sed -i 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' "$APP_TOML"
  sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
  sed -i 's/enable = false/enable = true/g' "$APP_TOML"
  sed -i 's/enable-indexer = false/enable-indexer = true/g' "$APP_TOML"
  sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"

  # --- Set persistent peers (all nodes except self) ---
  FULL_PEERS=$(cat "$CHAIN_HOME/peers.txt")
  MY_NODE_ID=$(cat "$CHAIN_HOME/my_node_id.txt")

  # Filter out self from peer list
  MY_PEERS=$(echo "$FULL_PEERS" | tr ',' '\n' | grep -v "$MY_NODE_ID" | paste -sd, -)

  sed -i "s/persistent_peers = \"\"/persistent_peers = \"${MY_PEERS}\"/" "$CONFIG_TOML"
  echo "   Peers: $MY_PEERS"

  # --- Install systemd service ---
  echo ""
  echo "🔧 Installing systemd service..."

  MERCURYD_PATH=$(which mercuryd)

  sudo tee /etc/systemd/system/mercuryd.service > /dev/null <<SERVICEEOF
[Unit]
Description=Mercury Blockchain Node ($MY_MONIKER)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=$MERCURYD_PATH start \\
    --pruning nothing \\
    --log_level info \\
    --minimum-gas-prices=0amercury \\
    --evm.min-tip=0 \\
    --home $CHAIN_HOME \\
    --json-rpc.api eth,txpool,personal,net,debug,web3 \\
    --chain-id $CHAIN_ID
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SERVICEEOF

  sudo systemctl daemon-reload
  sudo systemctl enable mercuryd

  # --- Firewall ---
  echo "🔥 Configuring firewall..."
  if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 26656/tcp comment "Mercury P2P"
    sudo ufw allow 26657/tcp comment "Mercury RPC"
    sudo ufw allow 8545/tcp comment "Mercury JSON-RPC"
    sudo ufw allow 8546/tcp comment "Mercury WebSocket"
    sudo ufw allow 9090/tcp comment "Mercury gRPC"
    sudo ufw allow 1317/tcp comment "Mercury REST"
    echo "   ✅ UFW rules added"
  else
    echo "   ⚠️  ufw not found — please open ports manually: 26656,26657,8545,8546,9090,1317"
  fi

  # --- Start ---
  echo ""
  echo "==========================================="
  echo "  🚀 STARTING NODE $NODE_NUM ($MY_MONIKER)"
  echo ""
  echo "  Chain ID:  $CHAIN_ID"
  echo "  Home:      $CHAIN_HOME"
  echo "  JSON-RPC:  http://$MY_IP:8545"
  echo "  RPC:       http://$MY_IP:26657"
  echo "  P2P:       $MY_IP:26656"
  echo "==========================================="
  echo ""

  sudo systemctl start mercuryd
  echo "✅ Node started! View logs with:"
  echo "   sudo journalctl -u mercuryd -f"
}

# ============================================================================
# MAIN — Run phases
# ============================================================================
case "$PHASE" in
  init)       phase_init ;;
  genesis)    phase_genesis ;;
  distribute) phase_distribute ;;
  start)      phase_start ;;
  all)
    phase_init
    phase_genesis
    phase_distribute
    phase_start
    ;;
  *)
    echo "❌ Invalid phase: $PHASE"
    usage; exit 1
    ;;
esac

echo ""
echo "🎉 Done! Node $NODE_NUM ($MY_MONIKER)"
