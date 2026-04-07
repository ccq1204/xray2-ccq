#!/bin/bash

# --- 1. 环境预处理 ---
apt-get update -y && apt-get install -y curl wget tar unzip
# 确保在管道模式下也能正常读取键盘输入
exec < /dev/tty

echo "======================================"
echo "      V2bX [终极免疫版] 部署向导"
echo "======================================"

# --- 2. 开启 BBR 加速 ---
if ! lsmod | grep -q bbr; then
    echo "正在开启 BBR 加速..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# --- 3. 获取并清理用户参数 (彻底修复 \r 报错) ---
read -p "1. 请输入面板地址 (ApiHost): " RAW_URL
read -p "2. 请输入面板 API Key: " RAW_KEY
read -p "3. 请输入节点 ID (NodeID): " RAW_ID
read -p "4. 请输入节点域名 (CertDomain): " RAW_DOMAIN

# 核心过滤：删除所有可能的 Windows 换行符和首尾空格
PANEL_URL=$(echo "$RAW_URL" | tr -d '\r' | xargs)
PANEL_KEY=$(echo "$RAW_KEY" | tr -d '\r' | xargs)
NODE_ID=$(echo "$RAW_ID" | tr -d '\r' | xargs)
CERT_DOMAIN=$(echo "$RAW_DOMAIN" | tr -d '\r' | xargs)

echo "======================================"

# --- 4. 安装 V2bX 程序 ---
mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# --- 5. 写入配置 (严格对齐你提供的成功模板格式) ---
mkdir -p /etc/V2bX
cat <<EOF > /etc/V2bX/config.json
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": [
    {
        "Type": "sing",
        "Log": {
            "Level": "error",
            "Timestamp": true
        },
        "NTP": {
            "Enable": false,
            "Server": "time.apple.com",
            "ServerPort": 0
        },
        "OriginalPath": "/etc/V2bX/sing_origin.json"
    }],
    "Nodes": [{
            "Core": "sing",
            "ApiHost": "${PANEL_URL}",
            "ApiKey": "${PANEL_KEY}",
            "NodeID": ${NODE_ID},
            "NodeType": "anytls",
            "Timeout": 30,
            "ListenIP": "::",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "MinReportTraffic": 0,
            "TCPFastOpen": false,
            "SniffEnabled": true,
            "CertConfig": {
                "CertMode": "http",
                "RejectUnknownSni": false,
                "CertDomain": "${CERT_DOMAIN}",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        }]
}
EOF

# --- 6. 同步规则文件 ---
wget -O /etc/V2bX/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -O /etc/V2bX/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -O /etc/V2bX/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# --- 7. 配置 Systemd 服务 ---
cat <<EOF > /etc/systemd/system/V2bX.service
[Unit]
Description=V2bX Service
After=network.target

[Service]
User=root
WorkingDirectory=/usr/local/V2bX
ExecStart=/usr/local/V2bX/V2bX server -c /etc/V2bX/config.json
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# --- 8. 注册管理快捷键 v2 ---
cat <<EOF > /usr/bin/v2
#!/bin/bash
case "\$1" in
    log) journalctl -u V2bX -f ;;
    restart) systemctl restart V2bX ;;
    *) V2bX --help ;;
esac
EOF
chmod +x /usr/bin/v2

# --- 9. 启动 ---
systemctl daemon-reload
systemctl enable V2bX
systemctl restart V2bX

clear
echo "======================================"
echo "✅ 部署修复完成！"
echo "格式已对齐，已过滤干扰字符。"
echo "请执行: v2 log  查看状态"
echo "======================================"
