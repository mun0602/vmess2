#!/bin/bash

# Cập nhật danh sách gói phần mềm (KHÔNG upgrade)
apt update

# Định nghĩa biến
XRAY_URL="https://dtdp.bio/wp-content/apk/Xray-linux-64.zip"
INSTALL_DIR="/usr/local/xray"
CONFIG_FILE="${INSTALL_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"

# Cài đặt các gói cần thiết
apt install -y unzip curl jq qrencode

# Kiểm tra xem Xray đã được cài đặt chưa
if [[ -f "${INSTALL_DIR}/xray" ]]; then
    echo "Xray đã được cài đặt. Bỏ qua bước cài đặt."
else
    echo "Cài đặt Xray..."
    mkdir -p ${INSTALL_DIR}
    curl -L ${XRAY_URL} -o xray.zip
    unzip xray.zip -d ${INSTALL_DIR}
    chmod +x ${INSTALL_DIR}/xray
    rm xray.zip
fi

# Nhận địa chỉ IP máy chủ
SERVER_IP=$(curl -s ifconfig.me)

# Nhập User ID, Port, và tên người dùng
read -p "Nhập User ID VMess (UUID, nhấn Enter để tạo ngẫu nhiên): " UUID
UUID=${UUID:-$(uuidgen)}
read -p "Nhập Port cho VMess (mặc định 443): " PORT
PORT=${PORT:-443}
read -p "Nhập tên người dùng: " USERNAME

# Tạo file cấu hình cho Xray (VMess)
cat > ${CONFIG_FILE} <<EOF
{
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# Mở cổng trên tường lửa (nếu chưa mở)
ufw allow ${PORT}/tcp

# Kiểm tra và tạo service systemd nếu chưa có
if [[ ! -f "${SERVICE_FILE}" ]]; then
    echo "Tạo service Xray (VMess)..."
    cat > ${SERVICE_FILE} <<EOF
[Unit]
Description=Xray Service (VMess)
After=network.target
Wants=network-online.target

[Service]
ExecStart=${INSTALL_DIR}/xray run -config ${CONFIG_FILE}
Restart=always
User=root
LimitNOFILE=512000
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

# Khởi động Xray
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# Tạo URL VMess
VMESS_JSON=$(echo -n "{\"v\":\"2\",\"ps\":\"${USERNAME}\",\"add\":\"${SERVER_IP}\",\"port\":\"${PORT}\",\"id\":\"${UUID}\",\"aid\":\"64\",\"net\":\"tcp\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"tls\":\"none\"}" | base64 -w 0)
VMESS_URL="vmess://${VMESS_JSON}"

# Tạo mã QR
QR_FILE="/tmp/vmess_qr.png"
qrencode -o ${QR_FILE} -s 10 "${VMESS_URL}"

# Hiển thị thông tin VMess
echo "========================================"
echo "      Cài đặt VMess hoàn tất!"
echo "----------------------------------------"
echo "Tên người dùng: ${USERNAME}"
echo "VMess URL: ${VMESS_URL}"
echo "----------------------------------------"
echo "Mã QR được lưu tại: ${QR_FILE}"
echo "Quét mã QR dưới đây để sử dụng:"
qrencode -t ANSIUTF8 "${VMESS_URL}"
echo "----------------------------------------"
echo "Tên người dùng: ${USERNAME}"
echo "========================================"
