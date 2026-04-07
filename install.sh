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

# --- 2. 基础安装与目录创建 ---
apt update && apt install -y curl wget tar
mkdir -p /etc/V2bX

# --- 3. 动态生成 config.json (其他所有选项都保持你提供的格式) ---
cat > /etc/V2bX/config.json <<EOF
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
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        }]
}
EOF

# --- 4. 拉取你 GitHub 里的固定规则文件 (这些文件不需要变) ---
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
declare -a files=("sing_origin.json" "route.json" "dns.json")

for file in "\${files[@]}"; do
    wget -q -O /etc/V2bX/\$file "\$BASE_URL/\$file"
    echo "已拉取固定规则: \$file"
done

# --- 5. 注册快捷命令 v2 ---
cat > /usr/bin/v2 <<EOF
#!/bin/bash
case "\$1" in
    log) V2bX log ;;
    restart) V2bX restart ;;
    *) V2bX ;;
esac
EOF
chmod +x /usr/bin/v2

# --- 6. 启动服务 ---
V2bX restart
echo "部署完成！输入 v2 log 查看对接状态。"
