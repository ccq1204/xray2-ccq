#!/bin/bash

# --- [ 1. 商业配置与色彩定义 ] ---
AD_URL="0000.7788.gg"
AD_TG="@jzllzf"
BRAND_NAME="xray2"
AUTH_DB="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth_md5.txt"

# 定义颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
PLAIN="\033[0m"

# --- [ 2. 授权验证 (防抖增强版) ] ---
clear
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "${GREEN}          $BRAND_NAME 商业版高性能转发系统${PLAIN}"
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "  极昼流量转发官网: ${YELLOW}$AD_URL${PLAIN}"
echo -e "  官方 Telegram 频道: ${YELLOW}$AD_TG${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"

# 强制重定向输入流
exec < /dev/tty

RETRY_COUNT=0
while [ $RETRY_COUNT -lt 3 ]; do
    read -p "请输入您的授权码 (Auth Key): " USER_INPUT
    CLEAN_INPUT=$(echo -n "$USER_INPUT" | tr -cd '[:alnum:]')
    AUTH_LIST=$(curl -H "Cache-Control: no-cache" -Lfs --connect-timeout 10 "${AUTH_DB}?v=${RANDOM}" | tr -cd '[:alnum:]')

    if [[ "$AUTH_LIST" == *"$CLEAN_INPUT"* ]] && [ -n "$CLEAN_INPUT" ]; then
        echo -e "${GREEN}✅ 授权验证成功！${PLAIN}"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt 3 ]; then
            echo -e "${RED}❌ 验证失败，请检查并重试 ($RETRY_COUNT/3)${PLAIN}"
        else
            echo -e "${RED}❌ 连续失败，请访问 $AD_URL 获取支持。${PLAIN}"
            exit 1
        fi
    fi
done

# --- [ 3. 模式选择 ] ---
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "请选择部署模式："
echo -e "  ${GREEN}1.${PLAIN} 单节点模式"
echo -e "  ${GREEN}2.${PLAIN} 多节点冗余模式"
read -p "请输入数字 (1-2): " DEPLOY_MODE

# --- [ 4. 参数获取与深度清洗 ] ---
NODE_JSON_CONFIG=""

function get_node_config() {
    local index=$1
    echo -e "${YELLOW}---- 正在配置第 $index 个节点 ----${PLAIN}"
    read -p "请输入面板地址 (ApiHost): " RAW_URL
    read -p "请输入面板密钥 (ApiKey): " RAW_KEY
    read -p "请输入节点 ID (NodeID): " RAW_ID
    read -p "请输入解析域名 (CertDomain): " RAW_DOMAIN

    # 【关键修复：清除所有 ANSI 颜色代码及不可见字符】
    CLEAN_URL=$(echo "$RAW_URL" | tr -d '\r\n\x1b[' | sed 's/\/$//g' | xargs)
    [[ "$CLEAN_URL" != http* ]] && CLEAN_URL="https://$CLEAN_URL"
    
    CLEAN_KEY=$(echo "$RAW_KEY" | tr -d '\r\n\x1b[ ' | xargs)
    CLEAN_ID=$(echo "$RAW_ID" | tr -cd '0-9')
    CLEAN_DOMAIN=$(echo "$RAW_DOMAIN" | tr -d '\r\n\x1b[ ' | xargs)

    # 仅返回纯净字符串
    echo "{\"Core\":\"sing\",\"ApiHost\":\"$CLEAN_URL\",\"ApiKey\":\"$CLEAN_KEY\",\"NodeID\":$CLEAN_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$CLEAN_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
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

# --- [ 5. 系统优化与环境准备 ] ---
echo -e "${YELLOW}正在执行系统优化并安装依赖...${PLAIN}"
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

# --- [ 6. 架构自适应下载 ] ---
killall -9 xray2_core V2bX 2>/dev/null
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    DOWNLOAD_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip"
elif [ "$ARCH" == "aarch64" ]; then
    DOWNLOAD_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"
else
    echo -e "${RED}不支持的架构${PLAIN}"; exit 1
fi

mkdir -p /usr/local/xray2
wget -q -O /usr/local/xray2/core.zip "$DOWNLOAD_URL"
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 7. 核心配置：混淆与锁定 ] ---
mkdir -p /etc/xray2
# 解锁文件防止覆盖报错
chattr -i /etc/xray2/config.json 2>/dev/null
# 生成纯净随机乱码干扰项
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)

cat <<EOF > /etc/xray2/config.json
{"Log":{"Level":"error"},"Internal_Buffer_Cache":"$S1","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[$NODE_JSON_CONFIG],"Network_Token_Hash":"$S2"}
EOF

chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null

# 同步文件
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

# --- [ 9. 管理快捷指令 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
GREEN="\033[32m"
RED="\033[31m"
PLAIN="\033[0m"
case "\$1" in
    log) journalctl -u xray2 -f ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2; echo -e "\${GREEN}已重启引擎\${PLAIN}" ;;
    stop) systemctl stop xray2; echo -e "\${RED}服务已停止\${PLAIN}" ;;
    uninstall)
        read -p "确定卸载吗? (y/n): " res
        if [ "\$res" == "y" ]; then
            systemctl disable xray2 --now
            chattr -i /etc/xray2/config.json 2>/dev/null
            rm -rf /usr/local/xray2 /etc/xray2 /etc/systemd/system/xray2.service /usr/bin/x2
            echo -e "\${GREEN}✅ 已完全卸载。\${PLAIN}"
        fi ;;
    *)
        echo -e "\${GREEN}===============================${PLAIN}"
        echo -e "\${GREEN}   $BRAND_NAME 商业管理菜单\${PLAIN}"
        echo -e "\${GREEN}===============================${PLAIN}"
        echo -e "  x2 log       - 查看运行日志"
        echo -e "  x2 restart   - 重启转发引擎"
        echo -e "  x2 stop      - 停止转发服务"
        echo -e "  x2 uninstall - 彻底卸载清理"
        echo -e "\${GREEN}===============================${PLAIN}"
        ;;
esac
EOF
chmod +x /usr/bin/x2

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

# --- [ 10. 完成 ] ---
clear
echo -e "${GREEN}======================================================${PLAIN}"
echo -e "${GREEN}✅ $BRAND_NAME 商业旗舰版部署成功！${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "  管理指令: ${GREEN}x2${PLAIN} (输入 x2 调出菜单)"
echo -e "  官网: $AD_URL | TG: $AD_TG"
echo -e "${GREEN}======================================================${PLAIN}"
