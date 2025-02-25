#!/bin/bash

set -e  # Exit immediately on error

# --- Functions ---

print_with_delay() {
    local text="$1"
    local delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    printf "\n"
}

red() { printf "\033[31m\033[01m%s\033[0m\n" "$*"; }
green() { printf "\033[32m\033[01m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m\033[01m%s\033[0m\n" "$*"; }

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

# Get config value
get_config_value() {
  local key="$1"
  grep -o "$key='[^']*'" /root/sbox/config | awk -F"'" '{print $2}'
}

install_base() {
  local packages=("qrencode" "jq" "iptables")
  local apt_installed=""
  local yum_installed=""
  local dnf_installed=""

  # Check for package managers only once
  if command -v apt &> /dev/null; then
    apt_installed="yes"
  fi
  if command -v yum &> /dev/null; then
    yum_installed="yes"
  fi
  if command -v dnf &> /dev/null; then
    dnf_installed="yes"
  fi

  for package in "${packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then
      echo "正在安装 $package..."
      if [ -n "$apt_installed" ]; then
        sudo apt update && sudo apt install -y "$package" > /dev/null 2>&1
      elif [ -n "$yum_installed" ]; then
        sudo yum install -y "$package" > /dev/null 2>&1
      elif [ -n "$dnf_installed" ]; then
        sudo dnf install -y "$package" > /dev/null 2>&1
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


download_singbox() {
  local arch=$(uname -m)
  echo "Architecture: $arch"

  case ${arch} in
      x86_64)  arch="amd64" ;;
      aarch64) arch="arm64" ;;
      armv7l)  arch="armv7" ;;
      *) echo "Unsupported architecture: $arch"; exit 1 ;;
  esac

  # Fetch the latest non-prerelease version using jq
  local latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '.[0] | .tag_name')

  if [[ -z "$latest_version_tag" ]]; then
    echo "Error: Could not fetch the latest version tag."
    exit 1
  fi

  local latest_version=${latest_version_tag#v}
  echo "Latest version: $latest_version"

  local package_name="sing-box-${latest_version}-linux-${arch}"
  local url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"

  # Download with error handling
  curl -sLo "/tmp/${package_name}.tar.gz" "$url" || { echo "Error downloading sing-box."; exit 1; }

  # Extract and move
  tar -xzf "/tmp/${package_name}.tar.gz" -C /tmp || { echo "Error extracting sing-box."; exit 1; }
  sudo mv "/tmp/${package_name}/sing-box" /usr/local/bin/sbox

  # Cleanup
  rm -rf "/tmp/${package_name}.tar.gz" "/tmp/${package_name}"

  # Set permissions
  sudo chmod 755 /usr/local/bin/sbox
}

show_client_configuration() {
  local server_ip=$(get_config_value "SERVER_IP")
  local hy_port=$(get_config_value "HY_PORT")
  local hy_password=$(get_config_value "HY_PASSWORD")
  local tls_port=$(get_config_value "TLS_PORT")
  local tls_password=$(get_config_value "TLS_PASSWORD")
  local vmess_uuid=$(get_config_value "VMESS_UUID")
  local ws_path=$(get_config_value "WS_PATH")
  local domain=$(cat /root/domain.txt)

  # Hysteria2
  local hy2_link="hysteria2://$hy_password@$domain:$hy_port?insecure=0&alpn=h3&obfs=none&sni=$domain#hy2$domain"
  show_notice "$(green "Hysteria2 通用链接和二维码")"
  green "Hysteria2 Link:"
  echo "$hy2_link"
  green "Hysteria2 QR Code:"
  qrencode -t UTF8 "$hy2_link"
  echo ""

  # ShadowTLS
  local tls_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$tls_password@$domain:$tls_port" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"www.samsung.com\",\"password\":\"$tls_password\"}" | base64 -w0)#ShadowTLS$domain"
  show_notice "$(green "Shadowtls 通用链接和二维码")"
  green "ShadowTLS Link:"
  echo "$tls_link"
  green "ShadowTLS QR Code:"
  qrencode -t UTF8 "$tls_link"
  echo ""

  # Vmess WS
  local vmesswss_link="vmess://$(echo "{\"add\":\"$domain\",\"aid\":\"0\",\"host\":\"$domain\",\"id\":\"$vmess_uuid\",\"net\":\"ws\",\"path\":\"$ws_path\",\"port\":\"$vmess_port\",\"ps\":\"Vmess-tls$domain\",\"tls\":\"tls\",\"type\":\"none\",\"v\":\"2\"}" | base64 -w 0)"
  show_notice "$(yellow "vmess ws(s) 通用链接和二维码")"
  yellow "Vmess wss Link (replace speed.cloudflare.com with your optimized IP):"
  echo "$vmesswss_link"
  yellow "Vmess wss QR Code:"
  qrencode -t UTF8 "$vmesswss_link"
  echo ""
}


enable_bbr() {
  if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo "BBR 已经开启."
        return
    fi
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}

create_shortcut() {
  cat > /tmp/sing.sh << EOF
#!/usr/bin/env bash
bash <(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/sing.sh) \$1
EOF
  sudo install -m 755 /tmp/sing.sh /usr/local/bin/sing
  rm /tmp/sing.sh
}


enable_hy2hopping() {
    local hy_current_port=$(get_config_value "HY_PORT")

    while true; do
        read -rp "输入UDP端口范围的起始值(默认20000): " start_port
        start_port=${start_port:-20000}
        if [[ "$start_port" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "错误：起始端口必须是数字。"
        fi
    done

    while true; do
        read -rp "输入UDP端口范围的结束值(默认30000): " end_port
        end_port=${end_port:-30000}
        if [[ "$end_port" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "错误：结束端口必须是数字。"
        fi
    done
  if [[ "$start_port" -ge "$end_port" ]]; then
    echo "错误：起始端口必须小于结束端口。"
    return 1
  fi
    local interface=$(ip route get 8.8.8.8 | awk '{print $5}')

    # 检查是否获取到了网卡名称
    if [ -z "$interface" ]; then
        echo "无法获取网卡信息"
        exit 1
    fi
    sudo iptables -t nat -A PREROUTING -i "$interface" -p udp --dport "$start_port:$end_port" -j DNAT --to-destination ":$hy_current_port"
    sudo ip6tables -t nat -A PREROUTING -i "$interface" -p udp --dport "$start_port:$end_port" -j DNAT --to-destination ":$hy_current_port"

    sed -i "s/HY_HOPPING=FALSE/HY_HOPPING='TRUE'/" /root/sbox/config
    echo "端口跳跃已开启"
}

disable_hy2hopping() {
    sudo iptables -t nat -F PREROUTING >/dev/null 2>&1
    sudo ip6tables -t nat -F PREROUTING >/dev/null 2>&1
    sed -i "s/HY_HOPPING='TRUE'/HY_HOPPING=FALSE/" /root/sbox/config
    echo "端口跳跃已关闭"
}

uninstall_singbox() {
    systemctl stop sing-box
    systemctl disable sing-box > /dev/null 2>&1
    rm -f /etc/systemd/system/sing-box.service
    rm -rf /root/sbox/
    rm -f /usr/local/bin/sbox
    rm -f /usr/local/bin/sing

    echo "卸载完成"
}


# --- Main Script ---
install_base
mkdir -p "/root/sbox/"

if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/usr/local/bin/sbox" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then

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
    while true; do
        read -rp "Enter your choice (1-8): " choice
        case $choice in
          1)
              show_notice "开始卸载..."
              uninstall_singbox
              break
            ;;
          3)
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

              if /usr/local/bin/sbox check -c /root/sbox/sbconfig_server.json; then
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
                        break

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
                        read -rp "请输入对应数字（0-3）: " hopping_input
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
                            break 2
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
              exit 0
              ;;
          *)
              echo "Invalid choice. Exiting."
              exit 1
              ;;
        esac
    done
fi



download_singbox

# vmess ws
yellow "开始配置vmess"
echo ""
# Generate hysteria necessary values
local vmess_uuid=$(/usr/local/bin/sbox generate uuid)
while true; do
    read -rp "请输入vmess端口，默认为2053: " vmess_port
    vmess_port=${vmess_port:-2053}

    # 检测端口是否被占用
    if ! [[ "$vmess_port" =~ ^[0-9]+$ ]]; then
        echo "错误：端口必须是数字。"
    elif ss -tuln | grep -q ":$vmess_port\b"; then
        echo "端口 $vmess_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -rp "ws路径 (无需加斜杠,默认随机生成): " ws_path
local ws_path=$vmess_uuid

# hysteria2
green "开始配置hysteria2"
echo ""
# Generate hysteria necessary values
local hy_password=$vmess_uuid
echo "自动生成了8位随机密码"
echo ""
# Ask for listen port
while true; do
    read -rp "请输入hysteria2监听端口 (default: 8433): " hy_port
    hy_port=${hy_port:-8433}

      if ! [[ "$hy_port" =~ ^[0-9]+$ ]]; then
        echo "错误：端口必须是数字。"
    elif ss -tuln | grep -q ":$hy_port\b"; then
        echo "端口 $hy_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
echo ""
# Generate tls necessary values
local tls_password=$(/usr/local/bin/sbox generate rand --base64 16)
echo "自动生成了16位随机密码"
echo ""
# Ask for listen port
while true; do
    read -rp "请输入tls监听端口 (default: 9433): " tls_port
    tls_port=${tls_port:-9433}
    if ! [[ "$tls_port" =~ ^[0-9]+$ ]]; then
        echo "错误：端口必须是数字。"
    elif ss -tuln | grep -q ":$tls_port\b"; then
        echo "端口 $tls_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

#域名
read -rp "请输入您的域名: " domain
echo "$domain" > /root/domain.txt

#ip地址
local server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

#config配置文件
cat > /root/sbox/config <<EOF
# VPS ip
SERVER_IP='$server_ip'
# Singbox
# Hy2
HY_PORT='$hy_port'
HY_SERVER_NAME='$domain'
HY_PASSWORD='$hy_password'
# Vmess
VMESS_PORT='$vmess_port'
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'
# Tls
TLS_PORT='$tls_port'
TLS_PASSWORD='$tls_password'
#hy2 port hopping
HY_HOPPING=FALSE
EOF

# sbox配置文件
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
                "server_name": "$domain",
                "min_version": "1.2",
                "max_version": "1.3",
                "certificate_path": "/root/cert.crt",
                "key_path": "/root/private.key"
            }
    }
  ],
 "endpoints":[
{
"type":"wireguard",
"tag":"warp-out",
"address":[
"172.16.0.2/32",
"2606:4700:110:8f9a:dc05:2307:8bbc:5196/128"
],
"private_key":"8G4m+UBlxt2/kR0MOTQuKA6N0PTNsxdhnj0K84HDTH0=",
"peers": [
{
"address": "162.159.192.1",
"port":2408,
"public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"allowed_ips": [
"0.0.0.0/0",
"::/0"
],
"reserved":[213,132,110]
}
]
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
    }
  ],
  "route": {
      "rules": [
        {
          "rule_set": ["geosite-openai","geosite-netflix"],
          "outbound": "warp-out"
        },
	      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "outbound": "block"
      },
        {
          "rule_set": "geosite-bing",
          "outbound": "warp-out"
        },
        {
          "domain_keyword": [
            "ipaddress"
          ],
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
        },
        {
          "tag": "geosite-netflix",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/netflix.srs",
          "download_detour": "direct"
        },
        {
          "tag": "geosite-bing",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/bing.srs",
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
ExecStart=/usr/local/bin/sbox run -c /root/sbox/sbconfig_server.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Check configuration and start the service
if /usr/local/bin/sbox check -c /root/sbox/sbconfig_server.json; then
    echo "Configuration checked successfully. Starting sing-box service..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box  # Ensure it's restarted
    create_shortcut
    show_client_configuration
    sing
else
    echo "Error in configuration. Aborting"
fi
