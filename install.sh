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

# --- [ 4. 核心：物理隔离写入 (修复 \x1b 报错) ] ---
mkdir -p /etc/xray2
rm -f /etc/xray2/nodes.tmp 2>/dev/null

function write_node_json() {
    local index=$1
    echo -e "${YELLOW}---- 正在配置第 $index 个节点 ----${PLAIN}"
    read -p "ApiHost: " R_URL
    read -p "ApiKey: " R_KEY
    read -p "NodeID: " R_ID
    read -p "CertDomain: " R_DOMAIN

    # 纯净处理
    C_URL=$(echo "$R_URL" | tr -d '\r\n\x1b[' | sed 's/\/$//g' | xargs)
    [[ "$C_URL" != http* ]] && C_URL="https://$C_URL"
    C_KEY=$(echo "$R_KEY" | tr -d '\r\n\x1b[ ' | xargs)
    C_ID=$(echo "$R_ID" | tr -cd '0-9')
    C_DOMAIN=$(echo "$R_DOMAIN" | tr -d '\r\n\x1b[ ' | xargs)

    # 物理写入临时文件，绝不通过变量中转
    JSON_STR="{\"Core\":\"sing\",\"ApiHost\":\"$C_URL\",\"ApiKey\":\"$C_KEY\",\"NodeID\":$C_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$C_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
    
    if [ -f "/etc/xray2/nodes.tmp" ]; then
        echo ",$JSON_STR" >> /etc/xray2/nodes.tmp
    else
        echo "$JSON_STR" >> /etc/xray2/nodes.tmp
    fi
}

if [ "$DEPLOY_MODE" == "1" ]; then
    write_node_json 1
else
    read -p "节点总数: " NODE_COUNT
    for ((i=1; i<=NODE_COUNT; i++)); do
        write_node_json $i
    done
fi

NODE_CONTENT=$(cat /etc/xray2/nodes.tmp)

# --- [ 5. 环境与性能优化 ] ---
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi

# --- [ 6. 架构自适应下载 ] ---
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

# --- [ 7. 最终配置生成：强力脱水 ] ---
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)

# 组合并最后一次物理过滤所有 ANSI 码
printf '{"Log":{"Level":"error"},"Internal_Buffer_Cache":"%s","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[%s],"Network_Token_Hash":"%s"}' "$S1" "$NODE_CONTENT" "$S2" > /etc/xray2/config.json

# 物理必杀：删掉任何非 ASCII 打印字符（彻底消灭 \x1b）
sed -i 's/[^[:print:]]//g' /etc/xray2/config.json

chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null
rm -f /etc/xray2/nodes.tmp

# 同步伪装文件
wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route_rules.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns_config.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# --- [ 8. 系统服务与 x2 指令 ] ---
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

cat <<EOF > /usr/bin/x2
#!/bin/bash
case "\$1" in
    log) journalctl -u xray2 -f ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2 ;;
    stop) systemctl stop xray2 ;;
    start) systemctl start xray2 ;;
    uninstall)
        read -p "确定卸载吗? (y/n): " res
        if [ "\$res" == "y" ]; then
            systemctl disable xray2 --now
            chattr -i /etc/xray2/config.json 2>/dev/null
            rm -rf /usr/local/xray2 /etc/xray2 /etc/systemd/system/xray2.service /usr/bin/x2
            echo "✅ 已完全注销。"
        fi ;;
    *) echo "指令: x2 {log|restart|stop|start|uninstall}" ;;
esac
EOF
chmod +x /usr/bin/x2

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

# --- [ 9. 总结面板 ] ---
clear
echo -e "${GREEN}======================================================${PLAIN}"
echo -e "${GREEN}✅ $BRAND_NAME 商业旗舰版部署成功！${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "  作者: ${YELLOW}$AUTHOR${PLAIN} | 官网: $AD_URL"
echo -e "${YELLOW}常用指令：${PLAIN}"
echo -e "  查看日志: ${GREEN}x2 log${PLAIN}"
echo -e "  重启服务: ${GREEN}x2 restart${PLAIN}"
echo -e "  卸载脚本: ${GREEN}x2 uninstall${PLAIN}"
echo -e "${GREEN}======================================================${PLAIN}"
