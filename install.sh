#!/bin/bash
BIN_PATH="/usr/local/Xray2"
CONF_PATH="/etc/Xray2"
# 核心：走你自己的 GitHub 链接
CORE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/core.zip"

echo "正在部署 Xray2 商业版 (v0.4.0 内核)..."
mkdir -p $BIN_PATH $CONF_PATH
apt update && apt install unzip wget curl -y

# 下载你仓库里的 core.zip
wget -O $BIN_PATH/core.zip $CORE_URL

# 解压并重命名
unzip -o $BIN_PATH/core.zip -d $BIN_PATH/
# 截图显示解压后名字是 V2bX
chmod +x $BIN_PATH/V2bX
ln -sf $BIN_PATH/V2bX /usr/bin/xray2

# 复制你的商业配置
if [ -d "./conf" ]; then
    cp ./conf/config.yml $CONF_PATH/config.yml
fi

# 写入 Systemd 服务
cat > /etc/systemd/system/xray2.service <<SERVICES
[Unit]
Description=Xray2 Service
After=network.target
[Service]
ExecStart=/usr/bin/xray2 -config $CONF_PATH/config.yml
Restart=on-failure
[Install]
WantedBy=multi-user.target
SERVICES

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2
echo "部署完成！输入 xray2 即可测试。"
