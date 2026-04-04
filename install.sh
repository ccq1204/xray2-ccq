#!/bin/bash
BIN_PATH="/usr/local/Xray2"
CONF_PATH="/etc/Xray2"
CORE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/core.zip"

echo "正在部署 Xray2 商业版终极环境..."
mkdir -p $BIN_PATH $CONF_PATH
apt update && apt install unzip wget curl -y

# 1. 安装内核
wget -O $BIN_PATH/core.zip $CORE_URL
unzip -o $BIN_PATH/core.zip -d $BIN_PATH/
chmod +x $BIN_PATH/V2bX

# 2. 安装菜单 (关键：把 menu.sh 变成 /usr/bin/xray2)
cp menu.sh /usr/bin/xray2
chmod +x /usr/bin/xray2

# 3. 复制配置
if [ -d "./conf" ]; then
    cp ./conf/config.yml $CONF_PATH/config.yml
fi

# 4. 写入系统服务 (内核运行需要指向 V2bX)
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
echo "   Xray2 商业版安装完成！"
echo "   现在输入 xray2 即可看到 0-17 管理菜单。"
echo "==============================================="
