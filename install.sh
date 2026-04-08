#!/bin/bash

# --- [ 1. 商业配置与色彩定义 ] ---
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

# --- [ 2. 授权验证 (静默增强版) ] ---
clear
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "${GREEN}          $BRAND_NAME 商业版高性能转发系统${PLAIN}"
echo -e "          作者：${YELLOW}$AUTHOR${PLAIN}"
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "  极昼流量转发官网: ${YELLOW}$AD_URL${PLAIN}"
echo -e "  官方 Telegram 频道: ${YELLOW}$AD_TG${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"

exec < /dev/tty
AUTH_LIST=$(curl -H "Cache-Control: no-cache" -Lfs --connect-timeout 10 "${AUTH_DB}?v=${RANDOM}" | tr -cd '[:alnum:]')

RETRY_COUNT=0
VALID_AUTH=false
while [ $RETRY_COUNT -lt 3 ]; do
    read -p "请输入您的授权码 (Auth Key): " USER_INPUT
    CLEAN_INPUT=$(echo -n "$USER_INPUT" | tr -cd '[:alnum:]')
    if [[ "$AUTH_LIST" == *"$CLEAN_INPUT"* ]] && [ -n "$CLEAN_INPUT" ]; then
        echo -e "${GREEN}✅ 授权验证成功！${PLAIN}"
        VALID_AUTH=true
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        [ $RETRY_COUNT -lt 3 ] && continue 
    fi
done

[ "$VALID_AUTH" = false ] && { echo -e "${RED}❌ 授权验证失败。${PLAIN}"; exit 1; }

# --- [ 3. 模式选择 ] ---
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "请选择部署模式："
echo -e "  ${GREEN}1.${PLAIN} 单节点模式"
echo -e "  ${GREEN}2.${PLAIN} 多节点冗余模式"
read -p "请输入数字 (1-2): " DEPLOY_MODE

# --- [ 4. 参数获取与过滤 ] ---
NODE_JSON_CONFIG=""

function get_node_config() {
    local index=$1
    echo -e "${YELLOW}---- 正在配置第 $index 个节点 ----${PLAIN}"
    read -p "请输入面板地址 (ApiHost): " RAW_URL
    read -p "请输入面板密钥 (ApiKey): " RAW_KEY
    read -p "请输入节点 ID (NodeID): " RAW_ID
    read -p "请输入解析域名 (CertDomain): " RAW_DOMAIN

    local C_URL=$(echo "$RAW_URL" | tr -d '\r\n\x1b[' | sed 's/\/$//g' | xargs)
    [[ "$C_URL" != http* ]] && C_URL="https://$C_URL"
    local C_KEY=$(echo "$RAW_KEY" | tr -d '\r\n\x1b[ ' | xargs)
    local C_ID=$(echo "$RAW_ID" | tr -cd '0-9')
    local C_DOMAIN=$(echo "$RAW_DOMAIN" | tr -d '\r\n\x1b[ ' | xargs)

    printf '{"Core":"sing","ApiHost":"%s","ApiKey":"%s","NodeID":%s,"NodeType":"anytls","Timeout":30,"ListenIP":"::","SendIP":"0.0.0.0","CertConfig":{"CertMode":"http","CertDomain":"%s","CertFile":"/etc/xray2/sys_cert.dat","KeyFile":"/etc/xray2/sys_key.dat"}}' "$C_URL" "$C_KEY" "$C_ID" "$C_DOMAIN"
}

if [ "$DEPLOY_MODE" == "1" ]; then
    NODE_JSON_CONFIG=$(get_node_config 1)
else
    read -p "请输入对接节点总数: " NODE_COUNT
    for ((i=1; i<=NODE_COUNT; i++)); do
        ITEM=$(get_node_config $i)
        if [ "$i" -eq 1 ]; then NODE_JSON_CONFIG="$ITEM"; else NODE_JSON_CONFIG="$NODE_JSON_CONFIG,$ITEM"; fi
    done
fi

# --- [ 5. 环境与性能优化 ] ---
echo -e "${YELLOW}正在优化系统参数并下载内核...${PLAIN}"
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi
sed -i '/soft nofile/d' /etc/security/limits.conf
sed -i '/hard nofile/d' /etc/security/limits.conf
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# --- [ 6. 架构下载 ] ---
killall -9 xray2_core V2bX 2>/dev/null
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip"
[ "$ARCH" == "aarch64" ] && D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"

mkdir -p /usr/local/xray2
wget -q -O /usr/local/xray2/core.zip "$D_URL"
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 7. 核心配置生成与物理脱水 ] ---
mkdir -p /etc/xray2
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)

# 使用临时文件并执行 ANSI 物理清除，彻底干掉 \x1b
printf '{"Log":{"Level":"error"},"Internal_Buffer_Cache":"%s","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[%s],"Network_Token_Hash":"%s"}' "$S1" "$NODE_JSON_CONFIG" "$S2" > /etc/xray2/config.tmp
sed -i 's/\x1b\[[0-9;]*[a-zA-Z]//g' /etc/xray2/config.tmp
mv /etc/xray2/config.tmp /etc/xray2/config.json

chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null

# 同步伪装文件
wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route_rules.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns_config.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# --- [ 8. 系统服务 ] ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 System Service
After=network.target
[Service]
User=root
WorkingDirectory=/usr/local/xray2
ExecStart=/usr/local/xray2/xray2_core server -c /etc/xray2/config.json
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF

# --- [ 9. 管理菜单 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
GREEN="\033[32m"
RED="\033[31m"
PLAIN="\033[0m"
case "\$1" in
    log) journalctl -u xray2 -f ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2; echo -e "\${GREEN}引擎已重启\${PLAIN}" ;;
    stop) systemctl stop xray2; echo -e "\${RED}服务已停止\${PLAIN}" ;;
    start) systemctl start xray2; echo -e "\${GREEN}服务已启动\${PLAIN}" ;;
    uninstall)
        read -p "确定卸载吗? (y/n): " res
        if [ "\$res" == "y" ]; then
            systemctl disable xray2 --now
            chattr -i /etc/xray2/config.json 2>/dev/null
            rm -rf /usr/local/xray2 /etc/xray2 /etc/systemd/system/xray2.service /usr/bin/x2
            echo -e "\${GREEN}已完全移除。\${PLAIN}"
        fi ;;
    *)
        echo -e "\${GREEN}===============================${PLAIN}"
        echo -e "   $BRAND_NAME 商业管理菜单 | 作者：极昼"
        echo -e "\${GREEN}===============================${PLAIN}"
        echo -e "  x2 log       - 查看内核实时状态"
        echo -e "  x2 restart   - 重启转发引擎"
        echo -e "  x2 stop      - 停止转发服务"
        echo -e "  x2 start     - 启动转发服务"
        echo -e "  x2 uninstall - 彻底卸载与清理"
        echo -e "\${GREEN}===============================${PLAIN}"
        ;;
esac
EOF
chmod +x /usr/bin/x2

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

# --- [ 10. 安装完成输出 - 全指令展示 ] ---
clear
echo -e "${GREEN}======================================================${PLAIN}"
echo -e "${GREEN}✅ $BRAND_NAME 商业旗舰版部署成功！${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "  作者: ${YELLOW}$AUTHOR${PLAIN}"
echo -e "  官网: $AD_URL | TG: $AD_TG"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "${YELLOW}常用管理指令：${PLAIN}"
echo -e "  ${GREEN}x2 log${PLAIN}      - 查看实时日志"
echo -e "  ${GREEN}x2 restart${PLAIN}  - 重启转发服务"
echo -e "  ${GREEN}x2 stop${PLAIN}     - 停止转发服务"
echo -e "  ${GREEN}x2 start${PLAIN}    - 启动转发服务"
echo -e "  ${GREEN}x2 uninstall${PLAIN}- 彻底卸载脚本"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "  PS: 配置文件已锁定，输入 ${GREEN}x2${PLAIN} 可调出详细菜单"
echo -e "${GREEN}======================================================${PLAIN}"
