# 3. 验证授权 (极致兼容版)
echo "正在发起云端验证..."

# 1. 强制 IPv4 (-4)
# 2. 忽略证书 (-k)
# 3. 追踪重定向 (-L)
# 4. 伪装浏览器 (-A)
# 5. 获取 HTTP 状态码并存入变量
HTTP_RESPONSE=$(curl -4 -sLk -w "%{http_code}" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "http://64.118.148.160/check.php?code=$LICENSE")

# 提取 HTTP 状态码（最后三位）
HTTP_STATUS="${HTTP_RESPONSE: -3}"
# 提取返回内容（去掉最后三位状态码）
CONF_DATA="${HTTP_RESPONSE:0:${#HTTP_RESPONSE}-3}"

# 清理掉返回内容里可能的换行符、空格
CONF_DATA=$(echo "$CONF_DATA" | tr -d '\r\n[:space:]')

echo "-------------------------------------------"
echo "调试信息: HTTP状态码 [$HTTP_STATUS]"
echo "调试信息: 原始信号内容 [${CONF_DATA}]"
echo "-------------------------------------------"

if [[ "$CONF_DATA" == *"success"* ]]; then
    echo "✅ 授权验证通过！"
    
    # --- 以下是安装逻辑，请确保这些目录存在 ---
    systemctl stop xray2 2>/dev/null
    rm -rf /usr/local/xray2 /etc/xray2
    mkdir -p /etc/xray2 /usr/local/xray2
    
    # [此处继续你原本的 wget 下载核心、写入配置等逻辑...]
    
else
    echo "❌ 验证失败！"
    if [ "$HTTP_STATUS" == "000" ]; then
        echo "原因：VPS 无法连接到母机，请检查母机 80 端口或防火墙。"
    elif [ "$HTTP_STATUS" == "404" ]; then
        echo "原因：找不到 check.php 文件，请检查母机路径。"
    else
        echo "原因：服务器返回了无效内容 [$CONF_DATA]"
    fi
    exit 1
fi
