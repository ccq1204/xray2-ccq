#!/bin/bash

# --- [ 1. 商业配置区 ] ---
AD_URL="0000.7788.gg"
AD_TG="@jzllzf"
BRAND_NAME="xray2"
# 授权库地址 (现在里面直接存明文，比如 7788)
AUTH_DB="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth_md5.txt"

# --- [ 2. 授权验证逻辑 (明文硬匹配) ] ---
clear
echo "======================================================"
echo "          $BRAND_NAME 商业版高性能转发系统"
echo "======================================================"
echo "  极昼流量转发官网: $AD_URL"
echo "  官方 Telegram 频道: $AD_TG"
echo "------------------------------------------------------"
read -p "请输入您的授权码 (Auth Key): " USER_INPUT

# 暴力清洗输入：只保留字母和数字，删掉所有空格、回车、控制符
CLEAN_INPUT=$(echo -n "$USER_INPUT" | tr -cd '[:alnum:]')

# 强制获取远程列表并清洗 (只留字母数字)
AUTH_LIST=$(curl -H "Cache-Control: no-cache" -Ls "${AUTH_DB}?v=${RANDOM}" | tr -cd '[:alnum:]')

# 只要远程列表里包含用户输入的这个字符串，就过
if [[ "$AUTH_LIST" == *"$CLEAN_INPUT"* ]] && [ -n "$CLEAN_INPUT" ]; then
    echo "✅ 授权验证成功！"
else
    echo "❌ 授权验证失败！请访问 $AD_URL 获取授权。"
    exit 1
fi
echo "======================================================"

# --- [ 3. 基础环境 ] ---
apt-get update -y && apt-get install -y curl wget tar unzip
exec < /dev/tty

# --- [ 4. 参数获取 ] ---
read -p "1. ApiHost: " RAW_URL
read -p "2. ApiKey: " RAW_KEY
read -p "3. NodeID: " RAW_ID
read -p "4. CertDomain: " RAW_DOMAIN

PANEL_URL=$(echo "$RAW_URL" | tr -d '\r' | xargs)
PANEL_KEY=$(echo "$RAW_KEY" | tr -d '\r' | xargs)
NODE_ID=$(echo "$RAW_ID" | tr -d '\r' | xargs)
CERT_DOMAIN=$(echo "$RAW_DOMAIN" | tr -d '\r' | xargs)

# --- [ 5. 抹除痕迹安装 ] ---
mkdir -p /usr/local/xray2
wget -O /usr/local/xray2/core.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/xray2/core.zip -d /usr/local/xray2
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- [ 6. 配置单行混淆 ] ---
mkdir -p /etc/xray2
cat <<EOF > /etc/xray2/config.json
{"Log":{"Level":"error","Output":""},"Cores":[{"Type":"sing","Log":{"Level":"error","Timestamp":true},"NTP":{"Enable":false,"Server":"time.apple.com","ServerPort":0},"OriginalPath":"/etc/xray2/sing_origin.json"}],"Nodes":[{"Core":"sing","ApiHost":"${PANEL_URL}","ApiKey":"${PANEL_KEY}","NodeID":${NODE_ID},"NodeType":"anytls","Timeout":30,"ListenIP":"::","SendIP":"0.0.0.0","DeviceOnlineMinTraffic":200,"MinReportTraffic":0,"TCPFastOpen":false,"SniffEnabled":true,"CertConfig":{"CertMode":"http","RejectUnknownSni":false,"CertDomain":"${CERT_DOMAIN}","CertFile":"/etc/xray2/fullchain.cer","KeyFile":"/etc/xray2/cert.key","Email":"v2bx@github.com","Provider":"cloudflare","DNSEnv":{"EnvName":"env1"}}}]}
EOF
chmod 600 /etc/xray2/config.json

# --- [ 7. 同步文件 ] ---
wget -q -O /etc/xray2/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json
sed -i 's/\r//g' /etc/xray2/*.json

# --- [ 8. 服务化 ] ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 Service
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

# --- [ 9. 管理快捷键 ] ---
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
echo "管理命令: x2 log"
echo "======================================================"
