#!/bin/bash

# 修复管道执行时 read 失效
exec < /dev/tty

echo "======================================"
echo "      V2bX 节点一键配置向导"
echo "======================================"
read -p "1. 请输入面板地址 (如 https://v2.com): " PANEL_URL
read -p "2. 请输入面板 API Key: " PANEL_KEY
read -p "3. 请输入节点 ID (Node ID): " NODE_ID
read -p "4. 请输入节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# 1. 安装基础依赖
apt update && apt install -y curl wget tar unzip

# 2. 暴力安装 V2bX 二进制文件 (直接拉取 v0.4.0 版本)
echo "正在强制安装 V2bX 核心程序..."
mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# 3. 写入你的自定义 config.json
mkdir -p /etc/V2bX
cat > /etc/V2bX/config.json <<EOF
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
            "ApiHost": "$PANEL_URL",
            "ApiKey": "$PANEL_KEY",
            "NodeID": $NODE_ID,
            "NodeType": "anytls",
            "Timeout": 30,
            "ListenIP": "::",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "MinReportTraffic": 0,
            "TCPFastOpen": false,
            "SniffEnabled": true,
            "CertConfig": {
                "CertMode": "11",
                "RejectUnknownSni": false,
                "CertDomain": "$CERT_DOMAIN",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": { "EnvName": "env1" }
            }
    }]
}
EOF

# 4. 同步规则文件 (修正变量识别问题)
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
wget -q -O /etc/V2bX/sing_origin.json "${BASE_URL}/sing_origin.json"
wget -q -O /etc/V2bX/route.json "${BASE_URL}/route.json"
wget -q -O /etc/V2bX/dns.json "${BASE_URL}/dns.json"

# 5. 注册快捷命令 v2
cat > /usr/bin/v2 <<EOF
#!/bin/bash
case "\$1" in
    log) V2bX log ;;
    restart) systemctl restart V2bX ;;
    status) systemctl status V2bX ;;
    *) V2bX ;;
esac
EOF
chmod +x /usr/bin/v2

# 6. 设置 Systemd 服务 (确保能重启)
cat > /etc/systemd/system/V2bX.service <<EOF
[Unit]
Description=V2bX Service
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/usr/local/V2bX
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/V2bX/V2bX -config /etc/V2bX/config.json
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable V2bX
systemctl restart V2bX

clear
echo "=================================================="
echo "✅ 部署完成！"
echo "1. 唤起菜单：输入 [ v2 ]"
echo "2. 重启服务：输入 [ v2 restart ]"
echo "3. 查看日志：输入 [ v2 log ]"
echo "=================================================="
V2bX status
