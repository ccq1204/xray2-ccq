#!/bin/bash

# --- 1. 获取用户输入的四个关键参数 ---
echo "======================================"
echo "      V2bX 节点一键配置向导"
echo "======================================"
read -p "1. 请输入面板地址 (如 https://v2.com): " PANEL_URL
read -p "2. 请输入面板 API Key: " PANEL_KEY
read -p "3. 请输入节点 ID (Node ID): " NODE_ID
read -p "4. 请输入节点域名 (CertDomain): " CERT_DOMAIN
echo "======================================"

# --- 2. 基础环境安装 ---
apt update && apt install -y curl wget tar

# --- 3. 安装 V2bX 核心 (直接使用官方安装并等待完成) ---
# 强制先安装好 V2bX 二进制文件
wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh
# 模拟用户按 n，不让它自动生成那个破配置
echo -e "n" | bash install.sh

# --- 4. 确保目录存在 ---
mkdir -p /etc/V2bX

# --- 5. 写入你的自定义 config.json ---
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

# --- 6. 拉取固定规则 (修正变量识别问题) ---
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
# 手动一个个下载，确保 100% 成功
wget -q -O /etc/V2bX/sing_origin.json "\${BASE_URL}/sing_origin.json"
wget -q -O /etc/V2bX/route.json "\${BASE_URL}/route.json"
wget -q -O /etc/V2bX/dns.json "\${BASE_URL}/dns.json"

# --- 7. 注册快捷命令 v2 (并兼容大小写) ---
cat > /usr/bin/v2 <<EOF
#!/bin/bash
case "\$1" in
    log) V2bX log ;;
    restart) V2bX restart ;;
    status) V2bX status ;;
    *) V2bX ;;
esac
EOF
chmod +x /usr/bin/v2

# --- 8. 启动服务 ---
/usr/local/bin/V2bX restart

clear
echo "=================================================="
echo "✅ 部署完成！"
echo "1. 请直接输入 [ v2 ] 呼出管理菜单"
echo "2. 请直接输入 [ v2 log ] 查看对接日志"
echo "=================================================="
/usr/local/bin/V2bX status
