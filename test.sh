#!/bin/bash

# 全局变量
WORKDIR="/root/sbox"
DOMAIN_FILE="/root/domain.txt"
CERT_FILE="/root/cert.crt"
KEY_FILE="/root/private.key"

# 字体颜色配置 (函数版)
red() { echo -e "\033[31m\033[01m$*\033[0m"; }
green() { echo -e "\033[32m\033[01m$*\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$*\033[0m"; }

# 字体颜色配置 (变量版，用于面板拼接)
clr_red="\033[31m"
clr_green="\033[32m"
clr_yellow="\033[33m"
clr_reset="\033[0m"

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
  
  if [ -n "$(command -v apt)" ]; then
    CMD="apt"
    $CMD update > /dev/null 2>&1
  elif [ -n "$(command -v yum)" ]; then
    CMD="yum"
  elif [ -n "$(command -v dnf)" ]; then
    CMD="dnf"
  else
    red "未检测到支持的包管理器，脚本无法继续。"
    exit 1
  fi

  echo "正在检查系统依赖..."
  for package in "${packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then
        $CMD install -y "$package" > /dev/null 2>&1
    fi
  done
}

# 2. 证书申请模块
apply_certificate() {
    install_base
    echo ""
    show_notice "$(green "独立模块: 域名与证书配置")"
    
    # 80端口检查
    if lsof -i:80 > /dev/null 2>&1; then
        yellow "检测到 80 端口被占用，尝试停止 Web 服务..."
        systemctl stop nginx > /dev/null 2>&1
        systemctl stop apache2 > /dev/null 2>&1
        systemctl stop httpd > /dev/null 2>&1
        systemctl stop caddy > /dev/null 2>&1
        sleep 2
        if lsof -i:80 > /dev/null 2>&1; then
            red "错误：80 端口依然被占用，无法进行证书验证。"
            red "请手动停止占用 80 端口的程序后重试。"
            return
        fi
    fi

    if ! [ -f "/root/.acme.sh/acme.sh" ]; then
        echo "正在安装 acme.sh..."
        curl https://get.acme.sh | sh
    fi

    echo ""
    while true; do
        read -p "请输入您的域名: " domain
        if [ -z "$domain" ]; then red "域名不能为空！"; else break; fi
    done

    echo "$domain" > "$DOMAIN_FILE"
    random_email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"
    
    echo "请选择证书机构 (默认1: Let's Encrypt):"
    echo "1. Let's Encrypt"
    echo "2. Buypass"
    echo "3. ZeroSSL"
    read -p "请输入选项: " ca_choice
    ca_choice=${ca_choice:-1}

    case $ca_choice in
        1) ca="letsencrypt" ;;
        2) ca="buypass" ;;
        3) ca="zerossl" ;;
        *) ca="letsencrypt" ;;
    esac

    /root/.acme.sh/acme.sh --register-account -m "$random_email" --server "$ca"
    
    if command -v ufw &> /dev/null; then ufw allow 80 >/dev/null 2>&1; fi
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1

    if /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --server "$ca" --force; then
        /root/.acme.sh/acme.sh --installcert -d "$domain" --ecc --key-file "$KEY_FILE" --fullchain-file "$CERT_FILE"
        green "证书申请成功！请继续选择安装 Sing-box。"
        read -p "按回车返回..."
    else
        red "证书申请失败！请检查域名解析和 80 端口。"
        read -p "按回车返回..."
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

  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  if [ -z "$latest_version_tag" ]; then red "网络错误，无法获取版本"; exit 1; fi
  
  latest_version=${latest_version_tag#v}
  package_name="sing-box-${latest_version}-linux-${arch}"
  url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"
  
  curl -sLo "/root/${package_name}.tar.gz" "$url"
  tar -xzf "/root/${package_name}.tar.gz" -C /root
  systemctl stop sing-box >/dev/null 2>&1

  mv "/root/${package_name}/sing-box" "$WORKDIR/sing-box"
  rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

  chown root:root "$WORKDIR/sing-box"
  chmod +x "$WORKDIR/sing-box"
  green "核心安装完成。"
}

# 4. 配置与安装
configure_singbox() {
    if [ ! -f "$DOMAIN_FILE" ] || [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        red "错误：未检测到证书文件！请先执行 [1] 申请证书。"
        read -p "按回车返回..."
        return
    fi

    show_notice "$(green "生成配置文件")"
    local domain=$(cat "$DOMAIN_FILE")
    
    vmess_uuid=$("$WORKDIR/sing-box" generate uuid)
    tls_password=$("$WORKDIR/sing-box" generate rand --base64 16)
    hy_password=$vmess_uuid
    ws_path=$vmess_uuid
    hy_server_name=$domain

    read -p "Vmess 端口 (默认 2053): " vmess_port; vmess_port=${vmess_port:-2053}
    read -p "Hy2 端口 (默认 8433): " hy_port; hy_port=${hy_port:-8433}
    read -p "ShadowTLS 端口 (默认 9433): " tls_port; tls_port=${tls_port:-9433}
    
    server_ip=$(curl -s4m8 ip.sb -k || curl -s6m8 ip.sb -k)

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

    cat > "$WORKDIR/sbconfig_server.json" << EOF
{
  "log": { "disabled": false, "level": "info", "timestamp": true },
  "dns": { "servers": [{"type": "local"}], "strategy": "ipv4_only" },
  "inbounds": [
    {
        "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": $hy_port,
        "users": [{"password": "$hy_password"}],
        "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "$CERT_FILE", "key_path": "$KEY_FILE" }
    },
    {
      "type": "shadowtls", "tag": "ShadowTLS", "listen": "::", "listen_port": $tls_port, "version": 3,
      "users": [{"password": "$tls_password"}], "handshake": { "server": "www.samsung.com", "server_port": 443 },
      "strict_mode": true, "detour": "shadowsocks-shadowtls-in"
    },
    {
      "type": "shadowsocks", "tag": "shadowsocks-shadowtls-in", "listen": "::", "listen_port": 6530, 
      "method": "2022-blake3-aes-128-gcm", "password": "$tls_password"
    },
    {
        "type": "vmess", "tag": "vmess-sb", "listen": "::", "listen_port": $vmess_port,
        "users": [{"uuid": "$vmess_uuid", "alterId": 0}], "transport": { "type": "ws", "path": "$ws_path" },
        "tls":{ "enabled": true, "server_name": "$domain", "certificate_path": "$CERT_FILE", "key_path": "$KEY_FILE" }
    }
  ],
  "endpoints":[
    {
        "type":"wireguard", "tag":"warp-out",
        "address":["172.16.0.2/32","2606:4700:110:8f9a:dc05:2307:8bbc:5196/128"],
        "private_key":"8G4m+UBlxt2/kR0MOTQuKA6N0PTNsxdhnj0K84HDTH0=",
        "peers": [{ "address": "162.159.192.1", "port":2408, "public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=", "allowed_ips": ["0.0.0.0/0", "::/0"], "reserved":[213,132,110] }]
    }
  ], 
  "outbounds": [{ "type": "direct", "tag": "direct" }],
  "route": {
      "rules": [
        { "rule_set": ["geosite-openai"], "outbound": "warp-out" },
        { "domain_keyword": ["ipaddress"], "outbound": "warp-out" }
      ],
      "rule_set": [{ "tag": "geosite-openai", "type": "remote", "format": "binary", "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/openai.srs", "download_detour": "direct" }],
      "final": "direct"
    },
    "experimental": { "cache_file": { "enabled": true, "path": "cache.db", "store_fakeip": true } }
}
EOF

    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=$WORKDIR
ExecStart=$WORKDIR/sing-box run -c $WORKDIR/sbconfig_server.json
Restart=on-failure
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
        red "配置错误，Sing-box 启动失败。"
        "$WORKDIR/sing-box" check -c "$WORKDIR/sbconfig_server.json"
    fi
}

# 5. 客户端配置
show_client_configuration() {
    if [ ! -f "$WORKDIR/config" ]; then red "未找到配置文件"; return; fi
    source "$WORKDIR/config"
    local domain=$(cat "$DOMAIN_FILE")

    hy2_link="hysteria2://$HY_PASSWORD@$domain:$HY_PORT?insecure=0&alpn=h3&obfs=none&sni=$domain#hy2-$domain"
    tls_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$TLS_PASSWORD@$domain:$TLS_PORT" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"www.samsung.com\",\"password\":\"$TLS_PASSWORD\"}" | base64 -w0)#ShadowTLS-$domain"
    vmess_json="{\"add\":\"$domain\",\"aid\":\"0\",\"host\":\"$domain\",\"id\":\"$VMESS_UUID\",\"net\":\"ws\",\"path\":\"$WS_PATH\",\"port\":\"$VMESS_PORT\",\"ps\":\"Vmess-tls-$domain\",\"tls\":\"tls\",\"type\":\"none\",\"v\":\"2\"}"
    vmesswss_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"

    echo ""
    show_notice "配置信息 (截图保存)"
    green "=== Hysteria 2 ==="; echo "$hy2_link"; qrencode -t ANSIUTF8 "$hy2_link"
    echo ""; green "=== ShadowTLS (v3) ==="; echo "$tls_link"; qrencode -t ANSIUTF8 "$tls_link"
    echo ""; green "=== Vmess WS TLS ==="; echo "$vmesswss_link"; qrencode -t ANSIUTF8 "$vmesswss_link"
    echo ""; yellow "提示：以后输入 'sing' 可再次调出此菜单。"
    read -p "按回车返回..."
}

# 6. 端口跳跃
enable_hy2hopping(){
    interface=$(ip route get 8.8.8.8 | awk '{print $5}')
    if [ ! -f "$WORKDIR/config" ]; then red "请先安装 Sing-box"; return; fi
    source "$WORKDIR/config"
    read -p "起始端口 (20000): " start; start=${start:-20000}
    read -p "结束端口 (30000): " end; end=${end:-30000}
    iptables -t nat -A PREROUTING -i "$interface" -p udp --dport $start:$end -j DNAT --to-destination :$HY_PORT
    if command -v ip6tables &>/dev/null; then ip6tables -t nat -A PREROUTING -i "$interface" -p udp --dport $start:$end -j DNAT --to-destination :$HY_PORT; fi
    touch "$WORKDIR/hopping_enabled"
    green "端口跳跃已开启。"
}
disable_hy2hopping(){
    iptables -t nat -F PREROUTING
    if command -v ip6tables &>/dev/null; then ip6tables -t nat -F PREROUTING; fi
    rm -f "$WORKDIR/hopping_enabled"
    green "端口跳跃已关闭。"
}

# 7. 辅助功能
create_shortcut() { cat > /usr/bin/sing << EOF
#!/bin/bash
bash $0 show_menu
EOF
chmod +x /usr/bin/sing; }

enable_bbr() {
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    green "BBR 已开启。"
}
uninstall_singbox() {
    systemctl stop sing-box; systemctl disable sing-box
    rm -f /etc/systemd/system/sing-box.service; rm -rf "$WORKDIR"; rm -f /usr/bin/sing
    green "Sing-box 已卸载 (保留证书)。"
}

# ==========================================
# 8. 菜单系统 (含状态检测)
# ==========================================
show_menu() {
    clear
    # --- 状态检测逻辑 ---
    # 1. Sing-box 状态
    if systemctl is-active --quiet sing-box; then
        status_singbox="${clr_green}运行中${clr_reset}"
    else
        status_singbox="${clr_red}未运行${clr_reset}"
    fi

    # 2. 证书状态
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        status_cert="${clr_green}已申请${clr_reset}"
        domain_str=$(cat "$DOMAIN_FILE" 2>/dev/null)
        status_domain="${clr_green}${domain_str}${clr_reset}"
    else
        status_cert="${clr_red}未申请${clr_reset}"
        status_domain="${clr_yellow}未配置${clr_reset}"
    fi

    # 3. BBR 状态
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        status_bbr="${clr_green}已开启${clr_reset}"
    else
        status_bbr="${clr_yellow}未开启${clr_reset}"
    fi

    # 4. 端口跳跃状态
    if [ -f "$WORKDIR/hopping_enabled" ]; then
        status_hop="${clr_green}已开启${clr_reset}"
    else
        status_hop="${clr_yellow}未开启${clr_reset}"
    fi

    # 5. 内存状态
    # 获取内存 Total 和 Used (MB)
    mem_total=$(free -m | awk '/^Mem:/{print $2}')
    mem_used=$(free -m | awk '/^Mem:/{print $3}')
    if [ "$mem_total" -gt 0 ]; then
        mem_usage_pct=$((mem_used * 100 / mem_total))
        status_mem="${mem_used}MB / ${mem_total}MB (${mem_usage_pct}%)"
    else
        status_mem="无法读取"
    fi

    # --- 界面渲染 ---
    echo -e "${clr_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${clr_reset}"
    echo -e "           Sing-box 全能脚本 (管理面板)            "
    echo -e "${clr_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${clr_reset}"
    echo -e "系统内存: ${status_mem}"
    echo -e "BBR状态 : ${status_bbr}      端口跳跃: ${status_hop}"
    echo -e "----------------------------------------------------"
    echo -e "运行状态: ${status_singbox}"
    echo -e "证书状态: ${status_cert}      当前域名: ${status_domain}"
    echo -e "${clr_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${clr_reset}"
    echo -e " 1. 申请 SSL 证书 (第一步，必须)"
    echo -e " 2. 安装/重置 Sing-box (需要先有证书)"
    echo -e "----------------------------------------------------"
    echo -e " 3. 查看客户端配置 (二维码/链接)"
    echo -e " 4. 开启/管理 Hy2 端口跳跃"
    echo -e " 5. 开启 BBR 加速"
    echo -e " 6. 卸载 Sing-box"
    echo -e " 7. 重启服务"
    echo -e " 0. 退出"
    echo ""
    read -p " 请输入数字选择: " choice
    
    case $choice in
        1) apply_certificate ;;
        2) install_base; download_singbox; configure_singbox ;;
        3) show_client_configuration ;;
        4) 
            if [ -f "$WORKDIR/hopping_enabled" ]; then
                read -p "是否关闭端口跳跃? (y/n): " c
                [[ "$c" == "y" ]] && disable_hy2hopping
            else
                enable_hy2hopping
            fi
            ;;
        5) enable_bbr ;;
        6) uninstall_singbox ;;
        7) systemctl restart sing-box && green "已发送重启命令" ;;
        0) exit 0 ;;
        *) echo "无效输入" ;;
    esac

    [[ "$choice" != "0" ]] && { echo ""; read -p "按回车返回主菜单..."; show_menu; }
}

if [[ "$1" == "show_menu" ]]; then show_menu; else show_menu; fi
