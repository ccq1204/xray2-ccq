#!/bin/bash

# 1. 品牌化 Logo
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

# 3. 验证授权
echo "正在验证授权..."
# 发起请求
CONF_DATA=$(curl -s "https://00.7788.gg/check.php?code=$LICENSE&api=$MY_API&key=$MY_KEY&node=$MY_ID&domain=$MY_DOMAIN")

# 检查返回内容是否包含 success
if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "授权验证通过！"
else
    echo "授权验证失败！服务器返回: [$CONF_DATA]"
    exit 1
fi

# --- 修正点：原脚本在这里多出的 fi 和 exit 1 已被删除 ---

# 4. 环境清理与准备
echo "清理旧环境..."
systemctl stop xray2 2>/dev/null
systemctl stop V2bX 2>/dev/null
rm -rf /usr/local/xray2 /etc/xray2
mkdir -p /etc/xray2 /usr/local/xray2

# 5. 下载你编译的 89M 核心
echo "正在从云端拉取核心程序 (89MB)..."
wget --progress=dot:giga -O /usr/local/xray2/xray2 https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2
chmod +x /usr/local/xray2/xray2

# 6. 写入混淆配置
# 这里的配置你可以根据需要让 check.php 直接返回 JSON，或者在这里写死模板
# 既然 check.php 只返回 success，我们在这里手动生成配置
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

# 锁定配置防止篡改
chattr +i /etc/xray2/config.json 2>/dev/null

# 7. 下载管理菜单
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
