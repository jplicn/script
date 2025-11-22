#!/bin/bash

# 全局变量
WORKDIR="/root/sbox"
DOMAIN_FILE="/root/domain.txt"
CERT_FILE="/root/cert.crt"
KEY_FILE="/root/private.key"

# 字体颜色配置
red() { echo -e "\033[31m\033[01m$*\033[0m"; }
green() { echo -e "\033[32m\033[01m$*\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$*\033[0m"; }

# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   red "错误：本脚本必须以 root 身份运行！"
   exit 1
fi

# 信息提示框
show_notice() {
    local message="$1"
    local green_bg="\e[48;5;34m"
    local white_fg="\e[97m"
    local reset="\e[0m"
    echo -e "${green_bg}${white_fg}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "${white_fg}┃${reset}                                                                                                                    "
    echo -e "${white_fg}┃${reset}                    ${message}                                                        "
    echo -e "${white_fg}┃${reset}                                                                                                                    "
    echo -e "${green_bg}${white_fg}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
}

# 1. 系统依赖安装
install_base(){
  local packages=("qrencode" "jq" "iptables" "curl" "wget" "socat" "tar" "lsof")
  
  # 检测包管理器
  if [ -n "$(command -v apt)" ]; then
    CMD="apt"
    $CMD update > /dev/null 2>&1
  elif [ -n "$(command -v yum)" ]; then
    CMD="yum"
  elif [ -n "$(command -v dnf)" ]; then
    CMD="dnf"
  else
    red "未检测到支持的包管理器 (apt/yum/dnf)，脚本无法继续。"
    exit 1
  fi

  echo "正在检查并安装系统依赖..."
  for package in "${packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then
        $CMD install -y "$package" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            red "警告：安装 $package 失败，请手动检查。"
        fi
    fi
  done
}

# 2. 证书申请模块 (独立功能)
apply_certificate() {
    install_base # 确保 socat/curl 已安装
    
    echo ""
    show_notice "$(green "独立模块: 域名与证书配置")"
    
    # 检查 80 端口
    if lsof -i:80 > /dev/null 2>&1; then
        yellow "检测到 80 端口被占用，尝试停止常见 Web 服务..."
        systemctl stop nginx > /dev/null 2>&1
        systemctl stop apache2 > /dev/null 2>&1
        systemctl stop httpd > /dev/null 2>&1
        systemctl stop caddy > /dev/null 2>&1
        
        sleep 2
        if lsof -i:80 > /dev/null 2>&1; then
            red "错误：80 端口依然被占用，无法进行证书验证。"
            red "请手动停止占用 80 端口的程序 (如 Nginx/Caddy) 后重试。"
            return
        fi
    fi

    # 安装 acme.sh
    if ! [ -f "/root/.acme.sh/acme.sh" ]; then
        echo "正在安装 acme.sh..."
        curl https://get.acme.sh | sh
    fi

    # 输入域名
    echo ""
    while true; do
        read -p "请输入您的域名 (请确保已解析到本机 IP): " domain
        if [ -z "$domain" ]; then
            red "域名不能为空！"
        else
            break
        fi
    done

    echo "$domain" > "$DOMAIN_FILE"
    
    # 生成随机邮箱
    random_email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"
    
    # 选择 CA
    echo ""
    echo "请选择证书机构:"
    echo "1. Let's Encrypt (推荐)"
    echo "2. Buypass"
    echo "3. ZeroSSL"
    read -p "请输入选项 (默认1): " ca_choice
    ca_choice=${ca_choice:-1}

    case $ca_choice in
        1) ca="letsencrypt" ;;
        2) ca="buypass" ;;
        3) ca="zerossl" ;;
        *) ca="letsencrypt" ;;
    esac

    # 注册并申请
    /root/.acme.sh/acme.sh --register-account -m "$random_email" --server "$ca"
    
    # 开放防火墙 80
    if command -v ufw &> /dev/null; then ufw allow 80 >/dev/null 2>&1; fi
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1

    if /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --server "$ca" --force; then
        green "证书申请成功！"
        /root/.acme.sh/acme.sh --installcert -d "$domain" --ecc \
            --key-file "$KEY_FILE" \
            --fullchain-file "$CERT_FILE"
        
        echo ""
        green "========================================="
        green " 证书已准备就绪！"
        green " 域名: $domain"
        green " 证书路径: $CERT_FILE"
        green " 私钥路径: $KEY_FILE"
        green "========================================="
        green "现在请在主菜单选择 [2] 安装 Sing-box。"
        read -p "按回车键返回主菜单..."
    else
        red "证书申请失败！请检查域名解析是否正确，以及防火墙是否开放 80 端口。"
        return
    fi
}

# 3. 下载 Sing-box
download_singbox(){
  show_notice "$(green "开始安装 Sing-box 核心")"
  
  mkdir -p "$WORKDIR"
  arch=$(uname -m)
  case ${arch} in
      x86_64) arch="amd64" ;;
      aarch64) arch="arm64" ;;
      armv7l) arch="armv7" ;;
      *) red "不支持的架构: $arch"; exit 1 ;;
  esac

  # 获取最新版本
  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  if [ -z "$latest_version_tag" ]; then
     red "无法获取 Sing-box 版本信息，请检查网络连接。"
     exit 1
  fi
  
  latest_version=${latest_version_tag#v}
  echo "检测到最新版本: $latest_version"
  
  package_name="sing-box-${latest_version}-linux-${arch}"
  url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"
  
  curl -sLo "/root/${package_name}.tar.gz" "$url"
  tar -xzf "/root/${package_name}.tar.gz" -C /root
  
  # 停止旧服务
  systemctl stop sing-box >/dev/null 2>&1

  mv "/root/${package_name}/sing-box" "$WORKDIR/sing-box"
  rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

  chown root:root "$WORKDIR/sing-box"
  chmod +x "$WORKDIR/sing-box"
  
  green "Sing-box 核心安装完成。"
}

# 4. 生成配置
configure_singbox() {
    # 前置检查：确保域名和证书存在
    if [ ! -f "$DOMAIN_FILE" ] || [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        red "错误：未检测到域名配置或证书文件！"
        yellow "请先在主菜单运行 [1] 申请/配置证书，然后再运行此选项。"
        read -p "按回车键返回主菜单..."
        return
    fi

    show_notice "$(green "生成配置文件")"
    
    local domain=$(cat "$DOMAIN_FILE")
    echo "检测到当前域名: $domain"
    
    # 获取 UUID 和 随机密码
    vmess_uuid=$("$WORKDIR/sing-box" generate uuid)
    tls_password=$("$WORKDIR/sing-box" generate rand --base64 16)
    hy_password=$vmess_uuid
    ws_path=$vmess_uuid
    hy_server_name=$domain

    # 端口设置
    while true; do
        read -p "请输入 Vmess 端口 (默认 2053): " vmess_port
        vmess_port=${vmess_port:-2053}
        if ss -tuln | grep -q ":$vmess_port\b"; then red "端口被占用"; else break; fi
    done

    while true; do
        read -p "请输入 Hysteria2 端口 (默认 8433): " hy_port
        hy_port=${hy_port:-8433}
        if ss -tuln | grep -q ":$hy_port\b"; then red "端口被占用"; else break; fi
    done

    while true; do
        read -p "请输入 ShadowTLS 端口 (默认 9433): " tls_port
        tls_port=${tls_port:-9433}
        if ss -tuln | grep -q ":$tls_port\b"; then red "端口被占用"; else break; fi
    done
    
    # 获取本机 IP
    server_ip=$(curl -s4m8 ip.sb -k || curl -s6m8 ip.sb -k)

    # 保存配置变量
    cat > "$WORKDIR/config" <<EOF
SERVER_IP='$server_ip'
HY_PORT='$hy_port'
HY_SERVER_NAME='$hy_server_name'
HY_PASSWORD='$hy_password'
VMESS_PORT='$vmess_port'
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'
TLS_PORT='$tls_port'
TLS_PASSWORD='$tls_password'
EOF

    # 生成 sbconfig_server.json
    cat > "$WORKDIR/sbconfig_server.json" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {"type": "local"}
    ],
    "strategy": "ipv4_only"
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
            "alpn": ["h3"],
            "certificate_path": "$CERT_FILE",
            "key_path": "$KEY_FILE"
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
        "tag": "ubuntu anytls",
        "listen": "::",
        "listen_port": 8883,
        "users": [
            { "password": "$tls_password" }
        ],
        "tls": {
            "enabled": true,
            "certificate_path": "$CERT_FILE",
            "key_path": "$KEY_FILE"
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
            "certificate_path": "$CERT_FILE",
            "key_path": "$KEY_FILE"
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
                "allowed_ips": ["0.0.0.0/0", "::/0"],
                "reserved":[213,132,110]
            }
        ]
    }
  ], 
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
      "rules": [
        {
          "rule_set": ["geosite-openai"],
          "outbound": "warp-out"
        },
        {
          "domain_keyword": ["ipaddress"],
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

    # 创建 systemd 服务
    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=$WORKDIR
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=$WORKDIR/sing-box run -c $WORKDIR/sbconfig_server.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    
    if "$WORKDIR/sing-box" check -c "$WORKDIR/sbconfig_server.json"; then
        systemctl restart sing-box
        green "Sing-box 服务启动成功！"
        create_shortcut
        show_client_configuration
    else
        red "配置文件生成有误，Sing-box 启动失败，请检查日志。"
        "$WORKDIR/sing-box" check -c "$WORKDIR/sbconfig_server.json"
    fi
}

# 5. 客户端配置展示
show_client_configuration() {
    if [ ! -f "$WORKDIR/config" ]; then red "未找到配置文件，请先安装 Sing-box"; return; fi
    
    source "$WORKDIR/config"
    local domain=$(cat "$DOMAIN_FILE")

    # Hysteria2 Link
    hy2_link="hysteria2://$HY_PASSWORD@$domain:$HY_PORT?insecure=0&alpn=h3&obfs=none&sni=$domain#hy2-$domain"

    # ShadowTLS Link
    tls_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$TLS_PASSWORD@$domain:$TLS_PORT" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"www.samsung.com\",\"password\":\"$TLS_PASSWORD\"}" | base64 -w0)#ShadowTLS-$domain"

    # Vmess Link
    vmess_json="{\"add\":\"$domain\",\"aid\":\"0\",\"host\":\"$domain\",\"id\":\"$VMESS_UUID\",\"net\":\"ws\",\"path\":\"$WS_PATH\",\"port\":\"$VMESS_PORT\",\"ps\":\"Vmess-tls-$domain\",\"tls\":\"tls\",\"type\":\"none\",\"v\":\"2\"}"
    vmesswss_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"

    echo ""
    show_notice "配置信息 (截图保存)"
    
    green "=== Hysteria 2 ==="
    echo "$hy2_link"
    qrencode -t ANSIUTF8 "$hy2_link"
    
    echo ""
    green "=== ShadowTLS (v3) ==="
    echo "$tls_link"
    qrencode -t ANSIUTF8 "$tls_link"
    
    echo ""
    green "=== Vmess WS TLS ==="
    echo "$vmesswss_link"
    qrencode -t ANSIUTF8 "$vmesswss_link"
    
    echo ""
    yellow "提示：以后可以输入 'sing' 命令再次调出此菜单。"
    read -p "按回车键返回..."
}

# 6. 端口跳跃设置
enable_hy2hopping(){
    interface=$(ip route get 8.8.8.8 | awk '{print $5}')
    if [ -z "$interface" ]; then red "无法获取网卡信息"; return; fi
    
    # 需要先加载配置获取端口
    if [ ! -f "$WORKDIR/config" ]; then red "请先安装 Sing-box"; return; fi
    source "$WORKDIR/config"
    
    read -p "输入UDP端口范围起始值 (默认 20000): " start_port
    start_port=${start_port:-20000}
    read -p "输入UDP端口范围结束值 (默认 30000): " end_port
    end_port=${end_port:-30000}
    
    iptables -t nat -A PREROUTING -i "$interface" -p udp --dport $start_port:$end_port -j DNAT --to-destination :$HY_PORT
    if command -v ip6tables &>/dev/null; then
         ip6tables -t nat -A PREROUTING -i "$interface" -p udp --dport $start_port:$end_port -j DNAT --to-destination :$HY_PORT
    fi
    
    touch "$WORKDIR/hopping_enabled"
    green "端口跳跃已开启 ($start_port-$end_port -> $HY_PORT)"
}

disable_hy2hopping(){
    iptables -t nat -F PREROUTING
    if command -v ip6tables &>/dev/null; then ip6tables -t nat -F PREROUTING; fi
    rm -f "$WORKDIR/hopping_enabled"
    green "端口跳跃已关闭。"
}

# 7. 辅助功能
create_shortcut() {
  cat > /usr/bin/sing << EOF
#!/bin/bash
bash $0 show_menu
EOF
  chmod +x /usr/bin/sing
}

enable_bbr() {
    echo "正在开启 BBR..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    green "BBR 已开启。"
}

uninstall_singbox() {
    read -p "确定要卸载 Sing-box 吗? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f /etc/systemd/system/sing-box.service
    rm -rf "$WORKDIR"
    rm -f /usr/bin/sing
    green "Sing-box 已卸载 (保留了证书文件)。"
    green "如需删除证书，请手动删除 /root/cert.crt 和 /root/private.key"
}

# 8. 菜单系统
show_menu() {
    clear
    show_notice "Sing-box 一键安装脚本 (分离版)"
    echo "1. 申请/管理 SSL 证书 (必须先执行)"
    echo "2. 安装 Sing-box 核心 (需先有证书)"
    echo "---------------------------------"
    echo "3. 查看客户端配置 (链接/二维码)"
    echo "4. 开启/管理 Hy2 端口跳跃"
    echo "5. 开启 BBR 加速"
    echo "6. 卸载 Sing-box"
    echo "7. 重启服务"
    echo "0. 退出"
    echo ""
    read -p "请选择: " choice
    
    case $choice in
        1) apply_certificate ;;
        2) 
           install_base
           download_singbox
           configure_singbox
           ;;
        3) show_client_configuration ;;
        4) 
            if [ -f "$WORKDIR/hopping_enabled" ]; then
                yellow "当前状态：已开启"
                read -p "是否关闭? (y/n): " close
                if [[ "$close" == "y" ]]; then disable_hy2hopping; fi
            else
                enable_hy2hopping
            fi
            ;;
        5) enable_bbr ;;
        6) uninstall_singbox ;;
        7) systemctl restart sing-box && green "重启成功" ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    
    # 操作完成后，如果不是退出，暂停一下让用户看结果
    if [[ "$choice" != "0" ]]; then
        echo ""
        read -p "按任意键返回菜单..."
        show_menu
    fi
}

# 脚本入口
if [[ "$1" == "show_menu" ]]; then
    show_menu
else
    # 首次运行直接进入菜单
    show_menu
fi
