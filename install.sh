#!/bin/bash

# --- [ 1. 品牌配置与色彩定义 ] ---
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
echo -e "  极昼官网: ${YELLOW}$AD_URL${PLAIN} | 频道: ${YELLOW}$AD_TG${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"

# 解决输入流冲突
exec < /dev/tty

# 预拉取授权列表
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

# --- [ 3. 参数录入与精准清洗 ] ---
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
read -p "选择模式 (1.单节点 2.多节点): " DEPLOY_MODE

mkdir -p /etc/xray2
rm -f /etc/xray2/nodes.tmp 2>/dev/null

function write_node_json() {
    local index=$1
    echo -e "${YELLOW}---- 配置第 $index 个节点 ----${PLAIN}"
    # 仅使用 xargs 去除首尾空格，绝对不破坏端口号
    read -p "面板地址(ApiHost): " RAW_URL
    C_URL=$(echo "$RAW_URL" | xargs | sed 's/\/$//g')
    [[ "$C_URL" != http* ]] && C_URL="http://$C_URL"
    
    read -p "面板密钥(ApiKey): " RAW_KEY
    C_KEY=$(echo "$RAW_KEY" | xargs)
    
    read -p "节点ID(NodeID): " RAW_ID
    C_ID=$(echo "$RAW_ID" | tr -cd '0-9')
    
    read -p "解析域名(CertDomain): " RAW_DOMAIN
    C_DOMAIN=$(echo "$RAW_DOMAIN" | xargs)

    JSON_STR="{\"Core\":\"sing\",\"ApiHost\":\"$C_URL\",\"ApiKey\":\"$C_KEY\",\"NodeID\":$C_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$C_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
    
    [ -f "/etc/xray2/nodes.tmp" ] && echo ",$JSON_STR" >> /etc/xray2/nodes.tmp || echo "$JSON_STR" >> /etc/xray2/nodes.tmp
}

if [ "$DEPLOY_MODE" == "2" ]; then
    read -p "请输入节点总数: " NC
    for ((i=1; i<=NC; i++)); do write_node_json $i; done
else
    write_node_json 1
fi
NODE_CONTENT=$(cat /etc/xray2/nodes.tmp)

# --- [ 4. 全量补全：同步 11 个依赖文件 ] ---
echo -e "${YELLOW}正在同步全量配置文件与规则库...${PLAIN}"
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc

# TCP 网络性能极致压榨
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

# 架构自适应下载
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip" || D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"

mkdir -p /usr/local/xray2
wget -q -O /usr/local/xray2/core.zip "$D_URL"
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core

# 同步 11 个核心文件 (对齐原版结构)
wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json
wget -q -O /etc/xray2/custom_inbound.json https://raw.githubusercontent.com/wyx2685/V2bX/master/example_config/custom_inbound.json
wget -q -O /etc/xray2/custom_outbound.json https://raw.githubusercontent.com/wyx2685/V2bX/master/example_config/custom_outbound.json
wget -q -O /usr/local/xray2/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
wget -q -O /usr/local/xray2/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/geosite.dat

# --- [ 5. 配置文件生成与物理脱水 ] ---
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
printf '{"Log":{"Level":"error"},"Internal_Buffer_Cache":"%s","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[%s],"Network_Token_Hash":"%s"}' "$S1" "$NODE_CONTENT" "$S2" > /etc/xray2/config.json
# 清除干扰字符
sed -i 's/[^[:print:]]//g' /etc/xray2/config.json
chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null
rm -f /etc/xray2/nodes.tmp

# --- [ 6. 维护工具 x2 (全能无错版) ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"
case "\$1" in
    log) journalctl -u xray2 -f ;;
    update)
        echo -e "\${YELLOW}正在静默同步云端补丁...\${PLAIN}"
        systemctl stop xray2
        wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
        systemctl start xray2 && echo -e "\${GREEN}更新成功！\${PLAIN}" ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2; echo "重启成功" ;;
    stop) systemctl stop xray2; echo "已停止" ;;
    start) systemctl start xray2; echo "已启动" ;;
    uninstall) chattr -i /etc/xray2/config.json 2>/dev/null; rm -rf /usr/local/xray2 /etc/xray2 /usr/bin/x2 /etc/systemd/system/xray2.service; echo "已彻底卸载" ;;
    *) echo "维护指令: x2 {log | update | restart | stop | start | uninstall}" ;;
esac
EOF
chmod +x /usr/bin/x2

# --- [ 7. 系统服务 ] ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 System Service
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

# --- [ 8. 成功面板 ] ---
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
echo -e "  卸载脚本: ${GREEN}x2 uninstall${PLAIN}"
echo -e "${GREEN}======================================================${PLAIN}"
