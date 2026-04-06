#!/bin/bash

# 1. 界面与品牌
echo "-------------------------------------------"
echo "      xray2 商业加速版 (V2bX 标准架构)"
echo "      状态：全功能 1:1 还原 | 零配置运行"
echo "-------------------------------------------"

# 2. 获取参数
read -p "请输入商业授权码: " LICENSE
read -p "请输入面板域名 (带https://): " MY_API
read -p "请输入面板 Token (ApiKey): " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名 (CertDomain): " MY_DOMAIN

# 3. 商业授权校验
echo "正在发起云端授权验证..."
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
# 强制使用 IPv4，增加超时控制，确保验证不卡死
CONF_DATA=$(curl -4 -sLk -A "$UA" --connect-timeout 10 "http://787.7788.gg/check.php?code=${LICENSE}" | tr -d '\r\n[:space:]')

if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "✅ 授权通过！正在部署环境..."
    
    # 4. 建立 V2bX 标准目录（目录不一致是最大的漏洞）
    systemctl stop xray2 2>/dev/null
    rm -rf /etc/V2bX /usr/local/xray2
    mkdir -p /etc/V2bX /usr/local/xray2

    # 5. 下载核心与【全套】依赖文件
    echo "正在下载核心组件及路由规则库..."
    # 下载内核
    wget -q -O /usr/local/xray2/xray2 "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2"
    chmod +x /usr/local/xray2/xray2
    
    # 【核心修复】直接从官方或你的仓库拉取 geoip/geosite，防止核心因缺少文件而崩溃
    wget -q -P /etc/V2bX/ https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
    wget -q -P /etc/V2bX/ https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
    mv /etc/V2bX/dlc.dat /etc/V2bX/geosite.dat

    # 6. 写入 1:1 还原的标准 config.json
    # 这里的参数完全对应你提供的 V2bX 截图格式
    cat <<EOF >/etc/V2bX/config.json
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
            "ApiHost": "$MY_API",
            "ApiKey": "$MY_KEY",
            "NodeID": $MY_ID,
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
                "CertDomain": "$MY_DOMAIN",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare"
            }
        }]
}
EOF

    # 7. 写入标准的 sing_origin.json (不可缺失)
    cat <<EOF >/etc/V2bX/sing_origin.json
{
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "dns", "tag": "dns-out" }
  ],
  "route": {
    "rules": [ { "protocol": "dns", "outbound": "dns-out" } ]
  }
}
EOF

    # 8. 安装管理脚本 (确保你的 xray2.sh 也指向了 /etc/V2bX)
    wget -q -O /usr/bin/xray2 "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh"
    chmod +x /usr/bin/xray2

    # 9. 配置并启动 Systemd 服务
    cat <<EOF >/etc/systemd/system/xray2.service
[Unit]
Description=xray2 商业加速服务
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/xray2
ExecStart=/usr/local/xray2/xray2 -config /etc/V2bX/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray2
    systemctl restart xray2

    echo "-------------------------------------------"
    echo "🎉 安装完成！所有配置已对标 V2bX 标准。"
    echo "节点状态：正在启动..."
    echo "管理菜单：输入 xray2"
    echo "-------------------------------------------"
    sleep 2
    systemctl status xray2 --no-pager
else
    echo "❌ 授权验证失败！内容: [$CONF_DATA]"
    exit 1
fi
