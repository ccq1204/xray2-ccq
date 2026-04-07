#!/bin/bash

# --- 1. 环境预处理：确保有基础工具 ---
apt-get update -y && apt-get install -y curl wget tar unzip

# 修复管道执行时键盘输入失效的问题
exec < /dev/tty

echo "======================================"
echo "      V2bX [终极修正版] 部署向导"
echo "======================================"

# --- 2. 开启 BBR 加速 (优化网络) ---
if ! lsmod | grep -q bbr; then
    echo "正在开启 BBR 加速..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# --- 3. 获取用户输入参数 ---
read -p "1. 请输入面板地址 (如 http://1.2.3.4:1007): " PANEL_URL
read -p "2. 请输入面板 API Key: " PANEL_KEY
read -p "3. 请输入节点 ID (Node ID): " NODE_ID
read -p "4. 请输入节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# --- 4. 安装 V2bX 程序并建立系统命令 ---
echo "正在下载 V2bX 核心程序..."
mkdir -p /usr/local/V2bX
# 强制下载 v0.4.0 稳定版
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX

# 建立全局软链接，防止 command not found
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# --- 5. 写入主配置文件 (修复变量替换逻辑) ---
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

# --- 6. 强制拉取 GitHub 规则文件 (修复 EOF 报错) ---
echo "正在同步核心规则文件..."
# 直接使用写死的 URL，防止变量解析失败
wget -t 3 -T 10 -O /etc/V2bX/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -t 3 -T 10 -O /etc/V2bX/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -t 3 -T 10 -O /etc/V2bX/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# 如果下载后文件大小为0，则写入应急基础配置防止 EOF
if [ ! -s /etc/V2bX/sing_origin.json ]; then
    cat <<EOF > /etc/V2bX/sing_origin.json
{"dns":{"servers":[{"tag":"cf","address":"1.1.1.1"}]},"route":{"rules":[{"outbound":"direct","network":["udp","tcp"]}]}}
EOF
fi

# --- 7. 配置 Systemd 服务 (修复启动路径和参数) ---
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
    status) systemctl status V2bX ;;
    *) V2bX --help ;;
esac
EOF
chmod +x /usr/bin/v2

# --- 9. 启动并收尾 ---
systemctl daemon-reload
systemctl enable V2bX
systemctl restart V2bX

clear
echo "======================================"
echo "✅ 部署修复完成！BBR 已开启。"
echo "请执行: v2 log  查看是否 Success"
echo "======================================"
