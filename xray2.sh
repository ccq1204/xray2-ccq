#!/bin/bash

# --- 1. 商业授权 ---
AUTH_LIST_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth.txt"
if ! command -v curl &> /dev/null; then apt update && apt install curl -y; fi
clear
echo "==============================================="
echo "       Xray2 商业版 - 专属授权验证"
echo "==============================================="
read -p "请输入您的授权码: " user_key
auth_line=$(curl -sL $AUTH_LIST_URL | grep "^$user_key:")
if [[ -n "$auth_line" ]]; then
    echo -e "\033[32m[√] 验证通过！\033[0m"
else
    echo -e "\033[31m[X] 授权无效！\033[0m"
    exit 1
fi

# --- 2. 检查是否已安装 (已安装则直接弹菜单) ---
if [ -f "/usr/bin/xray2_core" ]; then
    bash <(curl -sL https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh) | sed 's/V2bX/Xray2/g'
    exit 0
fi

# --- 3. 首次安装逻辑 ---
echo "正在为您部署 Xray2 核心..."
mkdir -p /usr/local/Xray2 /etc/Xray2
# 强制拉取确定的内核
wget -O /usr/local/Xray2/core.zip https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/core.zip
apt install unzip -y
unzip -o /usr/local/Xray2/core.zip -d /usr/local/Xray2/
chmod +x /usr/local/Xray2/V2bX
ln -sf /usr/local/Xray2/V2bX /usr/bin/xray2_core

# 写入菜单快捷方式
cat > /usr/bin/xray2 <<'INNER'
#!/bin/bash
bash <(curl -sL https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh) | sed 's/V2bX/Xray2/g'
INNER
chmod +x /usr/bin/xray2

# 写入系统服务
cat > /etc/systemd/system/xray2.service <<SERVICES
[Unit]
Description=Xray2 Service
After=network.target
[Service]
ExecStart=/usr/bin/xray2_core -config /etc/Xray2/config.yml
Restart=on-failure
[Install]
WantedBy=multi-user.target
SERVICES

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

echo "安装完成！直接输入 xray2 呼出菜单。"
