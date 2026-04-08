#!/bin/bash

# --- [ 1. 商业配置 ] ---
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
        echo -e "${GREEN}✅ 验证通过！${PLAIN}"
        VALID_AUTH=true
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        [ $RETRY_COUNT -lt 3 ] && continue 
    fi
done
[ "$VALID_AUTH" = false ] && { echo -e "${RED}❌ 授权失效。${PLAIN}"; exit 1; }

# --- [ 3. 模式与中文参数引导 ] ---
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "请选择模式："
echo -e "  1. 单节点"
echo -e "  2. 多节点冗余"
read -p "请输入数字: " DEPLOY_MODE

mkdir -p /etc/xray2
rm -f /etc/xray2/nodes.tmp 2>/dev/null

function write_node_json() {
    local index=$1
    echo -e "${YELLOW}---- 配置第 $index 个节点 ----${PLAIN}"
    read -p "【中文提示】面板地址(需带http端口): " R_URL
    read -p "【中文提示】面板密钥(ApiKey): " R_KEY
    read -p "【中文提示】节点ID(NodeID): " R_ID
    read -p "【中文提示】解析域名(域名需指向此服务器): " R_DOMAIN

    C_URL=$(echo "$R_URL" | tr -d '\r\n\x1b[' | sed 's/\/$//g' | xargs)
    [[ "$C_URL" != http* ]] && C_URL="https://$C_URL"
    C_KEY=$(echo "$RAW_KEY" | tr -d '\r\n\x1b[ ' | xargs)
    C_ID=$(echo "$R_ID" | tr -cd '0-9')
    C_DOMAIN=$(echo "$R_DOMAIN" | tr -d '\r\n\x1b[ ' | xargs)

    JSON_STR="{\"Core\":\"sing\",\"ApiHost\":\"$C_URL\",\"ApiKey\":\"$C_KEY\",\"NodeID\":$C_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$C_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
    
    if [ -f "/etc/xray2/nodes.tmp" ]; then echo ",$JSON_STR" >> /etc/xray2/nodes.tmp
    else echo "$JSON_STR" >> /etc/xray2/nodes.tmp; fi
}

[ "$DEPLOY_MODE" == "1" ] && write_node_json 1 || { read -p "总数: " NC; for((i=1;i<=NC;i++)); do write_node_json $i; done; }
NODE_CONTENT=$(cat /etc/xray2/nodes.tmp)

# --- [ 4. 性能与下载 ] ---
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc
killall -9 xray2_core 2>/dev/null
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip" || D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"
mkdir -p /usr/local/xray2
wget -q -O /usr/local/xray2/core.zip "$D_URL"
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core

# --- [ 5. 配置生成与脱水 ] ---
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
printf '{"Log":{"Level":"error"},"Internal_Buffer_Cache":"%s","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[%s],"Network_Token_Hash":"%s"}' "$S1" "$NODE_CONTENT" "$S2" > /etc/xray2/config.json
sed -i 's/[^[:print:]]//g' /etc/xray2/config.json
chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null

# --- [ 6. 智能管理脚本 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
case "\$1" in
    log)
        echo "---- 正在实时诊断运行状态 (按 Ctrl+C 退出) ----"
        journalctl -u xray2 -f | sed -u '
            s/.*timed out.*/\x1b[31m【警告】面板地址连接超时！请检查IP和端口是否填错，或防火墙是否放行。\x1b[0m/
            s/.*invalid character.*/\x1b[31m【错误】配置文件损坏或非法字符！请尝试重新安装。\x1b[0m/
            s/.*401 Unauthorized.*/\x1b[31m【警告】ApiKey 密钥错误！请对照面板修改。\x1b[0m/
            s/.*node not found.*/\x1b[31m【错误】节点ID不存在！请确认面板是否有此ID。\x1b[0m/
            s/.*rateLimited.*/\x1b[31m【警告】申请证书过快！域名已被暂时禁封，请换个域名或等几小时。\x1b[0m/
            s/.*Obtaining bundled SAN certificate.*/\x1b[32m【进度】正在为您的域名申请加密证书，请稍后...\x1b[0m/
        '
        ;;
    restart) systemctl restart xray2; echo "重启成功";;
    stop) systemctl stop xray2; echo "已停止";;
    uninstall) chattr -i /etc/xray2/config.json; rm -rf /usr/local/xray2 /etc/xray2 /usr/bin/x2; echo "已完全注销";;
    *) echo "指令: x2 {log|restart|stop|uninstall}";;
esac
EOF
chmod +x /usr/bin/x2

systemctl stop xray2 2>/dev/null
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 Service
After=network.target
[Service]
User=root
WorkingDirectory=/usr/local/xray2
ExecStart=/usr/local/xray2/xray2_core server -c /etc/xray2/config.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray2 && systemctl start xray2

clear
echo -e "${GREEN}======================================================${PLAIN}"
echo -e "✅ $BRAND_NAME 部署成功！"
echo -e "维护指令: ${YELLOW}x2 log${PLAIN} (如果连不上，请务必查看此日志提示)"
echo -e "${GREEN}======================================================${PLAIN}"
