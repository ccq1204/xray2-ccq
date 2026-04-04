#!/bin/bash
# 自动定位当前脚本所在目录
CUR_DIR=$(cd $(dirname $0); pwd)
BIN_PATH="/usr/local/Xray2"
CONF_PATH="/etc/Xray2"
CORE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/core.zip"

echo "正在部署 Xray2 商业版终极环境..."
mkdir -p $BIN_PATH $CONF_PATH
apt update && apt install unzip wget curl -y

# 1. 安装核心
wget -O $BIN_PATH/core.zip $CORE_URL
unzip -o $BIN_PATH/core.zip -d $BIN_PATH/
chmod +x $BIN_PATH/V2bX

# 2. 关键：从当前运行目录拷贝 menu.sh 到系统命令
if [ -f "$CUR_DIR/menu.sh" ]; then
    cp "$CUR_DIR/menu.sh" /usr/bin/xray2
    chmod +x /usr/bin/xray2
    echo "菜单指令安装成功！"
else
    echo "错误：找不到 menu.sh，请检查仓库完整性！"
    exit 1
fi

# 3. 复制配置
if [ -d "$CUR_DIR/conf" ]; then
    cp "$CUR_DIR/conf/config.yml" $CONF_PATH/config.yml
fi

# 4. 写入系统服务
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
