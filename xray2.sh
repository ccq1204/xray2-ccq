#!/bin/bash

# --- 商业授权验证 ---
AUTH_LIST_URL="https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/auth.txt"

clear
echo "==============================================="
echo "       Xray2 商业版 - 专属授权验证"
echo "==============================================="

if ! command -v curl &> /dev/null; then apt update && apt install curl -y; fi

read -p "请输入您的授权码: " user_key
auth_line=$(curl -sL $AUTH_LIST_URL | grep "^$user_key:")

if [[ -n "$auth_line" ]]; then
    expiry=$(echo $auth_line | cut -d':' -f2)
    echo -e "\033[32m[√] 授权通过！有效期至: $expiry\033[0m"
    sleep 1
else
    echo -e "\033[31m[X] 授权无效或已过期！\033[0m"
    exit 1
fi

# --- 执行本地安装逻辑 ---
chmod +x install.sh
./install.sh
