#!/bin/bash

# --- 1. 环境预处理 ---
apt-get update -y && apt-get install -y curl wget tar unzip
exec < /dev/tty

echo "======================================"
echo "      V2bX [格式精准对齐版] 部署向导"
echo "======================================"

# --- 2. 基础安装逻辑 ---
if ! lsmod | grep -q bbr; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

read -p "1. ApiHost: " PANEL_URL
read -p "2. ApiKey: " PANEL_KEY
read -p "3. NodeID: " NODE_ID
read -p "4. CertDomain: " CERT_DOMAIN

mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# --- 5. 写入配置 (严格按照你给的换行和缩进格式) ---
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

# --- 6. 后续逻辑 ---
wget -O /etc/V2bX/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -O /etc/V2bX/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -O /etc/V2bX/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

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

cat <<EOF > /usr/bin/v2
#!/bin/bash
case "\$1" in
    log) journalctl -u V2bX -f ;;
    restart) systemctl restart V2bX ;;
    *) V2bX --help ;;
esac
EOF
chmod +x /usr/bin/v2

systemctl daemon-reload
systemctl enable V2bX
systemctl restart V2bX

echo "✅ 格式已完全对齐，部署完成！"
