#!/bin/bash

# 1. Logo
echo "-------------------------------------------"
echo "  __  __                 ___  "
echo "  \ \/ /_ __ __ _ _   _ |__ \ "
echo "   >  <| '__/ _' | | | |   / / "
echo "  /_/\_\_|  \__,_|\__, |  / /_ "
echo "                  |___/  |____|"
echo "      xray2 商业加速版安装程序          "
echo "-------------------------------------------"

# 2. 获取参数
read -p "请输入商业授权码: " LICENSE
read -p "请输入面板域名 (带http/https): " MY_API
read -p "请输入面板 KEY: " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名: " MY_DOMAIN

# 3. 验证授权
echo "正在发起云端验证..."
CONF_DATA=$(curl -s "https://00.7788.gg/check.php?code=$LICENSE")

if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "-------------------------------------------"
    echo "✅ 授权验证通过！开始下载核心..."
    echo "-------------------------------------------"
    
    # 4. 环境清理
    systemctl stop xray2 2>/dev/null
    systemctl stop V2bX 2>/dev/null
    rm -rf /usr/local/xray2 /etc/xray2
    mkdir -p /etc/xray2 /usr/local/xray2

    # 5. 下载核心
    wget --progress=dot:giga -O /usr/local/xray2/xray2 https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2
    chmod +x /usr/local/xray2/xray2

    # 6. 写入配置
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
    chattr +i /etc/xray2/config.json 2>/dev/null

    # 7. 下载菜单
    wget -O /usr/bin/xray2 https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh
    chmod +x /usr/bin/xray2

    # 8. 写入服务并启动
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

    systemctl daemon-reload
    systemctl enable xray2
    systemctl restart xray2

    echo "-------------------------------------------"
    echo "🎉 xray2 商业版安装成功！输入 xray2 呼出菜单"
    echo "-------------------------------------------"

else
    # 验证失败的处理逻辑
    echo "❌ 验证失败！返回内容: [$CONF_DATA]"
    exit 1
fi
