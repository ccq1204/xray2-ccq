#!/bin/bash

# --- [ 1. 商业配置 ] ---
AD_URL="0000.7788.gg"
AD_TG="@jzllzf"
BRAND_NAME="xray2"
AUTH_DB="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth_md5.txt"

# --- [ 2. 授权验证 ] ---
clear
echo "======================================================"
echo "          $BRAND_NAME 商业版高性能转发系统"
echo "======================================================"
echo "  极昼流量转发官网: $AD_URL"
echo "  官方 Telegram 频道: $AD_TG"
echo "------------------------------------------------------"
read -p "请输入您的授权码 (Auth Key): " USER_INPUT
CLEAN_INPUT=$(echo -n "$USER_INPUT" | tr -cd '[:alnum:]')
AUTH_LIST=$(curl -H "Cache-Control: no-cache" -Ls "${AUTH_DB}?v=${RANDOM}" | tr -cd '[:alnum:]')

if [[ "$AUTH_LIST" == *"$CLEAN_INPUT"* ]] && [ -n "$CLEAN_INPUT" ]; then
    echo "✅ 授权验证成功！"
else
    echo "❌ 授权验证失败！请访问 $AD_URL 获取授权。"
    exit 1
fi

# --- [ 3. 模式选择 ] ---
echo "------------------------------------------------------"
echo "请选择部署模式："
echo "1. 单节点模式 (最快部署)"
echo "2. 多节点冗余模式 (自定义数量)"
read -p "请输入数字 (1-2): " DEPLOY_MODE
echo "------------------------------------------------------"

# --- [ 4. 参数获取 ] ---
exec < /dev/tty
NODE_JSON_CONFIG=""
if [ "$DEPLOY_MODE" == "1" ]; then
    read -p "1. 面板地址 (如 https://qie.myqieyun.net): " P_URL
    read -p "2. 面板密钥 (ApiKey): " P_KEY
    read -p "3. 节点 ID (NodeID): " P_ID
    read -p "4. 解析域名 (CertDomain): " P_DOMAIN
    NODE_JSON_CONFIG="{\"Core\":\"sing\",\"ApiHost\":\"$P_URL\",\"ApiKey\":\"$P_KEY\",\"NodeID\":$P_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$P_DOMAIN\",\"CertFile\":\"/etc/xray2/fullchain.cer\",\"KeyFile\":\"/etc/xray2/cert.key\"}}"
else
    read -p "请输入对接节点总数: " NODE_COUNT
    for ((i=1; i<=NODE_COUNT; i++))
    do
        echo "-- 配置第 $i 个节点 --"
        read -p "面板地址: " P_URL
        read -p "面板密钥: " P_KEY
        read -p "节点 ID: " P_ID
        read -p "解析域名: " P_DOMAIN
        ITEM="{\"Core\":\"sing\",\"ApiHost\":\"$P_URL\",\"ApiKey\":\"$P_KEY\",\"NodeID\":$P_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$P_DOMAIN\",\"CertFile\":\"/etc/xray2/fullchain.cer\",\"KeyFile\":\"/etc/xray2/cert.key\"}}"
        if [ "$i" -eq 1 ]; then NODE_JSON_CONFIG="$ITEM"; else NODE_JSON_CONFIG="$NODE_JSON_CONFIG,$ITEM"; fi
    done
fi

# --- [ 5. 安装准备 ] ---
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc
killall -9 xray2_core V2bX 2>/dev/null
mkdir -p /usr/local/xray2
wget -O /usr/local/xray2/core.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 6. 配置混淆与锁定 ] ---
mkdir -p /etc/xray2
chattr -i /etc/xray2/config.json 2>/dev/null
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 800 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 800 | head -n 1)
cat <<EOF > /etc/xray2/config.json
{"Log":{"Level":"error"},"Internal_Buffer_Hash":"$S1","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/sing_origin.json"}],"Nodes":[$NODE_JSON_CONFIG],"Network_Security_Token":"$S2"}
EOF
chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null

# --- [ 7. 规则文件同步 ] ---
wget -q -O /etc/xray2/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json

# --- [ 8. 系统服务定义 ] ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 Forwarding Service
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

# --- [ 9. 全功能维护指令 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
case "\$1" in
    log) journalctl -u xray2 -f ;;
    start) systemctl start xray2 ;;
    stop) systemctl stop xray2 ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2 ;;
    uninstall)
        read -p "确定要完全删除 $BRAND_NAME 吗? (y/n): " confirm
        if [ "\$confirm" == "y" ]; then
            systemctl disable xray2 --now
            chattr -i /etc/xray2/config.json 2>/dev/null
            rm -rf /usr/local/xray2 /etc/xray2 /etc/systemd/system/xray2.service /usr/bin/x2
            echo "✅ 已完全从系统中删除。"
        fi
        ;;
    *)
        echo "==============================="
        echo "   $BRAND_NAME 管理快捷菜单"
        echo "==============================="
        echo "  x2 log      - 查看运行日志"
        echo "  x2 restart  - 重启节点服务"
        echo "  x2 stop     - 停止节点服务"
        echo "  x2 start    - 启动节点服务"
        echo "  x2 uninstall- 彻底卸载删除"
        echo "==============================="
        ;;
esac
EOF
chmod +x /usr/bin/x2

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

# --- [ 10. 安装完成输出 ] ---
clear
echo "======================================================"
echo "✅ $BRAND_NAME 商业版部署成功！"
echo "------------------------------------------------------"
echo "  您可以使用快捷指令 [ x2 ] 来管理您的节点："
echo "------------------------------------------------------"
echo "  1. 查看日志: x2 log"
echo "  2. 重启服务: x2 restart"
echo "  3. 停止服务: x2 stop"
echo "  4. 启动服务: x2 start"
echo "  5. 彻底卸载: x2 uninstall"
echo "------------------------------------------------------"
echo "  官网: $AD_URL | TG: $AD_TG"
echo "======================================================"
