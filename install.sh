#!/bin/bash

# 1. 品牌化 Logo (修复了字符冲突)
echo "-------------------------------------------"
echo "  __  __                 ___  "
echo "  \ \/ /_ __ __ _ _   _ |__ \ "
echo "   >  <| '__/ _' | | | |   / / "
echo "  /_/\_\_|  \__,_|\__, |  / /_ "
echo "                  |___/  |____|"
echo "      xray2 商业加速版安装程序          "
echo "-------------------------------------------"

# 2. 交互获取参数
read -p "请输入商业授权码: " LICENSE
read -p "请输入面板域名 (带http/https): " MY_API
read -p "请输入面板 KEY: " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名: " MY_DOMAIN

# 3. 验证授权并获取配置
# 注意：把下面的域名换成你放 check.php 的真实地址
CONF_DATA=$(curl -s "https://你的授权域名.com/check.php?code=$LICENSE&api=$MY_API&key=$MY_KEY&node=$MY_ID&domain=$MY_DOMAIN")

if [[ $CONF_DATA == "invalid" ]] || [[ $CONF_DATA == "expired" ]] || [[ -z $CONF_DATA ]]; then
    echo "授权验证失败，请检查授权码或网络连接！"
    exit 1
fi

# 4. 环境清理与准备
systemctl stop V2bX 2>/dev/null
systemctl disable V2bX 2>/dev/null
rm -rf /usr/local/xray2 /etc/xray2
mkdir -p /etc/xray2 /usr/local/xray2

# 5. 下载你刚刚上传的 89M 核心
echo "正在从云端拉取核心程序..."
wget --progress=dot:giga -O /usr/local/xray2/xray2 https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2
chmod +x /usr/local/xray2/xray2

# 6. 写入混淆配置并加锁
echo "$CONF_DATA" > /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null

# 7. 下载管理菜单并建立软链接
wget -O /usr/bin/xray2 https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh
chmod +x /usr/bin/xray2

# 8. 写入 Systemd 服务
cat <<EOF >/etc/systemd/system/xray2.service
[Unit]
Description=xray2 Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/xray2
ExecStart=/usr/local/xray2/xray2 -config /etc/xray2/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 9. 启动服务
systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

echo "-------------------------------------------"
echo "xray2 安装成功！"
echo "输入 xray2 即可呼出管理菜单"
echo "-------------------------------------------"
