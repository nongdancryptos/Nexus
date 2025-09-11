# Hướng dẫn chạy Nexus.sh trên Ubuntu

## 1. Cài Git, screen và curl
```bash
sudo apt update
sudo apt install -y git screen curl
```

## 2. Clone repo
```bash
git clone https://github.com/nongdancryptos/Nexus.git
cd Nexus
```

## 3. Cấp quyền thực thi cho script
```bash
chmod +x nexus.sh
```

## 4. Chuẩn bị file id.txt (mỗi dòng 1 NODE-ID)
Tạo file `id.txt` trong thư mục `Nexus`:
```bash
nano id.txt
```

Ví dụ nội dung `id.txt`:
```
36063968
36063969
36063970
```

## 5. Cài nexus-network CLI
```bash
curl https://cli.nexus.xyz/ | sh
source ~/.bashrc
```

Kiểm tra:
```bash
nexus-network --help
```

## 6. Chạy script
- Start toàn bộ node trong `id.txt`:
```bash
./nexus.sh start
```
- Xem trạng thái screen session:
```bash
./nexus.sh status
```
- Stop toàn bộ node:
```bash
./nexus.sh stop
```
- Start một node:
```bash
./nexus.sh start-one <node-id>
```
- Stop một node:
```bash
./nexus.sh stop-one <node-id>
```

## 7. Xem log
```bash
tail -f ~/nexus_nodes/<node-id>/nexus.log
```
