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

# 3. 验证授权 (使用 787 域名并加入浏览器伪装)
echo "正在发起云端验证..."
# 定义伪装浏览器头，防止被 Nginx 防火墙拦截
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
# 3. 验证授权
echo "正在发起云端验证..."

# 1. 强制 IPv4 (-4) 
# 2. 模拟 Chrome 浏览器
# 3. 增加超时重试
# 4. 这里的域名请务必确认是 http://787.7788.gg (不要用 https 减少报错概率)
CONF_DATA=$(curl -4 -sLk -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" --connect-timeout 10 "http://787.7788.gg/check.php?code=$LICENSE" | tr -d '\r\n')

# 调试显示（一定要加这两行括号，看看到底有没有空格）
echo "-------------------------------------------"
echo "验证反馈内容: [${CONF_DATA}]"
echo "-------------------------------------------"

if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "✅ 授权验证通过！准备开始安装..."
    # ... 后面接安装逻辑 ...

    # 5. 下载核心程序
    echo "正在从云端拉取商业版核心 (89MB)..."
    wget --progress=dot:giga -O /usr/local/xray2/xray2 https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2
    if [ ! -f "/usr/local/xray2/xray2" ]; then
        echo "❌ 核心下载失败，请检查网络或 GitHub 链接！"
        exit 1
    fi
    chmod +x /usr/local/xray2/xray2

    # 6. 写入配置文件
    echo "正在写入节点配置..."
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
    # 锁定配置文件，防止篡改
    chattr +i /etc/xray2/config.json 2>/dev/null

    # 7. 下载并安装管理菜单 (xray2.sh)
    echo "正在安装管理脚本..."
    wget -O /usr/bin/xray2 https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh
    chmod +x /usr/bin/xray2

    # 8. 写入 Systemd 服务项
    echo "配置系统服务..."
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

    # 9. 重启服务并设置开机自启
    systemctl daemon-reload
    systemctl enable xray2
    systemctl restart xray2

    echo "-------------------------------------------"
    echo "🎉 xray2 商业加速版安装成功！"
    echo "使用说明: 输入 xray2 即可呼出管理菜单"
    echo "-------------------------------------------"

else
    # 验证失败的处理
    echo "❌ 验证失败！服务器返回: [$CONF_DATA]"
    echo "提示：请确保母机后台已生成该授权码，且母机网络未阻断当前 IP。"
    exit 1
fi
