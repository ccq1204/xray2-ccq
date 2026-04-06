#!/bin/bash
# 品牌化 Logo
echo "-------------------------------------------"
echo "  __   autobiography ___  "
echo "  \ \/ / '__/ _` | | | | |__ \ "
echo "   >  <| | | (_| | |_| | | / / "
echo "  /_/\_\_|  \__,_|\__, | |/ /_ "
echo "                  |___/ |____| "
echo "      xray2 商业加速版安装程序          "
echo "-------------------------------------------"

read -p "请输入商业授权码: " LICENSE
read -p "请输入面板域名: " MY_API
read -p "请输入面板 KEY: " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名: " MY_DOMAIN

# 获取混淆配置并验证授权
CONF_DATA=$(curl -s "https://你的域名/check.php?code=$LICENSE&api=$MY_API&key=$MY_KEY&node=$MY_ID&domain=$MY_DOMAIN")

if [[ $CONF_DATA == "invalid"* || $CONF_DATA == "expired"* ]]; then
    echo "授权验证失败，请联系管理员！"
    exit 1
fi

# 开始安装
mkdir -p /etc/xray2 /usr/local/xray2
# 下载你预编译改名后的二进制文件
wget -O /usr/local/xray2/xray2 https://github.com/你的名/xray2/releases/latest/download/xray2
chmod +x /usr/local/xray2/xray2

# 写入混淆配置并锁死
echo "$CONF_DATA" > /etc/xray2/config.json
chattr +i /etc/xray2/config.json

# 下载管理菜单
wget -O /usr/bin/xray2 https://raw.githubusercontent.com/你的名/xray2/main/xray2.sh
chmod +x /usr/bin/xray2

# 写入 Service
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

systemctl daemon-reload && systemctl enable xray2 && systemctl restart xray2
echo "安装完成！输入 xray2 即可呼出菜单。"
