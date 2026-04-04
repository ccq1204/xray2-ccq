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

# --- 2. 写入永久管理菜单 (不再去 GitHub 下脚本，直接本地化) ---
# 我们把管理逻辑直接塞进 /usr/bin/xray2
cat > /usr/bin/xray2 <<'MENU'
#!/bin/bash
# 简单的管理菜单逻辑
show_menu() {
    clear
    echo "Xray2 商业版管理快捷菜单"
    echo "------------------------"
    echo "1. 重启 Xray2"
    echo "2. 停止 Xray2"
    echo "3. 查看 实时日志 (对接检查)"
    echo "4. 修改 配置文件 (对接面板)"
    echo "0. 退出"
    echo "------------------------"
    read -p "请选择: " num
    case $num in
        1) systemctl restart xray2 ;;
        2) systemctl stop xray2 ;;
        3) journalctl -u xray2 -f ;;
        4) nano /etc/Xray2/config.yml ;;
        *) exit ;;
    esac
}

if [ $# -gt 0 ]; then
    case $1 in
        restart) systemctl restart xray2 ;;
        log) journalctl -u xray2 -f ;;
        *) echo "未知参数" ;;
    esac
else
    show_menu
fi
MENU
chmod +x /usr/bin/xray2

# --- 3. 部署核心和服务 ---
mkdir -p /usr/local/Xray2 /etc/Xray2
wget -O /usr/local/Xray2/core.zip https://gh-proxy.com/https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/core.zip
apt install unzip nano -y
unzip -o /usr/local/Xray2/core.zip -d /usr/local/Xray2/
chmod +x /usr/local/Xray2/V2bX

cat > /etc/systemd/system/xray2.service <<SERVICES
[Unit]
Description=Xray2 Service
After=network.target
[Service]
ExecStart=/usr/local/Xray2/V2bX -config /etc/Xray2/config.yml
Restart=on-failure
[Install]
WantedBy=multi-user.target
SERVICES

systemctl daemon-reload
systemctl enable xray2
systemctl restart xray2

echo "==============================================="
echo "   安装成功！直接输入 xray2 即可管理。"
echo "   请按 4 修改配置对接 V2Board 面板。"
echo "==============================================="
