#!/bin/bash

# Cập nhật danh sách gói phần mềm (KHÔNG upgrade)
apt update

# Định nghĩa biến
XRAY_URL="https://dtdp.bio/wp-content/apk/Xray-linux-64.zip"
INSTALL_DIR="/usr/local/xray"
CONFIG_FILE="${INSTALL_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"

# Cài đặt các gói cần thiết
apt install -y unzip curl jq qrencode uuid-runtime imagemagick

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

# Nhập UUID, Port, và tên người dùng
read -p "Nhập UUID VMess (nhấn Enter để tạo ngẫu nhiên): " UUID
UUID=${UUID:-$(uuidgen)}
PORT=$((RANDOM % 50000 + 10000)) # Random port từ 10000 đến 60000
read -p "Nhập tên người dùng: " USERNAME

# Tạo file cấu hình cho Xray (VMess)
cat > ${CONFIG_FILE} <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0
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

# Mở cổng trên tường lửa
ufw allow ${PORT}/tcp

# Kiểm tra và tạo service systemd nếu chưa có
if [[ ! -f "${SERVICE_FILE}" ]]; then
    echo "Tạo service Xray..."
    cat > ${SERVICE_FILE} <<EOF
[Unit]
Description=Xray VMess Service
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/xray run -config ${CONFIG_FILE}
Restart=always
User=root
LimitNOFILE=512000

[Install]
WantedBy=multi-user.target
EOF
fi

# Khởi động Xray
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# Tạo JSON VMess chuẩn hoá
VMESS_JSON=$(jq -n --arg v "2" \
                   --arg ps "${USERNAME}" \
                   --arg add "${SERVER_IP}" \
                   --arg port "${PORT}" \
                   --arg id "${UUID}" \
                   --arg aid "0" \
                   --arg net "tcp" \
                   --arg type "none" \
                   --arg host "" \
                   --arg path "" \
                   --arg tls "none" \
                   --arg scy "auto" \
                   --arg sni "" \
                   '{
  "v": $v,
  "ps": $ps,
  "add": $add,
  "port": $port,
  "id": $id,
  "aid": $aid,
  "net": $net,
  "type": $type,
  "host": $host,
  "path": $path,
  "tls": $tls,
  "scy": $scy,
  "sni": $sni
}')

# Encode JSON thành Base64 (đúng chuẩn V2Ray)
VMESS_ENCODED=$(echo -n "${VMESS_JSON}" | base64 -w 0)

# Tạo URL VMess
VMESS_URL="vmess://${VMESS_ENCODED}"

# Tạo mã QR nhỏ hơn (-s 5), với tên in đậm dưới QR
QR_FILE="/tmp/vmess_qr.png"
qrencode -o ${QR_FILE} -s 5 -m 2 "${VMESS_URL}"

# Thêm tên VMess dưới QR
convert ${QR_FILE} -gravity south -fill black -pointsize 20 -annotate +0+10 "**${USERNAME}**" ${QR_FILE}

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
