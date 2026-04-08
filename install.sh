#!/bin/bash

# --- [ 1. 品牌配置 ] ---
AUTHOR="极昼"
AD_URL="0000.7788.gg"
AD_TG="@jzllzf"
BRAND_NAME="xray2"
AUTH_DB="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth_md5.txt"

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
PLAIN="\033[0m"

# --- [ 2. 授权验证 ] ---
clear
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "${GREEN}          $BRAND_NAME 商业版高性能转发系统${PLAIN}"
echo -e "          作者：${YELLOW}$AUTHOR${PLAIN}"
echo -e "${BLUE}======================================================${PLAIN}"
exec < /dev/tty
AUTH_LIST=$(curl -H "Cache-Control: no-cache" -Lfs --connect-timeout 10 "${AUTH_DB}?v=${RANDOM}" | tr -cd '[:alnum:]')

RETRY_COUNT=0
VALID_AUTH=false
while [ $RETRY_COUNT -lt 3 ]; do
    read -p "请输入授权码: " USER_INPUT
    CLEAN_INPUT=$(echo -n "$USER_INPUT" | tr -cd '[:alnum:]')
    if [[ "$AUTH_LIST" == *"$CLEAN_INPUT"* ]] && [ -n "$CLEAN_INPUT" ]; then
        echo -e "${GREEN}✅ 验证通过！${PLAIN}"; VALID_AUTH=true; break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        [ $RETRY_COUNT -lt 3 ] && continue 
    fi
done
[ "$VALID_AUTH" = false ] && { echo -e "${RED}❌ 授权失效。${PLAIN}"; exit 1; }

# --- [ 3. 参数精准录入 ] ---
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
read -p "选择模式 (1.单节点 2.多节点): " DEPLOY_MODE
mkdir -p /etc/xray2
rm -f /etc/xray2/nodes.tmp 2>/dev/null

function write_node_json() {
    local index=$1
    echo -e "${YELLOW}---- 配置第 $index 个节点 ----${PLAIN}"
    read -p "面板地址(ApiHost): " R_URL
    C_URL=$(echo "$R_URL" | xargs | sed 's/\/$//g')
    [[ "$C_URL" != http* ]] && C_URL="http://$C_URL"
    
    read -p "面板密钥(ApiKey): " R_KEY
    C_KEY=$(echo "$R_KEY" | xargs)
    
    read -p "节点ID(NodeID): " R_ID
    C_ID=$(echo "$R_ID" | tr -cd '0-9')
    
    read -p "解析域名(CertDomain): " R_DOMAIN
    C_DOMAIN=$(echo "$R_DOMAIN" | xargs)

    JSON_STR="{\"Core\":\"sing\",\"ApiHost\":\"$C_URL\",\"ApiKey\":\"$C_KEY\",\"NodeID\":$C_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$C_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
    [ -f "/etc/xray2/nodes.tmp" ] && echo ",$JSON_STR" >> /etc/xray2/nodes.tmp || echo "$JSON_STR" >> /etc/xray2/nodes.tmp
}

[ "$DEPLOY_MODE" == "2" ] && { read -p "节点总数: " NC; for((i=1;i<=NC;i++)); do write_node_json $i; done; } || write_node_json 1
NODE_CONTENT=$(cat /etc/xray2/nodes.tmp)

# --- [ 4. 系统 TCP 压榨优化 ] ---
echo -e "${YELLOW}正在注入极昼专属网络加速补丁...${PLAIN}"
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc
cat <<EOF > /etc/sysctl.d/99-xray2.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
EOF
sysctl --system >/dev/null 2>&1

# --- [ 5. 架构自适应下载 ] ---
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip" || D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"
mkdir -p /usr/local/xray2
wget -q -O /usr/local/xray2/core.zip "$D_URL"
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core

# --- [ 6. 同步 11 个原版核心依赖 ] ---
wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json
wget -q -O /etc/xray2/custom_inbound.json https://raw.githubusercontent.com/wyx2685/V2bX/master/example_config/custom_inbound.json
wget -q -O /etc/xray2/custom_outbound.json https://raw.githubusercontent.com/wyx2685/V2bX/master/example_config/custom_outbound.json
wget -q -O /usr/local/xray2/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
wget -q -O /usr/local/xray2/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/geosite.dat

# --- [ 7. 物理脱水：配置文件生成 ] ---
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
printf '{"Log":{"Level":"error"},"Internal_Buffer_Cache":"%s","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[%s],"Network_Token_Hash":"%s"}' "$S1" "$NODE_CONTENT" "$S2" > /etc/xray2/config.json
sed -i 's/[^[:print:]]//g' /etc/xray2/config.json
chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null
rm -f /etc/xray2/nodes.tmp

# --- [ 8. 强化版管理工具 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
case "\$1" in
    log) journalctl -u xray2 -f ;;
    update)
        echo "正在同步补丁与规则库..."
        systemctl stop xray2
        wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
        systemctl start xray2 && echo "更新成功！" ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2; echo "重启成功" ;;
    uninstall) chattr -i /etc/xray2/config.json 2>/dev/null; rm -rf /usr/local/xray2 /etc/xray2 /usr/bin/x2 /etc/systemd/system/xray2.service; echo "已卸载" ;;
    *) echo "指令: x2 {log|update|restart|stop|uninstall}" ;;
esac
EOF
chmod +x /usr/bin/x2

# --- [ 9. 服务启动 ] ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 Forward Service
After=network.target
[Service]
User=root
WorkingDirectory=/usr/local/xray2
ExecStart=/usr/local/xray2/xray2_core server -c /etc/xray2/config.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable xray2 && systemctl restart xray2

# --- [ 10. 终极面板 ] ---
clear
echo -e "${GREEN}======================================================${PLAIN}"
echo -e "✅ $BRAND_NAME 部署成功！ 作者：$AUTHOR"
echo -e "------------------------------------------------------"
echo -e "  极昼官网: $AD_URL | 频道: $AD_TG"
echo -e "------------------------------------------------------"
echo -e "${YELLOW}管理指令：${PLAIN}"
echo -e "  查看日志: ${GREEN}x2 log${PLAIN}"
echo -e "  静默升级: ${GREEN}x2 update${PLAIN}"
echo -e "  重启服务: ${GREEN}x2 restart${PLAIN}"
echo -e "  彻底卸载: ${GREEN}x2 uninstall${PLAIN}"
echo -e "${GREEN}======================================================${PLAIN}"
