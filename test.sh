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
clr_red="\033[31m"; clr_green="\033[32m"; clr_yellow="\033[33m"; clr_reset="\033[0m"

if [[ $EUID -ne 0 ]]; then red "错误：必须以 root 身份运行！"; exit 1; fi

# 信息提示框
show_notice() {
    local message="$1"
    echo -e "\e[48;5;34m\e[97m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[97m┃\e[0m                    ${message}                                                        "
    echo -e "\e[48;5;34m\e[97m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

# 1. 系统依赖安装
install_base(){
  local packages=("qrencode" "jq" "iptables" "curl" "wget" "socat" "tar" "lsof")
  if [ -n "$(command -v apt)" ]; then CMD="apt"; $CMD update >/dev/null 2>&1;
  elif [ -n "$(command -v yum)" ]; then CMD="yum";
  elif [ -n "$(command -v dnf)" ]; then CMD="dnf";
  else red "未检测到支持的包管理器"; exit 1; fi

  echo "正在检查系统依赖..."
  for package in "${packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then $CMD install -y "$package" > /dev/null 2>&1; fi
  done
}

# 2. 深度网络优化 (核心优化部分)
optimize_sysctl() {
    show_notice "$(green "正在执行深度网络优化 (BBR + TCP调优)")"
    
    # 备份原文件
    [ ! -f /etc/sysctl.conf.bak ] && cp /etc/sysctl.conf /etc/sysctl.conf.bak

    cat > /etc/sysctl.conf << EOF
# --- 性能优化参数 ---
# 开启 BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 增加文件描述符限制
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192

# 增加 TCP 缓冲区大小 (提升大流量速度)
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000

# 调大 TCP 窗口 (关键)
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF

    sysctl -p > /dev/null 2>&1
    
    # 提高系统 ulimit 限制
    echo "* soft nofile 1000000" > /etc/security/limits.conf
    echo "* hard nofile 1000000" >> /etc/security/limits.conf
    echo "root soft nofile 1000000" >> /etc/security/limits.conf
    echo "root hard nofile 1000000" >> /etc/security/limits.conf
    
    green "网络参数优化完成！"
}

# 3. 证书申请模块
apply_certificate() {
    install_base
    echo ""; show_notice "$(green "独立模块: 域名与证书配置")"
    
    if lsof -i:80 > /dev/null 2>&1; then
        yellow "正在释放 80 端口..."
        systemctl stop nginx apache2 httpd caddy > /dev/null 2>&1
    fi

    if ! [ -f "/root/.acme.sh/acme.sh" ]; then curl https://get.acme.sh | sh; fi

    echo ""
    while true; do
        read -p "请输入您的域名: " domain
        if [ -z "$domain" ]; then red "域名不能为空！"; else break; fi
    done

    echo "$domain" > "$DOMAIN_FILE"
    random_email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"
    
    echo "请选择证书机构 (默认1): 1.Let's Encrypt  2.Buypass  3.ZeroSSL"
    read -p "选项: " ca_choice
    case ${ca_choice:-1} in 1) ca="letsencrypt";; 2) ca="buypass";; 3) ca="zerossl";; *) ca="letsencrypt";; esac

    /root/.acme.sh/acme.sh --register-account -m "$random_email" --server "$ca"
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1

    if /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --server "$ca" --force; then
        /root/.acme.sh/acme.sh --installcert -d "$domain" --ecc --key-file "$KEY_FILE" --fullchain-file "$CERT_FILE"
        green "证书申请成功！"
        read -p "按回车返回..."
    else
        red "证书申请失败！检查域名解析。"
        read -p "按回车返回..."
        return
    fi
}

# 4. 下载 Sing-box
download_singbox(){
  show_notice "$(green "开始安装 Sing-box 核心")"
  mkdir -p "$WORKDIR"
  arch=$(uname -m)
  case ${arch} in x86_64) arch="amd64";; aarch64) arch="arm64";; armv7l) arch="armv7";; *) red "不支持架构"; exit 1;; esac

  tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  if [ -z "$tag" ]; then red "无法获取版本"; exit 1; fi
  
  ver=${tag#v}
  url="https://github.com/SagerNet/sing-box/releases/download/${tag}/sing-box-${ver}-linux-${arch}.tar.gz"
  
  curl -sLo "/root/sb.tar.gz" "$url"
  tar -xzf "/root/sb.tar.gz" -C /root
  systemctl stop sing-box >/dev/null 2>&1
  mv "/root/sing-box-${ver}-linux-${arch}/sing-box" "$WORKDIR/sing-box"
  rm -rf "/root/sb.tar.gz" "/root/sing-box-${ver}-linux-${arch}"
  chown root:root "$WORKDIR/sing-box"
  chmod +x "$WORKDIR/sing-box"
}

# 5. 配置与安装 (含 DNS 和 Hy2 优化)
configure_singbox() {
    if [ ! -f "$CERT_FILE" ]; then red "请先申请证书 [选项1]"; read -p "回车返回..."; return; fi
    show_notice "$(green "生成高性能配置文件")"
    local domain=$(cat "$DOMAIN_FILE")
    
    uuid=$("$WORKDIR/sing-box" generate uuid)
    pwd=$("$WORKDIR/sing-box" generate rand --base64 16)
    
    read -p "Vmess 端口 (2053): " vp; vp=${vp:-2053}
    read -p "Hy2 端口 (8433): " hp; hp=${hp:-8433}
    read -p "ShadowTLS 端口 (9433): " tp; tp=${tp:-9433}
    
    cat > "$WORKDIR/config" <<EOF
SERVER_IP='$(curl -s4m8 ip.sb -k)'
HY_PORT='$hp'
HY_SERVER_NAME='$domain'
HY_PASSWORD='$uuid'
VMESS_PORT='$vp'
VMESS_UUID='$uuid'
WS_PATH='$uuid'
TLS_PORT='$tp'
TLS_PASSWORD='$pwd'
EOF

    # 优化点：使用 8.8.8.8 DNS，Hy2 开启 ignore_client_bandwidth
    cat > "$WORKDIR/sbconfig_server.json" << EOF
{
  "log": { "disabled": false, "level": "info", "timestamp": true },
  "dns": { 
    "servers": [
        {"tag": "google", "address": "8.8.8.8", "detour": "direct"},
        {"tag": "local", "address": "local", "detour": "direct"}
    ], 
    "strategy": "ipv4_only" 
  },
  "inbounds": [
    {
        "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": $hp,
        "users": [{"password": "$uuid"}],
        "ignore_client_bandwidth": true,
        "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "$CERT_FILE", "key_path": "$KEY_FILE" }
    },
    {
      "type": "shadowtls", "tag": "ShadowTLS", "listen": "::", "listen_port": $tp, "version": 3,
      "users": [{"password": "$pwd"}], "handshake": { "server": "www.samsung.com", "server_port": 443 },
      "strict_mode": true, "detour": "shadowsocks-shadowtls-in"
    },
    {
      "type": "shadowsocks", "tag": "shadowsocks-shadowtls-in", "listen": "::", "listen_port": 6530, 
      "method": "2022-blake3-aes-128-gcm", "password": "$pwd"
    },
    {
        "type": "vmess", "tag": "vmess-sb", "listen": "::", "listen_port": $vp,
        "users": [{"uuid": "$uuid", "alterId": 0}], "transport": { "type": "ws", "path": "$uuid" },
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

    # 优化点：增加 Nice=-10 提高优先级
    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=$WORKDIR
ExecStart=$WORKDIR/sing-box run -c $WORKDIR/sbconfig_server.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
Nice=-10
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    
    if "$WORKDIR/sing-box" check -c "$WORKDIR/sbconfig_server.json"; then
        systemctl restart sing-box
        create_shortcut
        show_client_configuration
    else
        red "启动失败，请检查配置。"
        "$WORKDIR/sing-box" check -c "$WORKDIR/sbconfig_server.json"
    fi
}

# 6. 客户端展示
show_client_configuration() {
    if [ ! -f "$WORKDIR/config" ]; then red "未安装"; return; fi
    source "$WORKDIR/config"
    local d=$(cat "$DOMAIN_FILE")

    hy2="hysteria2://$HY_PASSWORD@$d:$HY_PORT?insecure=0&alpn=h3&obfs=none&sni=$d#hy2-$d"
    tls="ss://$(echo -n "2022-blake3-aes-128-gcm:$TLS_PASSWORD@$d:$TLS_PORT" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"www.samsung.com\",\"password\":\"$TLS_PASSWORD\"}" | base64 -w0)#ShadowTLS-$d"
    vm="{\"add\":\"$d\",\"aid\":\"0\",\"host\":\"$d\",\"id\":\"$VMESS_UUID\",\"net\":\"ws\",\"path\":\"$WS_PATH\",\"port\":\"$VMESS_PORT\",\"ps\":\"Vmess-tls-$d\",\"tls\":\"tls\",\"type\":\"none\",\"v\":\"2\"}"
    vm_link="vmess://$(echo -n "$vm" | base64 -w 0)"

    echo ""; show_notice "配置信息 (截图保存)"
    green "=== Hysteria 2 (推荐:速度最快) ==="; echo "$hy2"; qrencode -t ANSIUTF8 "$hy2"
    echo ""; green "=== ShadowTLS (推荐:防墙最强) ==="; echo "$tls"; qrencode -t ANSIUTF8 "$tls"
    echo ""; green "=== Vmess WS TLS (兼容性好) ==="; echo "$vm_link"; qrencode -t ANSIUTF8 "$vm_link"
    echo ""; read -p "按回车返回..."
}

# 7. 端口跳跃
enable_hy2hopping(){
    if=$(ip route get 8.8.8.8 | awk '{print $5}')
    if [ ! -f "$WORKDIR/config" ]; then red "请先安装"; return; fi
    source "$WORKDIR/config"
    read -p "起始端口 (20000): " s; s=${s:-20000}
    read -p "结束端口 (30000): " e; e=${e:-30000}
    iptables -t nat -A PREROUTING -i "$if" -p udp --dport $s:$e -j DNAT --to-destination :$HY_PORT
    if command -v ip6tables &>/dev/null; then ip6tables -t nat -A PREROUTING -i "$if" -p udp --dport $s:$e -j DNAT --to-destination :$HY_PORT; fi
    touch "$WORKDIR/hopping_enabled"
    green "端口跳跃已开启。"
}
disable_hy2hopping(){
    iptables -t nat -F PREROUTING
    if command -v ip6tables &>/dev/null; then ip6tables -t nat -F PREROUTING; fi
    rm -f "$WORKDIR/hopping_enabled"
    green "端口跳跃已关闭。"
}

# 8. 辅助功能
create_shortcut() { cat > /usr/bin/sing << EOF
#!/bin/bash
bash $0 show_menu
EOF
chmod +x /usr/bin/sing; }

uninstall_singbox() {
    systemctl stop sing-box; systemctl disable sing-box
    rm -f /etc/systemd/system/sing-box.service; rm -rf "$WORKDIR"; rm -f /usr/bin/sing
    green "Sing-box 已卸载 (保留证书)。"
}

# 9. 菜单系统
show_menu() {
    clear
    if systemctl is-active --quiet sing-box; then st_sb="${clr_green}运行中${clr_reset}"; else st_sb="${clr_red}未运行${clr_reset}"; fi
    if [ -f "$CERT_FILE" ]; then st_cert="${clr_green}已申请${clr_reset}"; else st_cert="${clr_red}未申请${clr_reset}"; fi
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then st_bbr="${clr_green}已开启(含调优)${clr_reset}"; else st_bbr="${clr_yellow}未优化${clr_reset}"; fi
    mem=$(free -m | awk '/^Mem:/{print $3"M/"$2"M"}')

    echo -e "${clr_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${clr_reset}"
    echo -e "        Sing-box 极速全能脚本 (内核优化版)        "
    echo -e "${clr_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${clr_reset}"
    echo -e " 状态: ${st_sb}   内存: ${mem}   BBR/优化: ${st_bbr}"
    echo -e " 证书: ${st_cert}"
    echo -e "${clr_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${clr_reset}"
    echo -e " 1. 申请 SSL 证书 (必须)"
    echo -e " 2. 安装 Sing-box (自动应用内核优化)"
    echo -e " 3. 查看配置 / 二维码"
    echo -e " 4. 开启/关闭 Hy2 端口跳跃"
    echo -e " 5. 单独执行网络优化 (Sysctl)"
    echo -e " 6. 卸载"
    echo -e " 7. 重启服务"
    echo -e " 0. 退出"
    echo ""
    read -p " 选择: " c
    case $c in
        1) apply_certificate ;;
        2) optimize_sysctl; download_singbox; configure_singbox ;;
        3) show_client_configuration ;;
        4) [ -f "$WORKDIR/hopping_enabled" ] && disable_hy2hopping || enable_hy2hopping ;;
        5) optimize_sysctl ;;
        6) uninstall_singbox ;;
        7) systemctl restart sing-box && green "重启成功" ;;
        0) exit 0 ;;
        *) echo "无效" ;;
    esac
    [ "$c" != "0" ] && { echo ""; read -p "回车返回..."; show_menu; }
}

if [[ "$1" == "show_menu" ]]; then show_menu; else show_menu; fi
