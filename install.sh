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

# --- [ 2. 授权验证 (静默增强版) ] ---
clear
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "${GREEN}          $BRAND_NAME 商业版高性能转发系统${PLAIN}"
echo -e "          作者：${YELLOW}$AUTHOR${PLAIN}"
echo -e "${BLUE}======================================================${PLAIN}"
echo -e "  极昼官网: ${YELLOW}$AD_URL${PLAIN}"
echo -e "  官方频道: ${YELLOW}$AD_TG${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"

# 强制重定向输入流，解决 curl | bash 冲突
exec < /dev/tty

# 预获取授权列表
AUTH_LIST=$(curl -H "Cache-Control: no-cache" -Lfs --connect-timeout 10 "${AUTH_DB}?v=${RANDOM}" | tr -cd '[:alnum:]')

RETRY_COUNT=0
VALID_AUTH=false
while [ $RETRY_COUNT -lt 3 ]; do
    read -p "请输入授权码: " USER_INPUT
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
[ "$VALID_AUTH" = false ] && { echo -e "${RED}❌ 授权验证失败，请联系管理员。${PLAIN}"; exit 1; }

# --- [ 3. 模式与中文参数引导 ] ---
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "请选择部署模式："
echo -e "  ${GREEN}1.${PLAIN} 单节点模式 (快速对接)"
echo -e "  ${GREEN}2.${PLAIN} 多节点冗余模式 (支持多API备份)"
read -p "请输入数字 (1-2): " DEPLOY_MODE

mkdir -p /etc/xray2
rm -f /etc/xray2/nodes.tmp 2>/dev/null

function write_node_json() {
    local index=$1
    echo -e "${YELLOW}---- 正在配置第 $index 个节点 ----${PLAIN}"
    read -p "【中文引导】面板地址(需带端口,如http://ip:1007): " R_URL
    read -p "【中文引导】面板密钥(ApiKey): " R_KEY
    read -p "【中文引导】节点ID(NodeID): " R_ID
    read -p "【中文引导】解析域名(需指向当前服务器IP): " R_DOMAIN

    # 参数物理清洗
    C_URL=$(echo "$R_URL" | tr -d '\r\n\x1b[' | sed 's/\/$//g' | xargs)
    [[ "$C_URL" != http* ]] && C_URL="https://$C_URL"
    C_KEY=$(echo "$R_KEY" | tr -d '\r\n\x1b[ ' | xargs)
    C_ID=$(echo "$R_ID" | tr -cd '0-9')
    C_DOMAIN=$(echo "$R_DOMAIN" | tr -d '\r\n\x1b[ ' | xargs)

    # 构建纯净片段
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
    read -p "请输入节点总数: " NODE_COUNT
    for ((i=1; i<=NODE_COUNT; i++)); do write_node_json $i; done
fi
NODE_CONTENT=$(cat /etc/xray2/nodes.tmp)

# --- [ 4. 商业级性能调优与环境准备 ] ---
echo -e "${YELLOW}正在优化系统参数并适配架构资源...${PLAIN}"
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc

# TCP 深度压榨与 BBR 开启
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p >/dev/null 2>&1
fi

# 修改文件并发上限
sed -i '/nofile/d' /etc/security/limits.conf
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# --- [ 5. 架构自适应下载 ] ---
killall -9 xray2_core V2bX 2>/dev/null
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip"
else
    D_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"
fi

mkdir -p /usr/local/xray2
wget -q -O /usr/local/xray2/core.zip "$D_URL"
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 6. 同步核心规则文件 ] ---
wget -q -O /etc/xray2/kernel_node.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route_rules.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns_config.bin https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# --- [ 7. 终极物理脱水：配置文件混淆锁定 ] ---
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)

# 写入临时文件
printf '{"Log":{"Level":"error"},"Internal_Buffer_Cache":"%s","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[%s],"Network_Token_Hash":"%s"}' "$S1" "$NODE_CONTENT" "$S2" > /etc/xray2/config.tmp

# 物理过滤非法字符 (彻底杀掉 \x1b)
sed -i 's/[^[:print:]]//g' /etc/xray2/config.tmp
mv /etc/xray2/config.tmp /etc/xray2/config.json

chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null
rm -f /etc/xray2/nodes.tmp

# --- [ 8. 智能诊断系统 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
PLAIN="\033[0m"

case "\$1" in
    log)
        echo -e "\${YELLOW}---- 正在智能诊断运行状态 (按 Ctrl+C 退出) ----\${PLAIN}"
        journalctl -u xray2 -f | sed -u '
            s/.*timed out.*/\x1b[31m【警告】面板地址连接超时！请检查IP和端口是否填错，或防火墙未开。\x1b[0m/
            s/.*invalid character.*/\x1b[31m【错误】配置文件包含非法字符！请重新安装。\x1b[0m/
            s/.*401 Unauthorized.*/\x1b[31m【警告】ApiKey 密钥错误！请检查面板设置。\x1b[0m/
            s/.*node not found.*/\x1b[31m【错误】节点ID不存在！请确认面板配置。\x1b[0m/
            s/.*no such file.*/\x1b[31m【致命】缺失核心规则文件，请尝试重新安装补丁！\x1b[0m/
            s/.*rateLimited.*/\x1b[31m【警告】域名证书申请过快，请更换域名或等2小时。\x1b[0m/
            s/.*Obtaining bundled SAN certificate.*/\x1b[32m【进度】正在为您的域名申请加密证书，请稍候...\x1b[0m/
        '
        ;;
    update)
        echo -e "\${YELLOW}正在静默检查商业补丁...\${PLAIN}"
        systemctl stop xray2
        ARCH=\$(uname -m)
        [ "\$ARCH" == "x86_64" ] && DURL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip" || DURL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"
        wget -q -O /tmp/x2.zip "\$DURL" && unzip -qo /tmp/x2.zip -d /tmp/x2_new
        mv -f /tmp/x2_new/V2bX /usr/local/xray2/xray2_core && chmod +x /usr/local/xray2/xray2_core
        systemctl start xray2 && echo -e "\${GREEN}补丁同步成功！当前已是最新版。\${PLAIN}" ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2; echo "重启成功" ;;
    stop) systemctl stop xray2; echo "转发已停止" ;;
    start) systemctl start xray2; echo "转发已启动" ;;
    uninstall)
        read -p "确定彻底注销所有商业数据吗? (y/n): " res
        if [ "\$res" == "y" ]; then
            systemctl disable xray2 --now
            chattr -i /etc/xray2/config.json 2>/dev/null
            rm -rf /usr/local/xray2 /etc/xray2 /etc/systemd/system/xray2.service /usr/bin/x2
            echo -e "\${GREEN}商业版已安全移除。\${PLAIN}"
        fi ;;
    *)
        echo -e "\${GREEN}===============================\${PLAIN}"
        echo -e "   $BRAND_NAME 管理系统 | 作者：$AUTHOR"
        echo -e "\${GREEN}===============================\${PLAIN}"
        echo -e "  x2 log      - 中文智能诊断 (必看)"
        echo -e "  x2 update   - 静默升级补丁"
        echo -e "  x2 restart  - 重启转发引擎"
        echo -e "  x2 stop     - 停止转发服务"
        echo -e "  x2 start    - 启动转发服务"
        echo -e "  x2 uninstall- 彻底注销清理"
        echo -e "\${GREEN}===============================\${PLAIN}"
        ;;
esac
EOF
chmod +x /usr/bin/x2

# --- [ 9. 服务化启动 ] ---
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

systemctl daemon-reload
systemctl enable xray2 && systemctl restart xray2

# --- [ 10. 终极成功面板输出 ] ---
clear
echo -e "${GREEN}======================================================${PLAIN}"
echo -e "${GREEN}✅ $BRAND_NAME 商业旗舰版部署成功！${PLAIN}"
echo -e "          作者：${YELLOW}$AUTHOR${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "  官网: ${YELLOW}$AD_URL${PLAIN} | 频道: ${YELLOW}$AD_TG${PLAIN}"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "${YELLOW}常用管理维护指令：${PLAIN}"
echo -e "  ${GREEN}x2 log${PLAIN}       - 查看日志 (带中文报错分析)"
echo -e "  ${GREEN}x2 restart${PLAIN}   - 重启服务"
echo -e "  ${GREEN}x2 update${PLAIN}    - 静默修复/升级补丁"
echo -e "  ${GREEN}x2 uninstall${PLAIN} - 彻底注销脚本"
echo -e "${BLUE}------------------------------------------------------${PLAIN}"
echo -e "  温馨提示: 配置文件已物理锁定，输入 ${GREEN}x2${PLAIN} 查看菜单"
echo -e "${GREEN}======================================================${PLAIN}"
