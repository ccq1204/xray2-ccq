#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "arch"; then
    release="arch"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(uname -m)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}注意： CentOS 7 无法使用hysteria1/2协议！${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release wget curl unzip tar crontabs socat ca-certificates -y >/dev/null 2>&1
        update-ca-trust force-enable >/dev/null 2>&1
    elif [[ x"${release}" == x"alpine" ]]; then
        apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"debian" ]]; then
        apt-get update -y >/dev/null 2>&1
        apt install wget curl unzip tar cron socat ca-certificates -y >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"ubuntu" ]]; then
        apt-get update -y >/dev/null 2>&1
        apt install wget curl unzip tar cron socat -y >/dev/null 2>&1
        apt-get install ca-certificates wget -y >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"arch" ]]; then
        pacman -Sy --noconfirm >/dev/null 2>&1
        pacman -S --noconfirm --needed wget curl unzip tar cron socat >/dev/null 2>&1
        pacman -S --noconfirm --needed ca-certificates wget >/dev/null 2>&1
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /usr/local/Xray2/Xray2 ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service Xray2 status | awk '{print $3}')
        if [[ x"${temp}" == x"started" ]]; then
            return 0
        else
            return 1
        fi
    else
        temp=$(systemctl status Xray2 | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        if [[ x"${temp}" == x"running" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

install_Xray2() {
    if [[ -e /usr/local/Xray2/ ]]; then
        rm -rf /usr/local/Xray2/
    fi

    mkdir /usr/local/Xray2/ -p
    cd /usr/local/Xray2/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/wyx2685/Xray2/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 Xray2 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 Xray2 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 Xray2 最新版本：${last_version}，开始安装"
        wget --no-check-certificate -N --progress=bar -O /usr/local/Xray2/Xray2-linux.zip https://github.com/wyx2685/V2bX/releases/download/${last_version}/Xray2-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 Xray2 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/wyx2685/V2bX/releases/download/${last_version}/Xray2-linux-${arch}.zip"
        echo -e "开始安装 Xray2 $1"
        wget --no-check-certificate -N --progress=bar -O /usr/local/Xray2/Xray2-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 Xray2 $1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip Xray2-linux.zip
    rm Xray2-linux.zip -f
    chmod +x Xray2
    mkdir /etc/Xray2/ -p
    cp geoip.dat /etc/Xray2/
    cp geosite.dat /etc/Xray2/
    if [[ x"${release}" == x"alpine" ]]; then
        rm /etc/init.d/Xray2 -f
        cat <<EOF > /etc/init.d/Xray2
#!/sbin/openrc-run

name="Xray2"
description="Xray2"

command="/usr/local/Xray2/Xray2"
command_args="server"
command_user="root"

pidfile="/run/Xray2.pid"
command_background="yes"

depend() {
        need net
}
EOF
        chmod +x /etc/init.d/Xray2
        rc-update add Xray2 default
        echo -e "${green}Xray2 ${last_version}${plain} 安装完成，已设置开机自启"
    else
        rm /etc/systemd/system/Xray2.service -f
        cat <<EOF > /etc/systemd/system/Xray2.service
[Unit]
Description=Xray2 Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999
WorkingDirectory=/usr/local/Xray2/
ExecStart=/usr/local/Xray2/Xray2 server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl stop Xray2
        systemctl enable Xray2
        echo -e "${green}Xray2 ${last_version}${plain} 安装完成，已设置开机自启"
    fi

    if [[ ! -f /etc/Xray2/config.json ]]; then
        cp config.json /etc/Xray2/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://xray2.v-50.me/，配置必要的内容"
        first_install=true
    else
        if [[ x"${release}" == x"alpine" ]]; then
            service Xray2 start
        else
            systemctl start Xray2
        fi
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Xray2 重启成功${plain}"
        else
            echo -e "${red}Xray2 可能启动失败，请稍后使用 Xray2 log 查看日志信息，若无法启动，则可能更改了配置格式，请前往 wiki 查看：https://github.com/Xray2-project/Xray2/wiki${plain}"
        fi
        first_install=false
    fi

    if [[ ! -f /etc/Xray2/dns.json ]]; then
        cp dns.json /etc/Xray2/
    fi
    if [[ ! -f /etc/Xray2/route.json ]]; then
        cp route.json /etc/Xray2/
    fi
    if [[ ! -f /etc/Xray2/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/Xray2/
    fi
    if [[ ! -f /etc/Xray2/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/Xray2/
    fi
    curl -o /usr/bin/Xray2 -Ls https://raw.githubusercontent.com/wyx2685/Xray2-script/master/Xray2.sh
    chmod +x /usr/bin/Xray2
    if [ ! -L /usr/bin/xray2 ]; then
        ln -s /usr/bin/Xray2 /usr/bin/xray2
        chmod +x /usr/bin/xray2
    fi
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Xray2 管理脚本使用方法 (兼容使用Xray2执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "Xray2              - 显示管理菜单 (功能更多)"
    echo "Xray2 start        - 启动 Xray2"
    echo "Xray2 stop         - 停止 Xray2"
    echo "Xray2 restart      - 重启 Xray2"
    echo "Xray2 status       - 查看 Xray2 状态"
    echo "Xray2 enable       - 设置 Xray2 开机自启"
    echo "Xray2 disable      - 取消 Xray2 开机自启"
    echo "Xray2 log          - 查看 Xray2 日志"
    echo "Xray2 x25519       - 生成 x25519 密钥"
    echo "Xray2 generate     - 生成 Xray2 配置文件"
    echo "Xray2 update       - 更新 Xray2"
    echo "Xray2 update x.x.x - 更新 Xray2 指定版本"
    echo "Xray2 install      - 安装 Xray2"
    echo "Xray2 uninstall    - 卸载 Xray2"
    echo "Xray2 version      - 查看 Xray2 版本"
    echo "------------------------------------------"
    curl -fsS --max-time 10 "https://api.v-50.me/counter_xray2" || true
    # 首次安装询问是否生成配置文件
    if [[ $first_install == true ]]; then
        read -rp "检测到你为第一次安装Xray2,是否自动直接生成配置文件？(y/n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            curl -o ./initconfig.sh -Ls https://raw.githubusercontent.com/wyx2685/Xray2-script/master/initconfig.sh
            source initconfig.sh
            rm initconfig.sh -f
            generate_config_file
        fi
    fi
}

echo -e "${green}开始安装${plain}"
install_base
install_Xray2 $1
