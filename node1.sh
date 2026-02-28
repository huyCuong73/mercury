#!/bin/bash
# ============================================================================
# node1.sh — Thiết lập Validator 1 (Laptop A - Primary)
# Chạy script này TRƯỚC node2.sh
# ============================================================================

set -e

# ------------- Cấu hình (lấy từ local_node.sh) -------------
CHAINID="${CHAIN_ID:-mercury_9001-1}"
MONIKER="validator-1"
KEYRING="test"
KEYALGO="eth_secp256k1"
BASEFEE=10000000
CHAINDIR="$HOME/.mercuryd"
KEYNAME="validator1"

CONFIG_TOML=$CHAINDIR/config/config.toml
APP_TOML=$CHAINDIR/config/app.toml
GENESIS=$CHAINDIR/config/genesis.json
TMP_GENESIS=$CHAINDIR/config/tmp_genesis.json

# ------------- Validate dependencies -------------
command -v jq >/dev/null 2>&1 || { echo "❌ jq chưa cài. Chạy: sudo apt install -y jq"; exit 1; }
command -v mercuryd >/dev/null 2>&1 || { echo "❌ mercuryd chưa build. Chạy: make install"; exit 1; }

echo "==========================================="
echo "  🚀 MERCURY NODE 1 — SETUP SCRIPT"
echo "==========================================="
echo ""

# ------------- Bước 1: Xóa dữ liệu cũ -------------
if [ -d "$CHAINDIR" ]; then
  echo "⚠️  Tìm thấy dữ liệu cũ tại $CHAINDIR"
  read -rp "Xóa và khởi tạo lại? [y/n]: " overwrite
  if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
    echo "Hủy bỏ."; exit 0
  fi
  rm -rf "$CHAINDIR"
fi

# ------------- Bước 2: Cấu hình client -------------
echo ""
echo "📝 Bước 1/8: Cấu hình client..."
mercuryd config set client chain-id "$CHAINID" --home "$CHAINDIR"
mercuryd config set client keyring-backend "$KEYRING" --home "$CHAINDIR"

# ------------- Bước 3: Tạo validator key -------------
echo ""
echo "🔑 Bước 2/8: Tạo key cho $KEYNAME..."
mercuryd keys add "$KEYNAME" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ⚠️  LƯU LẠI MNEMONIC Ở TRÊN!              ║"
echo "║  Đây là cách duy nhất khôi phục tài khoản.  ║"
echo "╚══════════════════════════════════════════════╝"
read -rp "Đã lưu mnemonic? Nhấn Enter để tiếp tục..."

# ------------- Bước 4: Init chain -------------
echo ""
echo "⛓️  Bước 3/8: Khởi tạo chain..."
mercuryd init "$MONIKER" --chain-id "$CHAINID" --home "$CHAINDIR" -o

# ------------- Bước 5: Cấu hình genesis -------------
echo ""
echo "📄 Bước 4/8: Cấu hình genesis..."

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

# ERC20 native precompile + token pair
jq '.app_state.erc20.native_precompiles=["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq '.app_state.erc20.token_pairs=[{contract_owner:1,erc20_address:"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",denom:"amercury",enabled:true}]' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# Block gas limit
jq '.consensus.params.block.max_gas="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# Voting periods (nhanh cho testing)
sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$GENESIS"
sed -i.bak 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$GENESIS"
sed -i.bak 's/"expedited_voting_period": "86400s"/"expedited_voting_period": "15s"/g' "$GENESIS"

echo "   ✅ Genesis configured"

# ------------- Bước 6: Fund + gentx cho validator1 -------------
echo ""
echo "💰 Bước 5/8: Fund validator1 và tạo gentx..."
mercuryd genesis add-genesis-account "$KEYNAME" 100000000000000000000000000amercury \
    --keyring-backend "$KEYRING" --home "$CHAINDIR"

# ------------- Bước 7: Chờ thông tin từ Node 2 -------------
echo ""
echo "==========================================="
echo "  📋 BÂY GIỜ CHUYỂN SANG LAPTOP B"
echo "  Chạy: ./node2.sh"
echo "  Nó sẽ cho bạn ĐỊA CHỈ VALIDATOR2"
echo "==========================================="
echo ""
read -rp "📥 Paste ĐỊA CHỈ validator2 từ Laptop B: " VALIDATOR2_ADDR

if [ -z "$VALIDATOR2_ADDR" ]; then
  echo "❌ Địa chỉ trống!"; exit 1
fi

echo "   Thêm validator2 vào genesis..."
mercuryd genesis add-genesis-account "$VALIDATOR2_ADDR" 100000000000000000000000000amercury \
    --home "$CHAINDIR"

# Tạo gentx cho validator1
mercuryd genesis gentx "$KEYNAME" 1000000000000000000000amercury \
    --gas-prices ${BASEFEE}amercury \
    --keyring-backend "$KEYRING" \
    --chain-id "$CHAINID" \
    --home "$CHAINDIR"

# ------------- Bước 8: Share genesis sang Node 2 -------------
echo ""
echo "==========================================="
echo "  📤 GỬI GENESIS.JSON CHO LAPTOP B"
echo ""
echo "  Đang mở HTTP server tại port 9999..."
echo "  Trên Laptop B chạy:"
echo "  wget http://<IP_LAPTOP_A>:9999/genesis.json \\"
echo "       -O \$HOME/.mercuryd/config/genesis.json"
echo ""
echo "  Sau khi Laptop B tải xong, nhấn Ctrl+C rồi Enter"
echo "==========================================="

cd "$CHAINDIR/config"
python3 -m http.server 9999 &
HTTP_PID=$!
read -rp "Laptop B đã tải genesis.json? Nhấn Enter..."
kill $HTTP_PID 2>/dev/null || true

# ------------- Bước 9: Nhận gentx từ Node 2 -------------
echo ""
echo "==========================================="
echo "  📥 NHẬN GENTX TỪ LAPTOP B"
echo ""
echo "  Trên Laptop B sẽ mở HTTP server."
echo "  Bạn cần tải gentx file về."
echo "==========================================="
echo ""
read -rp "📥 Paste URL gentx từ Laptop B (ví dụ: http://192.168.1.200:9998/gentx-xxx.json): " GENTX_URL

if [ -n "$GENTX_URL" ]; then
  wget "$GENTX_URL" -O "$CHAINDIR/config/gentx/gentx-validator2.json"
else
  echo ""
  echo "Hoặc copy file thủ công vào: $CHAINDIR/config/gentx/"
  read -rp "Đã copy file gentx vào thư mục trên? Nhấn Enter..."
fi

# ------------- Bước 10: Collect gentxs + validate -------------
echo ""
echo "📦 Bước 6/8: Collect gentxs..."
mercuryd genesis collect-gentxs --home "$CHAINDIR"
mercuryd genesis validate-genesis --home "$CHAINDIR"
echo "   ✅ Genesis validated!"

# ------------- Bước 11: Share genesis cuối cùng -------------
echo ""
echo "==========================================="
echo "  📤 GỬI GENESIS CUỐI CÙNG CHO LAPTOP B"
echo ""
echo "  Đang mở HTTP server tại port 9999..."
echo "  Trên Laptop B chạy:"
echo "  wget http://<IP_LAPTOP_A>:9999/genesis.json \\"
echo "       -O \$HOME/.mercuryd/config/genesis.json"
echo ""
echo "  Sau khi Laptop B tải xong, nhấn Enter"
echo "==========================================="

cd "$CHAINDIR/config"
python3 -m http.server 9999 &
HTTP_PID=$!
read -rp "Laptop B đã tải genesis cuối cùng? Nhấn Enter..."
kill $HTTP_PID 2>/dev/null || true

# ------------- Bước 12: Cấu hình networking -------------
echo ""
echo "🌐 Bước 7/8: Cấu hình networking..."

# Timeouts (nhanh hơn cho testnet)
sed -i.bak 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"

# Mở RPC cho bên ngoài
sed -i.bak 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "$CONFIG_TOML"

# Prometheus
sed -i.bak 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"

# App.toml: mở JSON-RPC, APIs
sed -i.bak 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' "$APP_TOML"
sed -i.bak 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' "$APP_TOML"
sed -i.bak 's/enabled = false/enabled = true/g' "$APP_TOML"
sed -i.bak 's/enable = false/enable = true/g' "$APP_TOML"
sed -i.bak 's/enable-indexer = false/enable-indexer = true/g' "$APP_TOML"
sed -i.bak 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"

# P2P peers
MY_NODE_ID=$(mercuryd comet show-node-id --home "$CHAINDIR")
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "  📋 NODE ID CỦA LAPTOP A: $MY_NODE_ID"
echo "  → Gửi node ID này cho Laptop B"
echo "╚══════════════════════════════════════════════╝"
echo ""
read -rp "📥 Paste NODE ID của Laptop B: " NODE2_ID
read -rp "📥 Paste IP LAN của Laptop B (ví dụ 192.168.1.200): " NODE2_IP

if [ -n "$NODE2_ID" ] && [ -n "$NODE2_IP" ]; then
  sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"${NODE2_ID}@${NODE2_IP}:26656\"/" "$CONFIG_TOML"
  echo "   ✅ Peer configured: ${NODE2_ID}@${NODE2_IP}:26656"
else
  echo "⚠️  Bỏ qua cấu hình peer. Sửa sau trong config.toml"
fi

# Xóa file .bak
find "$CHAINDIR/config" -name "*.bak" -delete

# ------------- Bước 13: Start! -------------
echo ""
echo "==========================================="
echo "  🚀 Bước 8/8: KHỞI CHẠY NODE!"
echo ""
echo "  Chain ID: $CHAINID"
echo "  Moniker:  $MONIKER"
echo "  Home:     $CHAINDIR"
echo "  JSON-RPC: http://0.0.0.0:8545"
echo "  P2P:      tcp://0.0.0.0:26656"
echo "==========================================="
echo ""
echo "⚠️  Đừng quên forward port trong PowerShell (Admin):"
echo '  $wslIp = (wsl hostname -I).Trim()'
echo '  netsh interface portproxy add v4tov4 listenport=26656 listenaddress=0.0.0.0 connectport=26656 connectaddress=$wslIp'
echo '  netsh interface portproxy add v4tov4 listenport=8545 listenaddress=0.0.0.0 connectport=8545 connectaddress=$wslIp'
echo ""
read -rp "Nhấn Enter để start node..."

mercuryd start \
    --pruning nothing \
    --log_level info \
    --minimum-gas-prices=0amercury \
    --evm.min-tip=0 \
    --home "$CHAINDIR" \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --chain-id "$CHAINID"
