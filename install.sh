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
echo "======================================================"

# --- [ 3. 模式选择 ] ---
echo "请选择部署模式："
echo "1. 单节点模式 (最快部署)"
echo "2. 多节点冗余模式 (自定义节点数量)"
read -p "请输入数字 (1-2): " DEPLOY_MODE
echo "------------------------------------------------------"

# --- [ 4. 参数获取 ] ---
exec < /dev/tty
NODE_JSON_CONFIG=""

if [ "$DEPLOY_MODE" == "1" ]; then
    echo "[单节点配置向导]"
    read -p "1. 请输入面板地址 (如 https://qie.myqieyun.net): " P_URL
    read -p "2. 请输入面板密钥 (ApiKey): " P_KEY
    read -p "3. 请输入节点 ID (NodeID): " P_ID
    read -p "4. 请输入解析域名 (CertDomain): " P_DOMAIN
    
    # 构建单节点 JSON 片段
    NODE_JSON_CONFIG="{\"Core\":\"sing\",\"ApiHost\":\"$P_URL\",\"ApiKey\":\"$P_KEY\",\"NodeID\":$P_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$P_DOMAIN\",\"CertFile\":\"/etc/xray2/fullchain.cer\",\"KeyFile\":\"/etc/xray2/cert.key\"}}"
else
    echo "[多节点冗余配置向导]"
    read -p "请输入您要对接的节点总数 (例如 2 或 5): " NODE_COUNT
    for ((i=1; i<=NODE_COUNT; i++))
    do
        echo "---- 正在配置第 $i 个节点 ----"
        read -p "请输入第 $i 个面板地址: " P_URL
        read -p "请输入第 $i 个面板密钥: " P_KEY
        read -p "请输入第 $i 个节点 ID: " P_ID
        read -p "请输入第 $i 个解析域名: " P_DOMAIN
        
        ITEM="{\"Core\":\"sing\",\"ApiHost\":\"$P_URL\",\"ApiKey\":\"$P_KEY\",\"NodeID\":$P_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$P_DOMAIN\",\"CertFile\":\"/etc/xray2/fullchain.cer\",\"KeyFile\":\"/etc/xray2/cert.key\"}}"
        
        # 拼接 JSON 片段，处理逗号
        if [ "$i" -eq 1 ]; then
            NODE_JSON_CONFIG="$ITEM"
        else
            NODE_JSON_CONFIG="$NODE_JSON_CONFIG,$ITEM"
        fi
    done
fi

# --- [ 5. 品牌安装 ] ---
apt-get update -y && apt-get install -y curl wget tar unzip
mkdir -p /usr/local/xray2
wget -O /usr/local/xray2/core.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 6. 配置文件动态生成 ] ---
mkdir -p /etc/xray2
cat <<EOF > /etc/xray2/config.json
{"Log":{"Level":"error","Output":""},"Cores":[{"Type":"sing","Log":{"Level":"error","Timestamp":true},"NTP":{"Enable":false,"Server":"time.apple.com","ServerPort":0},"OriginalPath":"/etc/xray2/sing_origin.json"}],"Nodes":[$NODE_JSON_CONFIG]}
EOF
chmod 600 /etc/xray2/config.json

# --- [ 7. 同步规则文件 ] ---
wget -q -O /etc/xray2/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json
sed -i 's/\r//g' /etc/xray2/*.json

# --- [ 8. 系统服务与快捷指令 ] ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 High Performance Service
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
    restart) systemctl restart xray2 ;;
    *) echo "指令: x2 {log|restart}" ;;
esac
EOF
chmod +x /usr/bin/x2

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

clear
echo "======================================================"
echo "✅ $BRAND_NAME 部署成功！"
echo "已根据您的输入生成了 $DEPLOY_MODE 模式配置。"
echo "------------------------------------------------------"
echo "  管理指令: x2 log"
echo "======================================================"
