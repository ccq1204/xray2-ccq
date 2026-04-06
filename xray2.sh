#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用 root 用户运行此脚本！\n" && exit 1

show_menu() {
    clear
    echo -e "    ${GREEN}xray2 后端管理脚本 (商业加速版)${PLAIN}"
    echo -e "--- https://github.com/ccq1204/xray2-ccq ---"
    echo -e "  ${YELLOW}0.${PLAIN}  修改配置 (已锁定，需联系管理员)"
    echo -e "————————————————————————————————————————————"
    echo -e "  ${GREEN}1.${PLAIN}  安装 xray2"
    echo -e "  ${GREEN}2.${PLAIN}  更新 xray2"
    echo -e "  ${RED}3.${PLAIN}  卸载 xray2"
    echo -e "————————————————————————————————————————————"
    echo -e "  ${GREEN}4.${PLAIN}  启动 xray2"
    echo -e "  ${RED}5.${PLAIN}  停止 xray2"
    echo -e "  ${YELLOW}6.${PLAIN}  重启 xray2"
    echo -e "  ${GREEN}7.${PLAIN}  查看 xray2 状态"
    echo -e "  ${YELLOW}8.${PLAIN}  查看 xray2 日志"
    echo -e "————————————————————————————————————————————"
    echo -e "  ${GREEN}9.${PLAIN}  设置 开机自启"
    echo -e "  ${RED}10.${PLAIN} 取消 开机自启"
    echo -e "————————————————————————————————————————————"
    echo -e "  ${GREEN}11.${PLAIN} 一键安装 BBR (官方原版)"
    echo -e "  ${GREEN}12.${PLAIN} 查看核心版本"
    echo -e "  ${YELLOW}15.${PLAIN} 重新拉取云端配置 (更新授权/配置)"
    echo -e "  ${GREEN}16.${PLAIN} 放行所有网络端口 (iptables)"
    echo -e "  ${RED}17.${PLAIN} 退出脚本"
    echo -ne "\n请输入选择 [0-17]: "
}

# 逻辑判断
handle_choice() {
    case $1 in
        1|2) wget -N https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/install.sh && bash install.sh ;;
        3) 
            systemctl stop xray2 && systemctl disable xray2
            rm -rf /usr/local/xray2 /etc/xray2 /usr/bin/xray2 /etc/systemd/system/xray2.service
            echo -e "${GREEN}卸载完成！${PLAIN}" ;;
        4) systemctl start xray2 && echo -e "${GREEN}已启动！${PLAIN}" ;;
        5) systemctl stop xray2 && echo -e "${RED}已停止！${PLAIN}" ;;
        6) systemctl restart xray2 && echo -e "${GREEN}已重启！${PLAIN}" ;;
        7) systemctl status xray2 ;;
        8) journalctl -u xray2 -f ;;
        9) systemctl enable xray2 && echo -e "${GREEN}已设为开机自启！${PLAIN}" ;;
        10) systemctl disable xray2 && echo -e "${YELLOW}已取消开机自启！${PLAIN}" ;;
        11) wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh ;;
        12) /usr/local/xray2/xray2 -version ;;
        15) 
            echo -e "${YELLOW}正在解除配置锁定并重新安装...${PLAIN}"
            chattr -i /etc/xray2/config.json 2>/dev/null
            wget -N https://raw.githubusercontent.com/ccq1204/xray2-ccq/main/install.sh && bash install.sh ;;
        16)
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            iptables -F
            echo -e "${GREEN}所有防火墙端口已放行！${PLAIN}" ;;
        17) exit 0 ;;
        *) echo -e "${RED}请输入正确的数字！${PLAIN}" ;;
    esac
}

# 支持命令行参数直接运行，如: xray2 restart
if [[ $# -gt 0 ]]; then
    handle_choice "$1"
else
    show_menu
    read check_set
    handle_choice "$check_set"
fi
