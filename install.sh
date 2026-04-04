#!/bin/bash

# --- 1. 定义变量 (私有化) ---
NAME="Xray2"
BIN_PATH="/usr/local/Xray2"
CONF_PATH="/etc/Xray2"
# 强制指定稳定的核心下载地址
CORE_URL="https://github.com/wyx2685/V2bX/releases/download/v1.5.5/V2bX-linux-64.zip"

echo "开始安装 $NAME 商业版..."

# --- 2. 准备环境 ---
mkdir -p $BIN_PATH $CONF_PATH
apt update && apt install unzip wget curl -y

# --- 3. 下载并静默解压 ---
wget -O $BIN_PATH/core.zip $CORE_URL
unzip -o $BIN_PATH/core.zip -d $BIN_PATH/
chmod +x $BIN_PATH/V2bX
# 建立软链接，让命令变成 xray2
ln -sf $BIN_PATH/V2bX /usr/bin/xray2

# --- 4. 自动注入你的黄金配置 ---
if [ -f "./conf/config.yml" ]; then
    cp ./conf/config.yml $CONF_PATH/config.yml
    echo "已自动同步您的商业对接配置。"
fi

# --- 5. 写入 Systemd 服务 (换壳为 Xray2) ---
cat > /etc/systemd/system/xray2.service <<SERVICES
[Unit]
Description=Xray2 Service
After=network.target

[Service]
ExecStart=$BIN_PATH/V2bX -config $CONF_PATH/config.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICES

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

echo "==============================================="
echo "   $NAME 安装完成！"
echo "   管理命令: xray2 (start|stop|restart|log)"
echo "==============================================="
