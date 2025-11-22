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
    
    [ ! -f /etc/sysctl.conf.bak ] && cp /etc/sysctl.conf /etc/sysctl.conf.bak

    cat > /etc/sysctl.conf << EOF
# --- 性能优化参数 ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF

    sysctl -p > /dev/null 2>&1
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

# 5. 配置与安装 (关键修复：Systemd 环境变量)
configure_singbox() {
    if [ ! -f "$CERT_FILE" ]; then red "请先申请证书 [选项1]"; read -p "回车返回..."; return; fi
    show_notice "$(green "生成适配 1.12+ 版本的配置文件")"
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

    # 生成 JSON 配置
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
      "type": "shadowtls", "tag": "ShadowTLS", "listen": "::
