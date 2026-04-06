#!/bin/bash

# 1. 品牌展示
echo "-------------------------------------------"
echo "  __  __                 ___  "
echo "  \ \/ /_ __ __ _ _   _ |__ \ "
echo "   >  <| '__/ _' | | | |   / / "
echo "  /_/\_\_|  \__,_|\__, |  / /_ "
echo "                  |___/  |____|"
echo "      xray2 商业全功能版 (V2bX 架构)          "
echo "-------------------------------------------"

# 2. 交互参数
read -p "请输入商业授权码: " LICENSE
read -p "请输入面板域名 (带https://): " MY_API
read -p "请输入面板 Token (ApiKey): " MY_KEY
read -p "请输入节点 ID: " MY_ID
read -p "请输入解析后的域名 (CertDomain): " MY_DOMAIN

# 3. 授权验证 (对接 787.7788.gg 母机)
echo "正在发起云端授权验证..."
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
CONF_DATA=$(curl -4 -sLk -A "$UA" --connect-timeout 10 "http://787.7788.gg/check.php?code=${LICENSE}" | tr -d '\r\n[:space:]')

if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "✅ 授权通过！正在部署标准 V2bX 环境..."
    
    # 4. 建立标准目录
    systemctl stop xray2 2>/dev/null
    rm -rf /etc/V2bX /usr/local/xray2
    mkdir -p /etc/V2bX /usr/local/xray2

    # 5. 从你的 GitHub Release 下载全套资源
    echo "正在拉取核心组件及路由规则库..."
    # 下载内核
    wget -q -O /usr/local/xray2/xray2 "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/xray2"
    chmod +x /usr/local/xray2/xray2
    
    # 下载 GeoIP/GeoSite (确保路径与内核一致)
    wget -q -O /etc/V2bX/geoip.dat "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/geoip.dat"
    wget -q -O /etc/V2bX/geosite.dat "https://github.com/ccq1204/xray2-ccq/releases/download/v0.4.0/geosite.dat"

    # 6. 写入注入了复杂审计规则的 sing_origin.json
    cat <<EOF >/etc/V2bX/sing_origin.json
{
  "dns": {
    "servers": [ { "tag": "cf", "address": "1.1.1.1" } ],
    "strategy": "prefer_ipv4"
  },
  "outbounds": [
    { "tag": "direct", "type": "direct", "domain_resolver": { "server": "cf", "strategy": "prefer_ipv4" } },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      { "ip_is_private": true, "outbound": "block" },
      {
        "domain_regex": [
            "(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
            "(.+.|^)(360|so).(cn|com)",
            "(Subject|HELO|SMTP)",
            "(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
            "(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
            "(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
            "(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
            "(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
            "(.+.|^)(360).(cn|com|net)",
            "(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
            "(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
            "(.*.||)(netvigator|torproject).(com|cn|net|org)",
            "(..||)(visa|mycard|gash|beanfun|bank).",
            "(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
            "(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
            "(.*.||)(mycard).(com|tw)",
            "(.*.||)(gash).(com|tw)",
            "(.bank.)",
            "(.*.||)(pincong).(rocks)",
            "(.*.||)(taobao).(com)",
            "(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
            "(flows|miaoko).(pages).(dev)"
        ],
        "outbound": "block"
      },
      { "outbound": "direct", "network": [ "udp", "tcp" ] }
    ]
  },
  "experimental": { "cache_file": { "enabled": true } }
}
EOF

    # 7. 写入 config.json
    cat <<EOF >/etc/V2bX/config.json
{
    "Log": { "Level": "error" },
    "Cores": [ { "Type": "sing", "OriginalPath": "/etc/V2bX/sing_origin.json" } ],
    "Nodes": [{
            "Core": "sing",
            "ApiHost": "$MY_API",
            "ApiKey": "$MY_KEY",
            "NodeID": $MY_ID,
            "NodeType": "anytls",
            "CertConfig": {
                "CertMode": "http",
                "CertDomain": "$MY_DOMAIN",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com"
            }
        }]
}
EOF

    # 8. 安装管理菜单
    wget -q -O /usr/bin/xray2 "https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/xray2.sh"
    chmod +x /usr/bin/xray2

    # 9. 配置服务
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
    echo "🎉 安装完成！所有文件已对标 V2bX 标准。"
    echo "配置路径: /etc/V2bX/config.json"
    echo "审计规则: 已启用 (屏蔽 BT/百度/360 等)"
    echo "管理命令: xray2"
    echo "-------------------------------------------"
else
    echo "❌ 授权验证失败！内容: [$CONF_DATA]"
    exit 1
fi
