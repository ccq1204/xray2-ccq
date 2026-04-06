#!/bin/bash

# 1. 品牌 Logo
echo "-------------------------------------------"
echo "  __  __                 ___  "
echo "  \ \/ /_ __ __ _ _   _ |__ \ "
echo "   >  <| '__/ _' | | | |   / / "
echo "  /_/\_\_|  \__,_|\__, |  / /_ "
echo "                  |___/  |____|"
echo "      xray2 商业加速版 (直接安装)          "
echo "-------------------------------------------"

# 2. 获取必要参数
read -p "请输入面板域名 (带http/https): " MY_API
read -p "请输入面板 KEY: " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名: " MY_DOMAIN

# 3. 环境清理
echo "正在清理旧环境..."
systemctl stop xray2 2>/dev/null
systemctl disable xray2 2>/dev/null
rm -rf /usr/local/xray2 /etc/xray2
mkdir -p /etc/xray2 /usr/local/xray2

# 4. 下载商业版核心 (89MB)
echo "正在拉取核心程序..."
wget --no-check-certificate -O /usr/local/xray2/xray2 "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2"

if [ ! -f "/usr/local/xray2/xray2" ]; then
    echo "❌ 核心下载失败，请检查网络或 GitHub 链接！"
    exit 1
fi
chmod +x /usr/local/xray2/xray2

# 5. 写入配置文件
echo "正在生成配置文件..."
cat <<EOF >/etc/xray2/config.json
{
  "Log": { "Level": "none" },
  "Api": {
    "WebAPI": "$MY_API",
    "Token": "$MY_KEY",
    "NodeID": $MY_ID
  },
  "Nodes": [{
    "Core": "singbox",
    "ApiHost": "http://127.0.0.1",
    "EnableAnyTLS": true,
    "CertConfig": {
      "CertMode": "http",
      "CertDomain": "$MY_DOMAIN"
    }
  }]
}
EOF

# 锁定配置防止被篡改
chattr +i /etc/xray2/config.json 2>/dev/null

# 6. 下载管理脚本
echo "正在安装管理菜单..."
wget --no-check-certificate -O /usr/bin/xray2 "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh"
chmod +x /usr/bin/xray2

# 7. 写入 Systemd 服务
echo "正在配置系统服务..."
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

# 8. 启动并显示状态
systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

echo "-------------------------------------------"
echo "🎉 xray2 商业加速版安装成功！"
echo "输入 xray2 即可呼出管理菜单"
echo "-------------------------------------------"
systemctl status xray2 --no-pager
