#!/bin/bash

# 1. 环境预处理：确保有 curl/wget/unzip 且系统源最新
apt-get update -y && apt-get install -y curl wget tar unzip

# 修复管道执行时键盘输入失效
exec < /dev/tty

echo "======================================"
echo "      V2bX [全自动] 部署向导"
echo "======================================"

# 2. 开启 BBR (如果未开启)
if ! lsmod | grep -q bbr; then
    echo "正在开启 BBR 加速..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 3. 获取用户输入
read -p "1. 请输入面板地址 (如 http://1.2.3.4:1007): " PANEL_URL
read -p "2. 请输入面板 API Key: " PANEL_KEY
read -p "3. 请输入节点 ID (Node ID): " NODE_ID
read -p "4. 请输入节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# 4. 下载并强制建立系统命令 (解决 command not found)
mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX

# 【核心修复：创建全局软链接】
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# 5. 写入配置文件 (确保变量被正确注入)
mkdir -p /etc/V2bX
cat <<EOF > /etc/V2bX/config.json
{
    "Log": { "Level": "error", "Output": "" },
    "Cores": [{
        "Type": "sing",
        "Log": { "Level": "error", "Timestamp": true },
        "NTP": { "Enable": false, "Server": "time.apple.com", "ServerPort": 0 },
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
            "TCPFastOpen": true,
            "SniffEnabled": true,
            "CertConfig": {
                "CertMode": "11",
                "RejectUnknownSni": false,
                "CertDomain": "${CERT_DOMAIN}",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": { "EnvName": "env1" }
            }
    }]
}
EOF

# 6. 同步 GitHub 规则文件
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
wget -q -O /etc/V2bX/sing_origin.json "${BASE_URL}/sing_origin.json"
wget -q -O /etc/V2bX/route.json "${BASE_URL}/route.json"
wget -q -O /etc/V2bX/dns.json "${BASE_URL}/dns.json"

# 7. 注册 Systemd 服务 (解决无法自动启动)
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

# 8. 注册一键管理快捷键 [ v2 ]
cat <<EOF > /usr/bin/v2
#!/
