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

#信息提示
show_notice() {
    local message="$1"

    local green_bg="\e[48;5;34m"
    local white_fg="\e[97m"
    local reset="\e[0m"

    echo -e "${green_bg}${white_fg}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "${white_fg}┃${reset}                                                                                             "
    echo -e "${white_fg}┃${reset}                                   ${message}                                                "
    echo -e "${white_fg}┃${reset}                                                                                             "
    echo -e "${green_bg}${white_fg}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
}

# 安装依赖
install_base(){
  # 安装qrencode jq
  local packages=("qrencode" "jq" "iptables")
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
      echo "$package 已安装。"
    fi
  done
}

# 下载sb
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

# client configuration
show_client_configuration() {

  # 获取当前ip
  server_ip=$(grep -o "SERVER_IP='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # reality
  # reality当前端口
  reality_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 当前偷取的网站
  reality_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 当前reality uuid
  reality_uuid=$(grep -o "REALITY_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 获取公钥
  public_key=$(grep -o "PUBLIC_KEY='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 获取short_id
  short_id=$(grep -o "SHORT_ID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  #聚合reality
  reality_link="vless://$reality_uuid@$server_ip:$reality_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-REALITY"
  echo ""
  echo ""
  show_notice "$(red "Reality 通用链接和二维码和通用参数")" 
  echo ""
  echo ""
  red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━Reality 通用链接如下━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "$reality_link"
  echo ""
  red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "" 
  red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━Reality 二维码如下━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  qrencode -t UTF8 $reality_link
  echo ""
  red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  echo ""
  echo ""
  echo ""

  # hy port
  hy_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy sni
  hy_server_name=$(grep -o "HY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy password
  hy_password=$(grep -o "HY_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # Generate the hy link
  hy2_link="hysteria2://$hy_password@$server_ip:$hy_port?insecure=0&alpn=h3&obfs=none&obfs-password=$hy_password&sni=$(cat /root/domain.txt)#hy2"

  echo ""
  echo "" 
  show_notice "$(green "Hysteria2 通用链接和二维码和通用参数")"
  echo ""
  echo "" 
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━hysteria2 通用链接格式━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "$hy2_link"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "" 
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━hysteria2 二维码━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  qrencode -t UTF8 $hy2_link  
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""  


  # tuic port
  tuic_port=$(grep -o "TUIC_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # tuic sni
  hy_server_name=$(grep -o "HY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # tuic UUID
  tuic_UUID=$(grep -o "TUIC_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # Generate the tuic link
  tuic_link="tuic://${tuic_UUID}:${tuic_UUID}@${server_ip}:${tuic_port}?congestion_control=bbr&alpn=h3&udp_relay_mode=quic&allow_insecure=0&sni=$(cat /root/domain.txt)#tuic"

  echo ""
  echo "" 
  show_notice "$(green "TUIC 通用链接和二维码和通用参数")"
  echo ""
  echo "" 
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━tuic 通用链接格式━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "$tuic_link"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "" 
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━tuic 二维码━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  qrencode -t UTF8 $tuic_link
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  vmess_uuid=$(grep -o "VMESS_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  ws_path=$(grep -o "WS_PATH='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  vmesswss_link='vmess://'$(echo '{"add":"'$(cat /root/domain.txt)'","aid":"0","host":"'$(cat /root/domain.txt)'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}'","port":"'$vmess_port'","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
  
  echo ""
  echo ""
  show_notice "$(yellow "vmess ws(s) 通用链接和二维码")"
  echo ""
  echo ""
  yellow "━━━━━━━━━━━━━━━━━━━━以下为vmess wss链接，替换speed.cloudflare.com为自己的优选ip可获得极致体验━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "$vmesswss_link"
  echo ""
  yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━vmess wss 二维码━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  qrencode -t UTF8 $vmesswss_link
  echo ""
  yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo ""

}

#enable bbr
enable_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}

# 创建快捷方式
create_shortcut() {
  cat > /root/sbox/sing.sh << EOF
#!/usr/bin/env bash
bash <(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/sing.sh) \$1
EOF
  chmod +x /root/sbox/sing.sh
  ln -sf /root/sbox/sing.sh /usr/bin/sing

}

# 开启hysteria2端口跳跃

interface=$(ip route get 8.8.8.8 | awk '{print $5}')

# 检查是否获取到了网卡名称
if [ -z "$interface" ]; then
  echo "无法获取网卡信息"
  exit 1
fi

enable_hy2hopping(){
  echo "开启端口跳跃"
    hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    read -p "输入UDP端口范围的起始值(默认20000): " -r start_port
    start_port=${start_port:-20000}
    read -p "输入UDP端口范围的结束值(默认30000): " -r end_port
    end_port=${end_port:-30000}
    iptables -t nat -A PREROUTING -i "$interface" -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port
    ip6tables -t nat -A PREROUTING -i "$interface" -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port

    sed -i "s/HY_HOPPING=FALSE/HY_HOPPING='TRUE'/" /root/sbox/config


}

disable_hy2hopping(){
    echo "关闭端口跳跃"
  hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')

  iptables -t nat -F PREROUTING >/dev/null 2>&1
  ip6tables -t nat -F PREROUTING >/dev/null 2>&1
  sed -i "s/HY_HOPPING='TRUE'/HY_HOPPING=FALSE/" /root/sbox/config


}


uninstall_singbox() {
    # Stop and disable services
    systemctl stop sing-box
    systemctl disable sing-box > /dev/null 2>&1

    # Remove service files
    rm -f /etc/systemd/system/sing-box.service

    # Remove configuration and executable files
    rm -f /root/sbox/sbconfig_server.json
    rm -f /root/sbox/sing-box
    rm -f /root/sbox/config
    rm -f /usr/bin/sing
    rm -f /root/sbox/sing.sh

    # Remove directories
    rm -rf /root/sbox/

    echo "卸载完成"
}

install_base

# Check if reality.json, sing-box, and sing-box.service already exist
if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/root/sbox/sing-box" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then

    echo "sing-box-reality-hysteria2已经安装"
    echo ""
    echo "请选择选项:"
    echo ""
    echo "1. 重新安装"
    echo "3. 显示客户端配置"
    echo "4. 卸载"
    echo "5. 更新sing-box内核"
    echo "6. Hy2端口跳跃"
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
                while true; do
            ishopping=$(grep '^HY_HOPPING=' /root/sbox/config | cut -d'=' -f2)

            if [ "$ishopping" = "FALSE" ]; then
                # 开启端口跳跃
                echo "开始设置端口跳跃范围"
                enable_hy2hopping
                
            else
                yellow "端口跳跃已开启"
                echo ""
                green "请选择选项："
                echo ""
                green "1. 关闭端口跳跃"
                green "2. 重新设置"
                green "3. 查看规则"
                green "0. 退出"
                echo ""
                read -p "请输入对应数字（0-3）: " hopping_input
                echo ""
                case $hopping_input in
                    1)
                    disable_hy2hopping
                    echo "端口跳跃规则已删除"
                    ;;
                    2)
                    disable_hy2hopping
                    echo "端口跳跃规则已删除"
                    echo "开始重新设置端口跳跃"
                    enable_hy2hopping
                    ;;
                    3)
                    # 查看IPv4的NAT规则
                    iptables -t nat -L -n -v | grep "udp"
                    # 查看IPv6的NAT规则
                    ip6tables -t nat -L -n -v | grep "udp"
                    ;;
                    0)
                    echo "退出"
                    break
                    ;;
                    *)
                    echo "无效的选项"
                    ;;
                esac
            fi
            done
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
    read -p "请输入Reality端口号 (default: 4430): " reality_port
    reality_port=${reality_port:-4430}

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
    read -p "请输入hysteria2监听端口 (default: 8433): " hy_port
    hy_port=${hy_port:-8433}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$hy_port\b"; then
        echo "端口 $hy_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

# tuic
green "开始配置tuic"
echo ""
# Generate hysteria necessary values
tuic_uuid=$(/root/sbox/sing-box generate uuid)
echo "自动生成了UUID"
echo ""
# Ask for listen port
while true; do
    read -p "请输入TUIC监听端口 (default: 28443): " tuic_port
    tuic_port=${tuic_port:-28443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$tuic_port\b"; then
        echo "端口 $tuic_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

# vmess ws
yellow "开始配置vmess"
echo ""
# Generate hysteria necessary values
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "请输入vmess端口，默认为443: " vmess_port
    vmess_port=${vmess_port:-443}

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


#ip地址
server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

#config配置文件
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
# Tuic
TUIC_PORT='$tuic_port'
TUIC_UUID='$tuic_uuid'
TUIC_PASSWORD='$tuic_uuid'
# Vmess
VMESS_PORT=$vmess_port
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'

EOF

# sbox配置文件
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
            "certificate_path": "/root/cert.crt",
            "key_path": "/root/private.key"
        }
    },
    {
      "type": "tuic",
      "tag": "tuic-in", 
      "listen": "::", 
      "listen_port": $tuic_port,
      "sniff": true,  
      "sniff_override_destination": false,  
      "users": [
        {
          "uuid": "$tuic_uuid", 
          "password": "$tuic_uuid" 
        }
      ],
      "congestion_control": "bbr", 
      "tls": {
        "enabled": true,
        "alpn": [ "h3" ], 
        "certificate_path": "/root/cert.crt",
        "key_path": "/root/private.key" 
      }
    },
    {
        "type": "vmess",
        "sniff": true,
        "sniff_override_destination": false,
        "tag": "vmess-sb",
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
            "path": "$ws_path"
        },
        "tls":{
                "enabled": true,
                "server_name": "$(cat /root/domain.txt)",
                "min_version": "1.2",
                "max_version": "1.3",
                "certificate_path": "/root/cert.crt",
                "key_path": "/root/private.key"
            }
    }
  ],
"outbounds": [
	{
      "type": "direct",
      "tag": "direct"
    	},
      {
        "type": "direct",
        "tag": "warp-IPv4-out",
        "detour": "wireguard-out",
        "domain_strategy": "ipv4_only"
      },
      {
        "type": "direct",
        "tag": "warp-IPv6-out",
        "detour": "wireguard-out",
        "domain_strategy": "ipv6_only"
      },
      {
        "type": "direct",
        "tag": "warp-IPv6-prefer-out",
        "detour": "wireguard-out",
        "domain_strategy": "prefer_ipv6"
      },
      {
        "type": "direct",
        "tag": "warp-IPv4-prefer-out",
        "detour": "wireguard-out",
        "domain_strategy": "prefer_ipv4"
      },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:812a:4929:7d2a:af62:351c/128"
      ],
      "private_key": "gBthRjevHDGyV0KvYwYE52NIPy29sSrVr6rcQtYNcXA=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved":[6,146,6]
    }
  ],
  "route": {
      "final": "direct",
      "rules": [
        {
          "rule_set": ["geosite-openai","geosite-netflix"],
          "outbound": "warp-IPv6-out"
        },
        {
          "rule_set": "geosite-tiktok",
          "outbound": "warp-IPv6-out" 
        },
        {
          "domain_keyword": [
            "ipaddress"
          ],
          "outbound": "warp-IPv6-out" 
        }
      ],
      "rule_set": [
        { 
          "tag": "geosite-openai",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/openai.srs",
          "download_detour": "direct"
        },
        {
          "tag": "geosite-netflix",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/netflix.srs",
          "download_detour": "direct"
        },
        {
          "tag": "geosite-tiktok",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/tiktok.srs",
          "download_detour": "direct"
        }
      ]
    } 
}
EOF

# Create sing-box.service
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


# Check configuration and start the service
if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
    echo "Configuration checked successfully. Starting sing-box service..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box
    create_shortcut
    show_client_configuration
    sing


else
    echo "Error in configuration. Aborting"
fi
