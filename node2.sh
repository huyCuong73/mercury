#!/bin/bash
# ============================================================================
# node2.sh — Thiết lập Validator 2 (Laptop B - Secondary)
# Chạy node1.sh trên Laptop A TRƯỚC, rồi mới chạy script này
# ============================================================================

set -e

# ------------- Cấu hình (giống node1.sh) -------------
CHAINID="${CHAIN_ID:-mercury_9001-1}"
MONIKER="validator-2"
KEYRING="test"
KEYALGO="eth_secp256k1"
BASEFEE=10000000
CHAINDIR="$HOME/.mercuryd"
KEYNAME="validator2"

CONFIG_TOML=$CHAINDIR/config/config.toml
APP_TOML=$CHAINDIR/config/app.toml
GENESIS=$CHAINDIR/config/genesis.json

# ------------- Validate dependencies -------------
command -v jq >/dev/null 2>&1 || { echo "❌ jq chưa cài. Chạy: sudo apt install -y jq"; exit 1; }
command -v mercuryd >/dev/null 2>&1 || { echo "❌ mercuryd chưa build. Chạy: make install"; exit 1; }

echo "==========================================="
echo "  🚀 MERCURY NODE 2 — SETUP SCRIPT"
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
echo "📝 Bước 1/7: Cấu hình client..."
mercuryd config set client chain-id "$CHAINID" --home "$CHAINDIR"
mercuryd config set client keyring-backend "$KEYRING" --home "$CHAINDIR"

# ------------- Bước 3: Tạo validator key -------------
echo ""
echo "🔑 Bước 2/7: Tạo key cho $KEYNAME..."
mercuryd keys add "$KEYNAME" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$CHAINDIR"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ⚠️  LƯU LẠI MNEMONIC Ở TRÊN!              ║"
echo "║  Đây là cách duy nhất khôi phục tài khoản.  ║"
echo "╚══════════════════════════════════════════════╝"
read -rp "Đã lưu mnemonic? Nhấn Enter để tiếp tục..."

# ------------- Bước 4: Init node -------------
echo ""
echo "⛓️  Bước 3/7: Khởi tạo node..."
mercuryd init "$MONIKER" --chain-id "$CHAINID" --home "$CHAINDIR" -o

# ------------- Bước 5: Hiện địa chỉ cho Node 1 -------------
VALIDATOR2_ADDR=$(mercuryd keys show "$KEYNAME" -a --keyring-backend "$KEYRING" --home "$CHAINDIR")
echo ""
echo "==========================================="
echo "  📋 GỬI THÔNG TIN NÀY CHO LAPTOP A"
echo ""
echo "  ĐỊA CHỈ VALIDATOR2:"
echo "  $VALIDATOR2_ADDR"
echo ""
echo "  → Paste địa chỉ này khi Laptop A hỏi"
echo "==========================================="
echo ""
read -rp "Đã gửi địa chỉ cho Laptop A? Nhấn Enter..."

# ------------- Bước 6: Nhận genesis từ Node 1 (lần 1) -------------
echo ""
echo "==========================================="
echo "  📥 NHẬN GENESIS.JSON TỪ LAPTOP A (lần 1)"
echo ""
echo "  Laptop A sẽ mở HTTP server port 9999."
echo "  Chạy lệnh sau để tải:"
echo "==========================================="
echo ""
read -rp "📥 Paste IP LAN của Laptop A (ví dụ 192.168.1.100): " NODE1_IP

wget "http://${NODE1_IP}:9999/genesis.json" -O "$GENESIS"
echo "   ✅ genesis.json đã tải"
echo ""
echo "→ Quay lại Laptop A, nhấn Enter để tiếp tục."
read -rp "Nhấn Enter khi Laptop A đã tiếp tục..."

# ------------- Bước 7: Tạo gentx cho validator2 -------------
echo ""
echo "📝 Bước 4/7: Tạo gentx cho validator2..."
mercuryd genesis gentx "$KEYNAME" 1000000000000000000000amercury \
    --gas-prices ${BASEFEE}amercury \
    --keyring-backend "$KEYRING" \
    --chain-id "$CHAINID" \
    --home "$CHAINDIR"

# ------------- Bước 8: Gửi gentx cho Node 1 -------------
GENTX_FILE=$(ls "$CHAINDIR/config/gentx/" | head -1)
echo ""
echo "==========================================="
echo "  📤 GỬI GENTX CHO LAPTOP A"
echo ""
echo "  Đang mở HTTP server tại port 9998..."
echo "  Trên Laptop A paste URL sau:"
echo "  http://${NODE1_IP%%.*}...:9998/$GENTX_FILE"
echo ""
echo "  (thay IP bằng IP thực của Laptop B)"
echo ""
echo "  Sau khi Laptop A tải xong, nhấn Enter"
echo "==========================================="

cd "$CHAINDIR/config/gentx"
python3 -m http.server 9998 &
HTTP_PID=$!

echo ""
echo "  📂 Gentx file: $GENTX_FILE"
echo "  🌐 URL: http://<IP_LAPTOP_B>:9998/$GENTX_FILE"
echo ""
read -rp "Laptop A đã tải gentx? Nhấn Enter..."
kill $HTTP_PID 2>/dev/null || true

# ------------- Bước 9: Nhận genesis cuối cùng từ Node 1 -------------
echo ""
echo "==========================================="
echo "  📥 NHẬN GENESIS CUỐI CÙNG TỪ LAPTOP A"
echo ""
echo "  Laptop A sẽ mở HTTP server port 9999."
echo "==========================================="
echo ""
read -rp "Laptop A đã mở HTTP server? Nhấn Enter để tải..."

wget "http://${NODE1_IP}:9999/genesis.json" -O "$GENESIS"
echo "   ✅ Genesis cuối cùng đã tải!"
echo ""
echo "→ Quay lại Laptop A, nhấn Enter để tiếp tục."
read -rp "Nhấn Enter khi Laptop A đã tiếp tục..."

# ------------- Bước 10: Cấu hình networking -------------
echo ""
echo "🌐 Bước 5/7: Cấu hình networking..."

# Timeouts
sed -i.bak 's/timeout_propose = "3s"/timeout_propose = "2s"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/g' "$CONFIG_TOML"
sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "1s"/g' "$CONFIG_TOML"

# Mở RPC
sed -i.bak 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "$CONFIG_TOML"

# Prometheus
sed -i.bak 's/prometheus = false/prometheus = true/' "$CONFIG_TOML"

# App.toml: JSON-RPC, APIs
sed -i.bak 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' "$APP_TOML"
sed -i.bak 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' "$APP_TOML"
sed -i.bak 's/enabled = false/enabled = true/g' "$APP_TOML"
sed -i.bak 's/enable = false/enable = true/g' "$APP_TOML"
sed -i.bak 's/enable-indexer = false/enable-indexer = true/g' "$APP_TOML"
sed -i.bak 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"

# ------------- Bước 11: Cấu hình peers -------------
echo ""
echo "🔗 Bước 6/7: Cấu hình P2P peers..."

MY_NODE_ID=$(mercuryd comet show-node-id --home "$CHAINDIR")
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "  📋 NODE ID CỦA LAPTOP B: $MY_NODE_ID"
echo "  → Gửi node ID này cho Laptop A"
echo "╚══════════════════════════════════════════════╝"
echo ""
read -rp "📥 Paste NODE ID của Laptop A: " NODE1_ID

if [ -n "$NODE1_ID" ] && [ -n "$NODE1_IP" ]; then
  sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"${NODE1_ID}@${NODE1_IP}:26656\"/" "$CONFIG_TOML"
  echo "   ✅ Peer configured: ${NODE1_ID}@${NODE1_IP}:26656"
else
  echo "⚠️  Bỏ qua cấu hình peer. Sửa sau trong config.toml"
fi

# Xóa file .bak
find "$CHAINDIR/config" -name "*.bak" -delete

# ------------- Bước 12: Start! -------------
echo ""
echo "==========================================="
echo "  🚀 Bước 7/7: KHỞI CHẠY NODE!"
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
