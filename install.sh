#!/bin/bash

# --- 1. 环境自愈：安装基础依赖 ---
apt-get update -y && apt-get install -y curl wget tar unzip

# 修复管道执行时键盘输入失效
exec < /dev/tty

echo "======================================"
echo "      V2bX [全自动] 部署向导"
echo "  (系统更新 + BBR开启 + 核心安装)"
echo "======================================"

# --- 2. 开启 BBR 加速 ---
if ! lsmod | grep -q bbr; then
    echo "正在开启 BBR 加速..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo "✅ BBR 加速已激活"
else
    echo "ℹ️ BBR 已经处于开启状态"
fi

# --- 3. 获取用户参数 ---
read -p "1. 请输入面板地址 (如 http://1.2.3.4:1007): " PANEL_URL
read -p "2. 请输入面板 API Key: " PANEL_KEY
read -p "3. 请输入节点 ID (Node ID): " NODE_ID
read -p "4. 请输入节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# --- 4. 暴力安装 V2bX 程序并建立系统命令 ---
echo "正在从 GitHub 获取 V2bX 核心..."
mkdir -p /usr/local/V2bX
wget -O /usr/local/V2bX/V2bX-linux.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/V2bX/V2bX-linux.zip -d /usr/local/V2bX
chmod +x /usr/local/V2bX/V2bX

# 建立全局软链接
ln -sf /usr/local/V2bX/V2bX /usr/bin/V2bX
ln -sf /usr/local/V2bX/V2bX /usr/bin/v2bx

# --- 5. 写入主配置文件 (修正 CertMode 为 none 解决崩溃) ---
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
                "CertMode": "none",
                "RejectUnknownSni": false,
                "CertDomain": "${CERT_DOMAIN}",
                "Email": "v2bx@github.com"
            }
    }]
}
EOF

# --- 6. 强制同步规则文件 (防止 EOF 错误) ---
echo "正在拉取核心规则文件..."
rm -f /etc/V2bX/sing_origin.json /etc/V2bX/route.json /etc/V2bX/dns.json

wget --no-check-certificate -O /etc/V2bX/sing_origin.json "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json"
wget --no-check-certificate -O /etc/V2bX/route.json "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json"
wget --no-check-certificate -O /etc/V2bX/dns.json "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json"

# 兜底校验：如果下载失败则写入基础规则
if [ ! -s /etc/V2bX/sing_origin.json ]; then
    cat <<EOF > /etc/V2bX/sing_origin.json
{"dns":{"servers":[{"tag":"cf","address":"1.1.1.1"}]},"route":{"rules":[{"outbound":"direct","network":["udp","tcp"]}]}}
EOF
fi

# --- 7. 配置 Systemd 服务 (修复启动指令) ---
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

# --- 9. 启动服务 ---
systemctl daemon-reload
systemctl enable V2bX
systemctl restart V2bX

clear
echo "======================================"
echo "✅ 部署完成！BBR 已开启。"
echo "请执行: v2 log  查看是否 Success"
echo "======================================"
