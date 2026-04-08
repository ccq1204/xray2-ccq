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
    read -p "1. 面板地址 (ApiHost): " P_URL
    read -p "2. 面板密钥 (ApiKey): " P_KEY
    read -p "3. 节点 ID (NodeID): " P_ID
    read -p "4. 解析域名 (CertDomain): " P_DOMAIN
    NODE_JSON_CONFIG="{\"Core\":\"sing\",\"ApiHost\":\"$P_URL\",\"ApiKey\":\"$P_KEY\",\"NodeID\":$P_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$P_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
else
    read -p "请输入对接节点总数: " NODE_COUNT
    for ((i=1; i<=NODE_COUNT; i++))
    do
        echo "-- 配置第 $i 个节点 --"
        read -p "面板地址: " P_URL
        read -p "面板密钥: " P_KEY
        read -p "节点 ID: " P_ID
        read -p "解析域名: " P_DOMAIN
        ITEM="{\"Core\":\"sing\",\"ApiHost\":\"$P_URL\",\"ApiKey\":\"$P_KEY\",\"NodeID\":$P_ID,\"NodeType\":\"anytls\",\"Timeout\":30,\"ListenIP\":\"::\",\"SendIP\":\"0.0.0.0\",\"CertConfig\":{\"CertMode\":\"http\",\"CertDomain\":\"$P_DOMAIN\",\"CertFile\":\"/etc/xray2/sys_cert.dat\",\"KeyFile\":\"/etc/xray2/sys_key.dat\"}}"
        if [ "$i" -eq 1 ]; then NODE_JSON_CONFIG="$ITEM"; else NODE_JSON_CONFIG="$NODE_JSON_CONFIG,$ITEM"; fi
    done
fi

# --- [ 5. 品牌环境准备 (全架构支持版) ] ---
apt-get update -y && apt-get install -y curl wget tar unzip e2fsprogs psmisc
killall -9 xray2_core V2bX 2>/dev/null

# 检测 CPU 架构
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    DOWNLOAD_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip"
elif [ "$ARCH" == "aarch64" ]; then
    DOWNLOAD_URL="https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-arm64-v8a.zip"
else
    echo "❌ 抱歉，暂不支持您的 CPU 架构: $ARCH"
    exit 1
fi

mkdir -p /usr/local/xray2
echo "正在下载适合 $ARCH 架构的商业内核..."
wget -O /usr/local/xray2/core.zip "$DOWNLOAD_URL"

unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 6. 核心配置：深度伪装混淆 ] ---
mkdir -p /etc/xray2
chattr -i /etc/xray2/config.json 2>/dev/null
# 生成 1000 位乱码，模拟加密 Head
S1=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)
S2=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1)

# 将 sing 夹杂在看起来像内核序列号的字符串里
cat <<EOF > /etc/xray2/config.json
{"Log":{"Level":"error"},"Kernel_Module_Verify":"$S1","Cores":[{"Type":"sing","Log":{"Level":"error"},"OriginalPath":"/etc/xray2/kernel_node.bin"}],"Nodes":[$NODE_JSON_CONFIG],"Security_Token_Hash":"$S2"}
EOF

chmod 400 /etc/xray2/config.json
chattr +i /etc/xray2/config.json 2>/dev/null

# --- [ 7. 文件名伪装 ] ---
# 把容易看懂的 json 全部改成 .bin 或 .dat 这种“不可读数据”后缀
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

# --- [ 9. 管理指令 x2 ] ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
case "\$1" in
    log) journalctl -u xray2 -f ;;
    start) systemctl start xray2 ;;
    stop) systemctl stop xray2 ;;
    restart) systemctl stop xray2; killall -9 xray2_core 2>/dev/null; systemctl start xray2 ;;
    uninstall)
        read -p "确定卸载并清理所有商业授权数据吗? (y/n): " confirm
        if [ "\$confirm" == "y" ]; then
            systemctl disable xray2 --now
            chattr -i /etc/xray2/config.json 2>/dev/null
            rm -rf /usr/local/xray2 /etc/xray2 /etc/systemd/system/xray2.service /usr/bin/x2
            echo "✅ 清理完成。"
        fi
        ;;
    *)
        echo "==============================="
        echo "   $BRAND_NAME 商业管理菜单"
        echo "==============================="
        echo "  x2 log      - 查看内核状态"
        echo "  x2 restart  - 重启加密链路"
        echo "  x2 stop     - 停止转发"
        echo "  x2 start    - 开启转发"
        echo "  x2 uninstall- 彻底卸载删除"
        echo "==============================="
        ;;
esac
EOF
chmod +x /usr/bin/x2

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

# --- [ 10. 完成提示 ] ---
clear
echo "======================================================"
echo "✅ $BRAND_NAME 商业授权版部署成功！"
echo "------------------------------------------------------"
echo "  快捷管理菜单 [ x2 ]："
echo "------------------------------------------------------"
echo "  1. 查看日志: x2 log"
echo "  2. 重启服务: x2 restart"
echo "  3. 彻底卸载: x2 uninstall"
echo "------------------------------------------------------"
echo "  官网: $AD_URL | TG: $AD_TG"
echo "======================================================"
