#!/bin/bash

# 函数：按字符间隔延迟打印文本
print_with_delay() {
    local text="$1"
    local delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

# 函数：以红色打印文本
红色() {
    echo -e "\033[31m\033[01m$*\033[0m"
}

# 函数：以绿色打印文本
绿色() {
    echo -e "\033[32m\033[01m$*\033[0m"
}

# 函数：以黄色打印文本
黄色() {
    echo -e "\033[33m\033[01m$*\033[0m"
}

# 函数：显示格式化的提示消息
显示提示() {
    local message="$1"
    local 绿色背景="\e[48;5;34m"
    local 白色前景="\e[97m"
    local 重置="\e[0m"

    echo -e "${绿色背景}${白色前景}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${重置}"
    echo -e "${白色前景}┃${重置}                                                                                             "
    echo -e "${白色前景}┃${重置}                                   ${message}                                                "
    echo -e "${白色前景}┃${重置}                                                                                             "
    echo -e "${绿色背景}${白色前景}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${重置}"
}

# 安装所需依赖
安装基础依赖() {
    local packages=("qrencode")
    for package in "${packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            echo "正在安装 $package..."
            if [ -n "$(command -v apt)" ]; then
                sudo apt update > /dev/null 2>&1
                sudo apt install -y "$package" > /dev/null 2>&1
            elif [ -n "$(command -v yum)" ]; then
                sudo yum install -y "$package"
            elif [ -n "$(command -v dnf)" ]; then
                sudo dnf install -y "$package"
            else
                echo "无法安装 $package，请手动安装后再运行脚本。"
                exit 1
            fi
            echo "$package 安装完成。"
        else
            echo "$package 已经安装。"
        fi
    done
}

# 下载 Sing-Box 并进行设置
下载Sing-Box() {
    local arch=$(uname -m)
    echo "架构: $arch"

    # 映射架构名称
    case $arch in
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="armv7"
            ;;
    esac

    # 从 GitHub API 获取最新发布版本号
    local latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | sort -V | tail -n 1)
    local latest_version=${latest_version_tag#v}  # 移除版本号前缀 'v'
    echo "最新版本: $latest_version"

    # 准备软件包名称和下载 URL
    local package_name="sing-box-${latest_version}-linux-${arch}"
    local url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"

    # 从 GitHub 下载最新发布的软件包 (.tar.gz)
    curl -sLo "/root/${package_name}.tar.gz" "$url"

    # 解压软件包并将可执行文件移动到 /root
    tar -xzf "/root/${package_name}.tar.gz" -C /root
    mv "/root/${package_name}/sing-box" /root/sbox

    # 清理软件包
    rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

    # 设置权限
    chown root:root /root/sbox/sing-box
    chmod +x /root/sbox/sing-box
}

# 下载 Cloudflared 并进行设置
下载Cloudflared() {
    local arch=$(uname -m)

    # 映射架构名称
    case $arch in
        x86_64)
            cf_arch="amd64"
            ;;
        aarch64)
            cf_arch="arm64"
            ;;
        armv7l)
            cf_arch="arm"
            ;;
    esac

    # 下载 Linux 版本的 Cloudflared
    local cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}"
    curl -sLo "/root/sbox/cloudflared-linux" "$cf_url"
    chmod +x /root/sbox/cloudflared-linux
    echo ""
}

# 显示客户端配置详细信息
显示客户端配置() {
    # 获取服务器 IP
    local server_ip=$(grep -o "SERVER_IP='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')

    # 显示 Reality 配置
    local reality_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local reality_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local reality_uuid=$(grep -o "REALITY_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local public_key=$(grep -o "PUBLIC_KEY='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local short_id=$(grep -o "SHORT_ID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local reality_link="vless://$reality_uuid@$server_ip:$reality_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-REALITY"

    echo ""
    echo ""
    显示提示 "$(红色 "Reality 配置")"
    echo ""
    echo ""
    红色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$reality_link"
    echo ""
    红色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""

    # 显示 Hysteria2 配置
    local hy_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local hy_server_name=$(grep -o "HY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local hy_password=$(grep -o "HY_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local hy2_link="hysteria2://$hy_password@$server_ip:$hy_port?insecure=1&sni=$hy_server_name"

    echo ""
    echo ""
    显示提示 "$(绿色 "Hysteria2 配置")"
    echo ""
    echo ""
    绿色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$hy2_link"
    echo ""
    绿色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""

    # 显示 Vmess 配置
    local vmess_uuid=$(grep -o "VMESS_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local ws_path=$(grep -o "WS_PATH='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local vmesswss_link='vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$server_ip'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}?ed=2048'","port":"443","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
    local vmessws_link='vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$server_ip'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}?ed=2048'","port":"80","ps":"sing-box-vmess","tls":"","type":"none","v":"2"}' | base64 -w 0)

    echo ""
    echo ""
    显示提示 "$(黄色 "Vmess 配置")"
    echo ""
    echo ""
    黄色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$vmesswss_link"
    echo ""
    黄色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    黄色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$vmessws_link"
    echo ""
    黄色 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
}

# 启用 BBR 拥塞控制算法
启用BBR() {
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}

# 修改 Sing-Box 服务器配置
修改Sing-Box() {
    # 修改 Reality 配置
    显示提示 "修改 Reality 配置"
    echo ""
    local reality_current_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "输入新的端口号 (当前端口: $reality_current_port): " reality_port
        reality_port=${reality_port:-$reality_current_port}
        if [ "$reality_port" -eq "$reality_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$reality_port\b"; then
            echo "端口 $reality_port 已被占用，请选择其他端口。"
        else
            break
        fi
    done
    echo ""
    local reality_current_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    read -p "输入要伪装的域名 (当前域名: $reality_current_server_name): " reality_server_name
    reality_server_name=${reality_server_name:-$reality_current_server_name}
    echo ""

    # 修改 Hysteria2 配置
    显示提示 "修改 Hysteria2 配置"
    echo ""
    local hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "输入新的端口号 (当前端口: $hy_current_port): " hy_port
        hy_port=${hy_port:-$hy_current_port}
        if [ "$hy_port" -eq "$hy_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$hy_port\b"; then
            echo "端口 $hy_port 已被占用，请选择其他端口。"
        else
            break
        fi
    done
    echo ""

    # 更新 Sing-Box 配置
    sed -i "s/REALITY_PORT='[^']*'/REALITY_PORT='$reality_port'/" /root/sbox/config
    sed -i "s/REALITY_SERVER_NAME='[^']*'/REALITY_SERVER_NAME='$reality_server_name'/" /root/sbox/config
    sed -i "s/HY_PORT='[^']*'/HY_PORT='$hy_port'/" /root/sbox/config

    # 重启 Sing-Box 服务
    systemctl restart sing-box
}

# 卸载 Sing-Box 服务器
卸载Sing-Box() {
    # 停止并禁用服务
    systemctl stop sing-box argo
    systemctl disable sing-box argo > /dev/null 2>&1

    # 删除服务文件
    rm -f /etc/systemd/system/sing-box.service
    rm -f /etc/systemd/system/argo.service

    # 删除配置文件和可执行文件
    rm -f /root/sbox/sbconfig_server.json
    rm -f /root/sbox/sing-box
    rm -f /root/sbox/cloudflared-linux
    rm -f /root/sbox/self-cert/private.key
    rm -f /root/sbox/self-cert/cert.pem
    rm -f /root/sbox/config

    # 删除目录
    rm -rf /root/sbox/self-cert/
    rm -rf /root/sbox/

    echo "卸载完成。"
}

# 安装基础依赖
安装基础依赖

# 检查是否已安装 Sing-Box
if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/root/sbox/cloudflared-linux" ] && [ -f "/root/sbox/sing-box" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then
    echo "Sing-Box 已经安装。"
    echo ""
    echo "请选择一个选项："
    echo ""
    echo "1. 重新安装 Sing-Box"
    echo "2. 修改配置"
    echo "3. 显示客户端配置"
    echo "4. 卸载 Sing-Box"
    echo "5. 更新 Sing-Box 内核"
    echo "6. 手动重启 Cloudflared"
    echo "7. 启用 BBR 拥塞控制"
    echo "8. 重启 Sing-Box"
    echo ""
    read -p "输入您的选择 (1-8): " choice

    case $choice in
        1)
            显示提示 "开始重新安装..."
            # 卸载之前的安装
            卸载Sing-Box
            ;;
        2)
            # 修改 Sing-Box 配置
            修改Sing-Box
            # 显示客户端配置
            显示客户端配置
            exit 0
            ;;
        3)
            # 显示客户端配置
            显示客户端配置
            exit 0
            ;;
        4)
            # 卸载 Sing-Box
            卸载Sing-Box
            exit 0
            ;;
        5)
            显示提示 "正在更新 Sing-Box..."
            下载Sing-Box
            # 检查配置并启动服务
            if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
                echo "配置检查成功。正在启动 Sing-Box 服务..."
                systemctl restart sing-box
            fi
            echo ""
            exit 0
            ;;
        6)
            systemctl stop argo
            systemctl start argo
            echo "重启完成。查看新的客户端信息。"
            显示客户端配置
            exit 0
            ;;
        7)
            启用BBR
            exit 0
            ;;
        8)
            systemctl restart sing-box
            echo "重启完成。"
            ;;
        *)
            echo "无效的选择。退出。"
            exit 1
            ;;
    esac
fi

# 创建必要的目录
mkdir -p "/root/sbox/"

# 下载 Sing-Box 并进行设置
下载Sing-Box

# 下载 Cloudflared 并进行设置
下载Cloudflared

# 配置 Reality
红色 "配置 Reality"
echo ""
key_pair=$(/root/sbox/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
reality_uuid=$(/root/sbox/sing-box generate uuid)
short_id=$(/root/sbox/sing-box generate rand --hex 8)
echo "生成 UUID 和 Short ID。"
echo ""
while true; do
    read -p "输入 Reality 端口号 (默认: 443): " reality_port
    reality_port=${reality_port:-443}
    if ss -tuln | grep -q ":$reality_port\b"; then
        echo "端口 $reality_port 已被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -p "输入要伪装的域名 (默认: itunes.apple.com): " reality_server_name
reality_server_name=${reality_server_name:-itunes.apple.com}
echo ""

# 配置 Hysteria2
绿色 "配置 Hysteria2"
echo ""
hy_password=$(/root/sbox/sing-box generate rand --hex 8)
echo "生成一个 8 位随机密码。"
echo ""
while true; do
    read -p "输入 Hysteria2 监听端口 (默认: 8443): " hy_port
    hy_port=${hy_port:-8443}
    if ss -tuln | grep -q ":$hy_port\b"; then
        echo "端口 $hy_port 已被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -p "输入自签名证书的域名 (默认: bing.com): " hy_server_name
hy_server_name=${hy_server_name:-bing.com}
mkdir -p /root/sbox/self-cert/ && openssl ecparam -genkey -name prime256v1 -out /root/sbox/self-cert/private.key && openssl req -new -x509 -days 36500 -key /root/sbox/self-cert/private.key -out /root/sbox/self-cert/cert.pem -subj "/CN=${hy_server_name}"
echo ""
echo "生成自签名证书。"
echo ""

# 配置 Vmess
黄色 "配置 Vmess"
echo ""
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "输入 Vmess 端口号 (默认: 18443): " vmess_port
    vmess_port=${vmess_port:-18443}
    if ss -tuln | grep -q ":$vmess_port\b"; then
        echo "端口 $vmess_port 已被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -p "输入 WS 路径 (不包含斜杠，随机生成默认值): " ws_path
ws_path=${ws_path:-$(/root/sbox/sing-box generate rand --hex 6)}

# 获取服务器 IP
server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

# 创建配置文件
cat > /root/sbox/config <<EOF
# 服务器 IP
SERVER_IP='$server_ip'

# Sing-Box
# Reality
PRIVATE_KEY='$private_key'
PUBLIC_KEY='$public_key'
SHORT_ID='$short_id'
REALITY_UUID='$reality_uuid'
REALITY_PORT='$reality_port'
REALITY_SERVER_NAME='$reality_server_name'

# Hysteria2
HY_PORT='$hy_port'
HY_SERVER_NAME='$hy_server_name'
HY_PASSWORD='$hy_password'

# Vmess
VMESS_PORT=$vmess_port
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'

# Argo
ARGO_DOMAIN=''

EOF

# 创建 Sing-Box 服务文件
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sbox/sing-box run -c /root/sbox/sbconfig_server.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# 检查配置并启动服务
if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
    echo "配置检查成功。正在启动 Sing-Box 服务..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box

    显示客户端配置
else
    echo "配置错误。中止。"
fi
