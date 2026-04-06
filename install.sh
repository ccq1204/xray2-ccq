#!/bin/bash
# 1. 基础信息获取
echo "-------------------------------------------"
echo "      xray2 商业版 (V2bX 标准架构)"
echo "-------------------------------------------"
read -p "请输入商业授权码: " LICENSE
read -p "请输入面板域名 (带https://): " MY_API
read -p "请输入面板 Token: " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名: " MY_DOMAIN

# 2. 授权验证
echo "正在验证授权..."
CONF_DATA=$(curl -4 -sLk --connect-timeout 10 "https://787.7788.gg/check.php?code=${LICENSE}" | tr -d '\r\n[:space:]')

if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "✅ 授权通过！正在部署..."
    systemctl stop xray2 2>/dev/null
    rm -rf /etc/V2bX /usr/local/xray2
    mkdir -p /etc/V2bX /usr/local/xray2

    # 3. 下载内核与资源 (请确保 Release 里有这些文件)
    wget -O /usr/local/xray2/xray2 "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2"
    wget -O /etc/V2bX/geoip.dat "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/geoip.dat"
    wget -O /etc/V2bX/geosite.dat "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/geosite.dat"
    chmod +x /usr/local/xray2/xray2

    # 4. 写入你提供的高级 sing_origin.json (规则审计)
    cat <<EOF >/etc/V2bX/sing_origin.json
{
  "dns": { "servers": [ { "tag": "cf", "address": "1.1.1.1" } ], "strategy": "prefer_ipv4" },
  "outbounds": [
    { "tag": "direct", "type": "direct", "domain_resolver": { "server": "cf", "strategy": "prefer_ipv4" } },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      { "ip_is_private": true, "outbound": "block" },
      { "domain_regex": [ 
          "(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
          "(.+.|^)(360|so).(cn|com)", "(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
          "(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)"
          /* 此处省略你提供的其他正则，请在 GitHub 上粘贴完整版本 */
      ], "outbound": "block" },
      { "outbound": "direct", "network": ["udp","tcp"] }
    ]
  },
  "experimental": { "cache_file": { "enabled": true } }
}
EOF

    # 5. 写入主配置 config.json
    cat <<EOF >/etc/V2bX/config.json
{
    "Log": { "Level": "error" },
    "Cores": [{ "Type": "sing", "OriginalPath": "/etc/V2bX/sing_origin.json" }],
    "Nodes": [{
        "Core": "sing", "ApiHost": "$MY_API", "ApiKey": "$MY_KEY", "NodeID": $MY_ID,
        "NodeType": "anytls", "CertConfig": { "CertMode": "http", "CertDomain": "$MY_DOMAIN" }
    }]
}
EOF

    # 6. 安装菜单、配置服务并启动 (略，参考之前版本)
    wget -O /usr/bin/xray2 "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh"
    chmod +x /usr/bin/xray2
    # [此处包含 systemd 服务配置代码...]
    systemctl daemon-reload && systemctl restart xray2
    echo "🎉 安装成功！"
else
    echo "❌ 授权失败: $CONF_DATA"
    exit 1
fi
