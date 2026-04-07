#!/bin/bash

# --- 1. 环境预处理 ---
apt-get update -y && apt-get install -y curl wget tar unzip

# 修复管道执行时键盘输入失效
exec < /dev/tty

echo "======================================"
echo "      V2bX [参照成功模板] 部署向导"
echo "======================================"

# --- 2. 开启 BBR ---
if ! lsmod | grep -q bbr; then
    echo "正在开启 BBR 加速..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# --- 3. 获取参数 ---
read -p "1. 面板地址 (ApiHost): " PANEL_URL
read -p "2. 面板 API Key: " PANEL_KEY
read -p "3. 节点 ID (NodeID): " NODE_ID
read -p "4. 节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# --- 4. 暴力安装 V2bX 程序 ---
mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# --- 5. 写入配置 (完全参考你提供的 JSON 结构) ---
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
            "DNSEnv": { "EnvName": "env1" }
        }
    }]
}
EOF

# --- 6. 同步规则文件 ---
wget -O /etc/V2bX/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -O /etc/V2bX/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -O /etc/V2bX/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# --- 7. 配置服务 ---
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

# --- 8. 快捷命令 ---
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

echo "======================================"
echo "✅ 部署完成！配置已同步你的成功模板。"
echo "======================================"
