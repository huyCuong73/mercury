Cách dùng (3 bước)
1. Sửa network.conf — đổi IP 4 server

2. Copy thư mục mercury/ lên tất cả 4 servers (git clone hoặc scp)

3. Chạy tuần tự:

bash
# Trên TẤT CẢ 4 servers (chạy song song được):
./deploy/deploy.sh --node 1 --phase init    # server 1
./deploy/deploy.sh --node 2 --phase init    # server 2
./deploy/deploy.sh --node 3 --phase init    # server 3
./deploy/deploy.sh --node 4 --phase init    # server 4

# Chỉ trên Server 1 (primary) — tự động SSH sang các server khác:
./deploy/deploy.sh --node 1 --phase genesis
./deploy/deploy.sh --node 1 --phase distribute
# Trên TẤT CẢ 4 servers:
./deploy/deploy.sh --node 1 --phase start   # server 1
./deploy/deploy.sh --node 2 --phase start   # server 2
./deploy/deploy.sh --node 3 --phase start   # server 3
./deploy/deploy.sh --node 4 --phase start   # server 4


Yêu cầu: Server 1 phải SSH được vào 3 server còn lại không cần password (dùng ssh-copy-id).