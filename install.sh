#!/bin/bash

# --- [ 商业配置区 ] ---
AD_URL="0000.7788.gg"
AD_TG="@jzllzf"
BRAND_NAME="xray2"
# 授权码 MD5 列表地址 (请确保你在仓库里创建了这个文件)
AUTH_DB="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth_md5.txt"

# --- 1. 开屏广告与授权验证 ---
clear
echo "======================================================"
echo "          $BRAND_NAME 商业版高性能转发系统"
echo "======================================================"
echo "  极昼流量转发官网: $AD_URL"
echo "  官方 Telegram 频道: $AD_TG"
echo "------------------------------------------------------"
read -p "请输入您的授权码 (Auth Key): " USER_INPUT

# 将用户输入转为 MD5 进行比对，防止授权码泄露
USER_MD5=$(echo -n "$USER_INPUT" | md5sum | cut -d ' ' -f 1)

if ! curl -Ls "$AUTH_DB" | grep -q "$USER_MD5"; then
    echo "❌ 授权验证失败！请访问 $AD_URL 获取授权。"
    exit 1
fi
echo "✅ 授权成功，欢迎使用极昼流量转发系统！"
echo "======================================================"

# --- 2. 基础环境自动化 ---
apt-get update -y && apt-get install -y curl wget tar unzip
exec < /dev/tty

# --- 3. 商业参数注入 (广告二次展示) ---
echo "请根据 $AD_TG 提供的参数进行配置："
read -p "1. 节点对接地址 (ApiHost): " RAW_URL
read -p "2. 节点对接密钥 (ApiKey): " RAW_KEY
read -p "3. 节点唯一 ID (NodeID): " RAW_ID
read -p "4. 节点解析域名 (CertDomain): " RAW_DOMAIN

# 过滤 Windows 换行符与空格
PANEL_URL=$(echo "$RAW_URL" | tr -d '\r' | xargs)
PANEL_KEY=$(echo "$RAW_KEY" | tr -d '\r' | xargs)
NODE_ID=$(echo "$RAW_ID" | tr -d '\r' | xargs)
CERT_DOMAIN=$(echo "$RAW_DOMAIN" | tr -d '\r' | xargs)

# --- 4. 品牌重塑：安装并重命名核心 ---
# 目录完全去 V2bX 化
mkdir -p /usr/local/xray2
wget -O /usr/local/xray2/xray2_core.zip https://github.com/wyx2685/V2bX/releases/download/v0.4.0/V2bX-linux-64.zip
unzip -o /usr/local/xray2/xray2_core.zip -d /usr/local/xray2
# 彻底改名
mv /usr/local/xray2/V2bX /usr/local/xray2/xray2_core
chmod +x /usr/local/xray2/xray2_core
ln -sf /usr/local/xray2/xray2_core /usr/bin/xray2

# --- 5. 配置加密隐藏 (单行压缩 + 权限锁定) ---
mkdir -p /etc/xray2
# 写入单行压缩配置，让用户看不懂
cat <<EOF > /etc/xray2/config.json
{"Log":{"Level":"error","Output":""},"Cores":[{"Type":"sing","Log":{"Level":"error","Timestamp":true},"NTP":{"Enable":false,"Server":"time.apple.com","ServerPort":0},"OriginalPath":"/etc/xray2/sing_origin.json"}],"Nodes":[{"Core":"sing","ApiHost":"${PANEL_URL}","ApiKey":"${PANEL_KEY}","NodeID":${NODE_ID},"NodeType":"anytls","Timeout":30,"ListenIP":"::","SendIP":"0.0.0.0","DeviceOnlineMinTraffic":200,"MinReportTraffic":0,"TCPFastOpen":false,"SniffEnabled":true,"CertConfig":{"CertMode":"http","RejectUnknownSni":false,"CertDomain":"${CERT_DOMAIN}","CertFile":"/etc/xray2/fullchain.cer","KeyFile":"/etc/xray2/cert.key","Email":"v2bx@github.com","Provider":"cloudflare","DNSEnv":{"EnvName":"env1"}}}]}
EOF
# 权限锁定，只有 root 能读
chmod 600 /etc/xray2/config.json

# --- 6. 同步后端规则文件 (路径同步改名) ---
wget -q -O /etc/xray2/sing_origin.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/sing_origin.json
wget -q -O /etc/xray2/route.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/route.json
wget -q -O /etc/xray2/dns.json https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/dns.json
sed -i 's/\r//g' /etc/xray2/*.json

# --- 7. 系统服务重塑 ---
cat <<EOF > /etc/systemd/system/xray2.service
[Unit]
Description=xray2 Commercial Service
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

# --- 8. 商业版快捷指令 x2 ---
cat <<EOF > /usr/bin/x2
#!/bin/bash
case "\$1" in
    log) journalctl -u xray2 -f ;;
    restart) systemctl restart xray2 ;;
    *) echo "极昼流量转发系统 - 使用说明: x2 {log|restart}" ;;
esac
EOF
chmod +x /usr/bin/x2

# --- 9. 启动 ---
systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

clear
echo "======================================================"
echo "✅ $BRAND_NAME 商业版部署成功！"
echo "------------------------------------------------------"
echo "  极昼流量转发官网: $AD_URL"
echo "  官方 TG 频道: $AD_TG"
echo "------------------------------------------------------"
echo "  节点管理命令: x2 log"
echo "======================================================"
