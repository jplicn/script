#!/bin/bash

# 延迟打字
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# 自定义字体彩色，read 函数
red() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
green() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
yellow() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色

# 信息提示
show_notice() {
    local message="$1"

    local green_bg="\e[48;5;34m"
    local white_fg="\e[97m"
    local reset="\e[0m"

    echo -e "${green_bg}${white_fg}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "${white_fg}┃${reset}                                                                                             "
    echo -e "${white_fg}┃${reset}                                   ${message}                                                "
    echo -e "${white_fg}┃${reset}                                                                                             "
    echo -e "${green_bg}${white_fg}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
}

# 安装依赖
install_base(){
  # 安装qrencode
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
        echo "无法安装 $package。请手动安装，并重新运行脚本。"
        exit 1
      fi
      echo "$package 已安装。"
    else
      echo "$package 已经安装。"
    fi
  done
}

# 下载cloudflared和sb
download_singbox(){
  arch=$(uname -m)
  echo "Architecture: $arch"
  # Map architecture names
  case ${arch} in
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
  # Fetch the latest (including pre-releases) release version number from GitHub API
  # 正式版
  #latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  #beta版本
  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | sort -V | tail -n 1)
  latest_version=${latest_version_tag#v}  # Remove 'v' prefix from version number
  echo "Latest version: $latest_version"
  # Detect server architecture
  # Prepare package names
  package_name="sing-box-${latest_version}-linux-${arch}"
  # Prepare download URL
  url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"
  # Download the latest release package (.tar.gz) from GitHub
  curl -sLo "/root/${package_name}.tar.gz" "$url"

  # Extract the package and move the binary to /root
  tar -xzf "/root/${package_name}.tar.gz" -C /root
  mv "/root/${package_name}/sing-box" /root/sbox

  # Cleanup the package
  rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

  # Set the permissions
  chown root:root /root/sbox/sing-box
  chmod +x /root/sbox/sing-box
}

download_cloudflared(){
  arch=$(uname -m)
  # Map architecture names
  case ${arch} in
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

  # install cloudflared linux
  cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}"
  curl -sLo "/root/sbox/cloudflared-linux" "$cf_url"
  chmod +x /root/sbox/cloudflared-linux
  echo ""
}

# 一键开启BBR
enable_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}

# 修改singbox配置
modify_singbox() {
    # modifying reality configuration
    show_notice "开始修改Reality端口号和域名"
    reality_current_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "请输入想要修改的端口号 (当前端口号为 $reality_current_port): " reality_port
        reality_port=${reality_port:-$reality_current_port}
        if [ "$reality_port" -eq "$reality_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$reality_port\b"; then
            echo "端口 $reality_port 已经被占用，请选择其他端口。"
        else
            break
        fi
    done
    echo ""
    reality_current_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    read -p "请输入想要偷取的域名 (当前域名为 $reality_current_server_name): " reality_server_name
    reality_server_name=${reality_server_name:-$reality_current_server_name}
    echo ""
    # modifying hysteria2 configuration
    show_notice "开始修改hysteria2端口号"
    echo ""
    hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "请输入想要修改的端口号 (当前端口号为 $hy_current_port): " hy_port
        hy_port=${hy_port:-$hy_current_port}
        if [ "$hy_port" -eq "$hy_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$hy_port\b"; then
            echo "端口 $hy_port 已经被占用，请选择其他端口。"
        else
            break
        fi
    done

    # 修改sing-box
    sed -i -e "/\"listen_port\":/{N; s/\"[0-9]*\"/\"$hy_port\"/}" \
          -e "/\"listen_port\":/{N; s/\"[0-9]*\"/\"$reality_port\"/}" \
          -e "/\"tls\": {/,/\"server\":/{ /\"server_name\":/{N; s/\"server_name\": \".*\"/\"server_name\": \"$reality_server_name\"/ }}"

    # 修改config
    sed -i "s/REALITY_PORT='[^']*'/REALITY_PORT='$reality_port'/" /root/sbox/config
    sed -i "s/REALITY_SERVER_NAME='[^']*'/REALITY_SERVER_NAME='$reality_server_name'/" /root/sbox/config
    sed -i "s/HY_PORT='[^']*'/HY_PORT='$hy_port'/" /root/sbox/config

    # Restart sing-box service
    systemctl restart sing-box
}

# 卸载singbox
uninstall_singbox() {
    # Stop and disable services
    systemctl stop sing-box argo
    systemctl disable sing-box argo > /dev/null 2>&1

    # Remove service files
    rm -f /etc/systemd/system/sing-box.service
    rm -f /etc/systemd/system/argo.service

    # Remove configuration and executable files
    rm -f /root/sbox/sbconfig_server.json
    rm -f /root/sbox/sing-box
    rm -f /root/sbox/cloudflared-linux
    rm -f /root/sbox/self-cert/private.key
    rm -f /root/sbox/self-cert/cert.pem
    rm -f /root/sbox/config

    # Remove directories
    rm -rf /root/sbox/self-cert/
    rm -rf /root/sbox/

    echo "卸载完成"
}

# 安装依赖
install_base

# Check if reality.json, sing-box, and sing-box.service already exist
if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/root/sbox/cloudflared-linux" ] && [ -f "/root/sbox/sing-box" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then
    echo "sing-box-reality-hysteria2已经安装"
    echo ""
    echo "请选择选项:"
    echo ""
    echo "1. 重新安装"
    echo "2. 修改配置"
    echo "3. 显示客户端配置"
    echo "4. 卸载"
    echo "5. 更新sing-box内核"
    echo "6. 手动重启cloudflared"
    echo "7. 一键开启bbr"
    echo "8. 重启sing-box"
    echo ""
    read -p "Enter your choice (1-8): " choice

    case $choice in
      1)
          show_notice "开始卸载..."
          # Uninstall previous installation
          uninstall_singbox
        ;;
      2)
          # 修改sb
          modify_singbox
          # show client configuration
          show_client_configuration
          exit 0
        ;;
      3)  
          # show client configuration
          show_client_configuration
          exit 0
      ;;	
      4)
          uninstall_singbox
          exit 0
          ;;
      5)
          show_notice "更新 Sing-box..."
          download_singbox
          # Check configuration and start the service
          if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
              echo "Configuration checked successfully. Starting sing-box service..."
              systemctl restart sing-box
          fi
          echo ""  
          exit 0
          ;;
      6)
          systemctl stop argo
          systemctl start argo
          echo "重新启动完成，查看新的客户端信息"
          show_client_configuration
          exit 0
          ;;
      7)
          enable_bbr
          exit 0
          ;;
      8)
          systemctl restart sing-box
          echo "重启完成"
          ;;
      *)
          echo "Invalid choice. Exiting."
          exit 1
          ;;
    esac
fi

mkdir -p "/root/sbox/"
download_singbox
download_cloudflared

# reality
red "开始配置Reality"
echo ""
# Generate key pair
echo "自动生成基本参数"
echo ""
key_pair=$(/root/sbox/sing-box generate reality-keypair)
echo "Key pair生成完成"
echo ""

# Extract private key and public key
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

# Generate necessary values
reality_uuid=$(/root/sbox/sing-box generate uuid)
short_id=$(/root/sbox/sing-box generate rand --hex 8)
echo "uuid和短id 生成完成"
echo ""
# Ask for listen port
while true; do
    read -p "请输入Reality端口号 (default: 443): " reality_port
    reality_port=${reality_port:-443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$reality_port\b"; then
        echo "端口 $reality_port 已经被占用，请重新输入。"
    else
        break
    fi
done
echo ""
# Ask for server name (sni)
read -p "请输入想要偷取的域名,需要支持tls1.3 (default: itunes.apple.com): " reality_server_name
reality_server_name=${reality_server_name:-itunes.apple.com}
echo ""

# hysteria2
green "开始配置hysteria2"
echo ""
# Generate hysteria necessary values
hy_password=$(/root/sbox/sing-box generate rand --hex 8)
echo "自动生成了8位随机密码"
echo ""
# Ask for listen port
while true; do
    read -p "请输入hysteria2监听端口 (default: 8443): " hy_port
    hy_port=${hy_port:-8443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$hy_port\b"; then
        echo "端口 $hy_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

# Ask for self-signed certificate domain
read -p "输入自签证书域名 (default: bing.com): " hy_server_name
hy_server_name=${hy_server_name:-bing.com}
mkdir -p /root/sbox/self-cert/ && openssl ecparam -genkey -name prime256v1 -out /root/sbox/self-cert/private.key && openssl req -new -x509 -days 36500 -key /root/sbox/self-cert/private.key -out /root/sbox/self-cert/cert.pem -subj "/CN=${hy_server_name}"
echo ""
echo "自签证书生成完成"
echo ""

# vmess ws
yellow "开始配置vmess"
echo ""
# Generate hysteria necessary values
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "请输入vmess端口，默认为18443(和tunnel通信用不会暴露在外): " vmess_port
    vmess_port=${vmess_port:-18443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$vmess_port\b"; then
        echo "端口 $vmess_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -p "ws路径 (无需加斜杠,默认随机生成): " ws_path
ws_path=${ws_path:-$(/root/sbox/sing-box generate rand --hex 6)}

# IP地址
server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

# 配置文件
cat > /root/sbox/config <<EOF
# VPS ip
SERVER_IP='$server_ip'
# Singbox
# Reality
PRIVATE_KEY='$private_key'
PUBLIC_KEY='$public_key'
SHORT_ID='$short_id'
REALITY_UUID='$reality_uuid'
REALITY_PORT='$reality_port'
REALITY_SERVER_NAME='$reality_server_name'
# Hy2
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

# Argo服务
cat > /etc/systemd/system/argo.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/bin/bash -c "/root/sbox/cloudflared-linux tunnel --url http://localhost:$vmess_port --no-autoupdate --edge-ip-version auto --protocol http2>/root/sbox/argo.log 2>&1 "
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable argo > /dev/null 2>&1
systemctl start argo

# Sing-box配置文件
cat > /root/sbox/sbconfig_server.json << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $reality_port,
      "users": [
        {
          "uuid": "$reality_uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$reality_server_name",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$reality_server_name",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
    {
        "type": "hysteria2",
        "tag": "hy2-in",
        "listen": "::",
        "listen_port": $hy_port,
        "users": [
            {
                "password": "$hy_password"
            }
        ],
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "/root/sbox/self-cert/cert.pem",
            "key_path": "/root/sbox/self-cert/private.key"
        }
    },
    {
        "type": "vmess",
        "tag": "vmess-in",
        "listen": "::",
        "listen_port": $vmess_port,
        "users": [
            {
                "uuid": "$vmess_uuid",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "$ws_path",
            "max_early_data":2048,
            "early_data_header_name":"Sec-WebSocket-Protocol"
        }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF

# 创建sing-box.service
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
    echo "Configuration checked successfully. Starting sing-box service..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box

    show_client_configuration
else
    echo "Error in configuration. Aborting"
fi
