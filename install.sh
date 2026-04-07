#!/bin/bash

echo "---------- 开始 xray2 品牌化一键部署 ----------"

# 1. 基础环境安装
apt update && apt install -y curl wget tar timedatectl
timedatectl set-ntp true

# 2. 交互式获取对接信息 (用户只需要填这几个)
read -p "请输入机场网址 (例如 https://v2.com): " PANEL_URL
read -p "请输入对接 API Key: " PANEL_KEY
read -p "请输入节点 Node ID: " NODE_ID
read -p "请输入节点证书域名 (例如 node.cc): " CERT_DOMAIN

# 3. 安装 V2bX 核心 (静默安装)
wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh
printf "n\n" | bash install.sh

# 4. 强制写入你给我的那个 config.json 模板
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

# 5. 拉取你 GitHub 仓库里的其他 JSON 规则 (必须确保仓库里有这些文件)
BASE_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main"
declare -a files=("sing_origin.json" "route.json" "dns.json")

for file in "\${files[@]}"; do
    wget -q -O /etc/V2bX/\$file "\$BASE_URL/\$file"
    echo "已同步规则文件: \$file"
done

# 6. 【核心功能】注册一键唤起命令 [ v2 ]
cat > /usr/bin/v2 <<EOF
#!/bin/bash
case "\$1" in
    log) V2bX log ;;
    restart) V2bX restart ;;
    status) V2bX status ;;
    *) V2bX ;; # 默认呼出你截图里那个 0-17 的蓝色菜单
esac
EOF
chmod +x /usr/bin/v2

# 7. 启动服务
V2bX restart
clear

echo "=================================================="
echo "✅ 部署完成！"
echo "1. 规则同步：Sing-box 规则已从仓库拉取"
echo "2. 管理命令：现在直接输入 [ v2 ] 呼出菜单"
echo "3. 快捷日志：输入 [ v2 log ] 查看对接是否成功"
echo "=================================================="
v2 status
