#!/bin/bash
BIN_PATH="/usr/local/Xray2"
CONF_PATH="/etc/Xray2"
# 以后只走你自己的私有源，再也不看作者脸色
CORE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/core.zip"

echo "正在部署 Xray2 商业版 (基于 v0.4.0 内核)..."
mkdir -p $BIN_PATH $CONF_PATH
apt update && apt install unzip wget curl -y

# 下载你仓库里的 core.zip
wget -O $BIN_PATH/core.zip $CORE_URL

# 解压
unzip -o $BIN_PATH/core.zip -d $BIN_PATH/
# 根据截图，解压出来的二进制文件名应该叫 V2bX
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
echo "安装成功！输入 xray2 即可看到程序响应。"
