#!/bin/bash

# 确保在管道模式下也能正常读取输入
exec < /dev/tty

echo "======================================"
echo "      V2bX 节点一键配置向导"
echo "======================================"
read -p "1. 请输入面板地址 (如 http://1.2.3.4:1007): " PANEL_URL
read -p "2. 请输入面板 API Key: " PANEL_KEY
read -p "3. 请输入节点 ID (Node ID): " NODE_ID
read -p "4. 请输入节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# 1. 强制清理旧环境并安装依赖
systemctl stop V2bX 2>/dev/null
apt update && apt install -y curl wget tar unzip

# 2. 暴力下载并覆盖二进制文件
mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX

# 3. 写入配置文件 (使用单引号包裹 EOF 防止变量在写入前被错误解析)
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

# 4. 拉取规则文件
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
wget -q -O /etc/V2bX/sing_origin.json "${BASE_URL}/sing_origin.json"
wget -q -O /etc/V2bX/route.json "${BASE_URL}/route.json"
wget -q -O /etc/V2bX/dns.json "${BASE_URL}/dns.json"

# 5. 注册快捷命令 v2
cat <<EOF > /usr/bin/v2
#!/bin/bash
case "\$1" in
    log) journalctl -u V2bX -f ;;
    restart) systemctl restart V2bX ;;
    *) V2bX --help ;;
esac
EOF
chmod +x /usr/bin/v2

# 6. 修正 Systemd 服务 (核心修复：增加 -config 参数)
cat <<EOF > /etc/systemd/system/V2bX.service
[Unit]
Description=V2bX Service
After=network.target

[Service]
User=root
WorkingDirectory=/usr/local/V2bX
ExecStart=/usr/local/V2bX/V2bX server -config /etc/V2bX/config.json
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable V2bX
systemctl restart V2bX

echo "======================================"
echo "✅ 部署修复完成！"
echo "请执行: v2 log  查看是否 Success"
echo "======================================"
