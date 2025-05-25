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
  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  #beta版本
  #latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" \
  #| awk '/"tag_name":/ {tag=$2} /"prerelease": false/ {print tag}' \
  #| tr -d '",' \
  #| sort -V \
  #| tail -n 1)
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

  # hy port
  hy_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy sni
  hy_server_name=$(grep -o "HY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy password
  hy_password=$(grep -o "HY_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # Generate the hy link
  hy2_link="hysteria2://$hy_password@$(cat /root/domain.txt):$hy_port?insecure=0&alpn=h3&obfs=none&sni=$(cat /root/domain.txt)#hy2$(cat /root/domain.txt)"

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

  # tls port
  tls_port=$(grep -o "TLS_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # tls password
  tls_password=$(grep -o "TLS_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # Generate the hy link
  tls_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$tls_password@$(cat /root/domain.txt):$tls_port" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"www.samsung.com\",\"password\":\"$tls_password\"}" | base64 -w0)#ShadowTLS$(cat /root/domain.txt)"

  echo ""
  echo "" 
  show_notice "$(green "Shadowtls 通用链接和二维码和通用参数")"
  echo ""
  echo "" 
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━tls 通用链接格式━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "$tls_link"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "" 
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━tls 二维码━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  qrencode -t UTF8 $tls_link  
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "" 



  vmess_uuid=$(grep -o "VMESS_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  ws_path=$(grep -o "WS_PATH='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  vmesswss_link='vmess://'$(echo '{"add":"'$(cat /root/domain.txt)'","aid":"0","host":"'$(cat /root/domain.txt)'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}'","port":"'$vmess_port'","ps":"Vmess-tls'$(cat /root/domain.txt)'","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
  
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
bash <(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/test.sh) \$1
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

# vmess ws
yellow "开始配置vmess"
echo ""
# Generate hysteria necessary values
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "请输入vmess端口，默认为2053: " vmess_port
    vmess_port=${vmess_port:-2053}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$vmess_port\b"; then
        echo "端口 $vmess_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -p "ws路径 (无需加斜杠,默认随机生成): " ws_path
ws_path=$vmess_uuid

# hysteria2
green "开始配置hysteria2"
echo ""
# Generate hysteria necessary values
hy_password=$vmess_uuid
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
echo ""
# Generate tls necessary values
tls_password=$(/root/sbox/sing-box generate rand --base64 16)
echo "自动生成了16位随机密码"
echo ""
# Ask for listen port
while true; do
    read -p "请输入tls监听端口 (default: 9433): " tls_port
    tls_port=${tls_port:-9433}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$tls_port\b"; then
        echo "端口 $tls_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""


#ip地址
server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

#config配置文件
cat > /root/sbox/config <<EOF

# VPS ip
SERVER_IP='$server_ip'
# Singbox
# Hy2
HY_PORT='$hy_port'
HY_SERVER_NAME='$hy_server_name'
HY_PASSWORD='$hy_password'
# Vmess
VMESS_PORT='$vmess_port'
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'
# Tls
TLS_PORT='$tls_port'
TLS_PASSWORD='$tls_password'
# Hopping
HY_HOPPING=FALSE

EOF

# sbox配置文件 - 修复了弃用格式
cat > /root/sbox/sbconfig_server.json << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "strategy": "ipv4_only",
        "detour": "direct"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "server": "block"
      }
    ],
    "final": "cloudflare",
    "strategy": "",
    "disable_cache": false,
    "disable_expire": false
  },
  "inbounds": [
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
      "type": "shadowtls",
      "tag": "ShadowTLS",
      "listen": "::",
      "listen_port": $tls_port, 
      "version": 3,
      "users": [
        {
          "password": "$tls_password" 
        }
      ],
      "handshake": {
        "server": "www.samsung.com",
        "server_port": 443
      },
      "strict_mode": true, 
      "detour": "shadowsocks-shadowtls-in"
    },
    {
      "type": "shadowsocks",
      "tag": "shadowsocks-shadowtls-in", 
      "listen": "::",
      "listen_port": 6530, 
      "sniff": true,
      "sniff_override_destination": false,
      "method": "2022-blake3-aes-128-gcm",
      "password": "$tls_password", 
      "multiplex": {
        "enabled": true,
        "padding": true
        }
    },
    {
      "type": "anytls",
      "tag": "anytls-in",
      "listen": "::",
      "listen_port": 7443,
      "users": [
        {
          "password": "$tls_password"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$(cat /root/domain.txt)",
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
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "wireguard",
      "tag": "warp-out",
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:8f9a:dc05:2307:8bbc:5196/128"
      ],
      "private_key": "8G4m+UBlxt2/kR0MOTQuKA6N0PTNsxdhnj0K84HDTH0=",
      "server": "162.159.192.1",
      "server_port": 2408,
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [213,132,110]
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "action": "route",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "action": "route",
        "outbound": "direct"
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "action": "route",
        "outbound": "block"
      },
      {
        "rule_set": [
          "geosite-openai",
          "geosite-netflix"
        ],
        "action": "route",
        "outbound": "warp-out"
      },
      {
        "domain_keyword": [
          "ipaddress"
        ],
        "action": "route",
        "outbound": "warp-out" 
      }
    ],
    "rule_set": [
      { 
        "tag": "geosite-openai",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/openai.srs",
        "download_detour": "direct"
      },{
          "tag": "geosite-netflix",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/netflix.srs",
          "download_detour": "direct"
        },
	{
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
      ],
          "auto_detect_interface": true,
    "final": "direct"
    },
    "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "cache.db",
      "cache_id": "mycacheid",
      "store_fakeip": true
    }
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
