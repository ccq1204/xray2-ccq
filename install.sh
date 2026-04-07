#!/bin/bash

# 修复管道执行时 read 失效的问题
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
apt update && apt install -y curl wget tar

# 2. 安装 V2bX 核心 (换一种更稳的方法)
echo "正在安装 V2bX 核心..."
wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh
# 这一步是关键：确保二进制文件被安装
bash install.sh <<EOF
n
EOF

# 3. 写入你的自定义 config.json
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

# 4. 同步规则文件 (硬编码下载，避免 $file 报错)
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
wget -q -O /etc/V2bX/sing_origin.json "${BASE_URL}/sing_origin.json"
wget -q -O /etc/V2bX/route.json "${BASE_URL}/route.json"
wget -q -O /etc/V2bX/dns.json "${BASE_URL}/dns.json"

# 5. 创建快捷命令 v2 (关联绝对路径)
cat > /usr/bin/v2 <<EOF
#!/bin/bash
case "\$1" in
    log) V2bX log ;;
    restart) V2bX restart ;;
    *) V2bX ;;
esac
EOF
chmod +x /usr/bin/v2

# 6. 重启并显示
V2bX restart
echo "--------------------------------------"
echo "部署完成！输入 v2 log 查看状态。"
V2bX status
