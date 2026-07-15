# check blockchain đang produce blocks
curl -s http://localhost:26657/status | jq '.result.sync_info.latest_block_height'
# Check JSON-RPC (MetaMask)
curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Forward port 8545 từ host vào container
sudo iptables -t nat -A PREROUTING -p tcp --dport 8545 -j DNAT --to-destination 10.199.94.107:8545
sudo iptables -A FORWARD -p tcp -d 10.199.94.107 --dport 8545 -j ACCEPT
# Mở firewall trên host
sudo ufw allow 8545/tcp


# Trên server host (10.3.2.51)
curl -s ifconfig.me

# Từ máy cá nhân, test tới host
curl -X POST http://10.3.2.51:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'


curl -X POST http://10.3.2.51:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'