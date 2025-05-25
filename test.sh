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
red() { echo -e "\033[31m\033[01m$*\033[0m"; } # 红色
green() { echo -e "\033[32m\033[01m$*\033[0m"; } # 绿色
yellow() { echo -e "\033[33m\033[01m$*\033[0m"; } # 黄色

#信息提示
show_notice() {
    local message="$1"

    local green_bg="\e[48;5;34m" # 更柔和的绿色背景
    local white_fg="\e[97m"
    local reset="\e[0m"
    
    # 获取终端宽度
    local term_width=$(tput cols)
    local line_char="━"
    local border_line=""
    for ((i=0; i<term_width; i++)); do
        border_line="${border_line}${line_char}"
    done

    # 计算消息的填充
    local message_len=${#message}
    # 移除颜色代码以获得实际长度
    local plain_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
    local plain_message_len=${#plain_message}
    
    local padding_total=$((term_width - plain_message_len - 4)) # 4 for "┃  ┃"
    local padding_left=$((padding_total / 2))
    local padding_right=$((padding_total - padding_left))

    local left_spaces=$(printf '%*s' "$padding_left")
    local right_spaces=$(printf '%*s' "$padding_right")

    echo -e "${green_bg}${white_fg}${border_line}${reset}"
    echo -e "${white_fg}┃${reset}$(printf '%*s' "$((term_width-2))")${white_fg}┃${reset}" # 空行
    echo -e "${white_fg}┃${reset}${left_spaces}${message}${right_spaces}${white_fg}┃${reset}"
    echo -e "${white_fg}┃${reset}$(printf '%*s' "$((term_width-2))")${white_fg}┃${reset}" # 空行
    echo -e "${green_bg}${white_fg}${border_line}${reset}"
}

# 安装依赖
install_base(){
  local packages=("qrencode" "jq" "iptables" "curl" "socat") # Added curl and socat for broader compatibility and cert generation
  for package in "${packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then
      echo "正在安装 $package..."
      if [ -n "$(command -v apt-get)" ]; then # Changed to apt-get for broader compatibility
        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y "$package" -qq > /dev/null 2>&1
      elif [ -n "$(command -v yum)" ]; then
        sudo yum install -y "$package" -q > /dev/null 2>&1
      elif [ -n "$(command -v dnf)" ]; then
        sudo dnf install -y "$package" -q > /dev/null 2>&1
      elif [ -n "$(command -v zypper)" ]; then
        sudo zypper install -y "$package" > /dev/null 2>&1
      elif [ -n "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm "$package" > /dev/null 2>&1
      else
        echo "无法自动安装 $package。请手动安装，并重新运行脚本。"
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
      s390x)
          arch="s390x"
          ;;
      riscv64)
          arch="riscv64"
          ;;
  esac
  # Fetch the latest (including pre-releases) release version number from GitHub API
  # 正式版
  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '.[] | select(.prerelease==false) | .tag_name' | head -n 1)
  if [ -z "$latest_version_tag" ]; then
      yellow "获取正式版失败，尝试获取最新版（包含预发布）..."
      latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '.[0].tag_name')
  fi

  if [ -z "$latest_version_tag" ]; then
      red "无法获取最新的 sing-box 版本标签。请检查网络或稍后再试。"
      exit 1
  fi

  latest_version=${latest_version_tag#v} # Remove 'v' prefix from version number
  echo "Latest version: $latest_version_tag ($latest_version)"
  
  package_name="sing-box-${latest_version}-linux-${arch}"
  url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"
  
  echo "正在下载 sing-box: $url"
  # Download the latest release package (.tar.gz) from GitHub
  if curl -sLo "/root/${package_name}.tar.gz" "$url"; then
      echo "下载成功。"
  else
      red "下载失败。请检查URL或网络连接。"
      # 尝试使用备用下载链接 (如果官方链接有问题)
      # url_mirror="https://ghproxy.com/${url}" # 示例代理
      # echo "尝试备用下载链接: $url_mirror"
      # if curl -sLo "/root/${package_name}.tar.gz" "$url_mirror"; then
      #     echo "备用下载成功。"
      # else
      #     red "备用下载也失败了。"
      #     exit 1
      # fi
      exit 1
  fi

  echo "正在解压..."
  tar -xzf "/root/${package_name}.tar.gz" -C /root
  mkdir -p /root/sbox # 确保sbox目录存在
  mv "/root/${package_name}/sing-box" /root/sbox/sing-box

  echo "清理下载文件..."
  rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

  echo "设置权限..."
  chown root:root /root/sbox/sing-box
  chmod +x /root/sbox/sing-box
  echo "sing-box 内核更新/安装完成。"
}

# client configuration
show_client_configuration() {
  if [ ! -f "/root/sbox/config" ]; then
      red "配置文件 /root/sbox/config 不存在。请先完成安装。"
      return 1
  fi
  if [ ! -f "/root/domain.txt" ]; then
      red "域名文件 /root/domain.txt 不存在。请先完成安装。"
      return 1
  fi

  current_domain=$(cat /root/domain.txt)

  # hy port
  hy_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy password
  hy_password=$(grep -o "HY_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  hy2_link="hysteria2://${hy_password}@${current_domain}:${hy_port}?insecure=0&alpn=h3&obfs=none&sni=${current_domain}#hy2-${current_domain}"

  echo ""
  show_notice "$(green "Hysteria2 通用链接和二维码")"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Hysteria2 通用链接 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$hy2_link"
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Hysteria2 二维码 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  qrencode -t UTF8 "$hy2_link"
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # tls port
  tls_port=$(grep -o "TLS_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # tls password
  tls_password=$(grep -o "TLS_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # ShadowTLS link uses base64 for parts of its query parameters
  shadowtls_password_b64=$(echo -n "$tls_password" | base64 -w0)
  shadowtls_config_json="{\"version\":\"3\",\"host\":\"www.samsung.com\",\"password\":\"$tls_password\"}"
  shadowtls_config_b64=$(echo -n "$shadowtls_config_json" | base64 -w0)
  
  # SS part of ShadowTLS link
  ss_part_plain="2022-blake3-aes-128-gcm:${tls_password}@${current_domain}:${tls_port}"
  ss_part_b64=$(echo -n "$ss_part_plain" | base64 -w0)

  tls_link="ss://${ss_part_b64}?shadow-tls=${shadowtls_config_b64}#ShadowTLS-${current_domain}"

  echo ""
  show_notice "$(green "ShadowTLS 通用链接和二维码")"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ShadowTLS 通用链接 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$tls_link"
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ShadowTLS 二维码 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  qrencode -t UTF8 "$tls_link"
  green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  vmess_uuid=$(grep -o "VMESS_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  ws_path=$(grep -o "WS_PATH='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  vmess_port_val=$(grep -o "VMESS_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}') # Read from config

  vmess_json_config='{"add":"'${current_domain}'","aid":"0","host":"'${current_domain}'","id":"'$vmess_uuid'","net":"ws","path":"'$ws_path'","port":"'$vmess_port_val'","ps":"Vmess-TLS-'${current_domain}'","tls":"tls","type":"none","v":"2"}'
  vmesswss_link='vmess://'$(echo -n "$vmess_json_config" | base64 -w 0)
  
  echo ""
  show_notice "$(yellow "VMess WS(TLS) 通用链接和二维码")"
  echo ""
  yellow "━━━━━━━━━━━━━━━━━━━━ VMess WSS 链接 (替换 ${current_domain} 为优选IP可优化) ━━━━━━━━━━━━━━━━━━━━━━"
  echo "$vmesswss_link"
  yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ VMess WSS 二维码 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  qrencode -t UTF8 "$vmesswss_link"
  yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

#enable bbr
enable_bbr() {
    if grep -q "tcp_bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
        echo "BBR 已经加载。"
    else
        echo "BBR 未加载。"
    fi
    
    if lsmod | grep -q "tcp_bbr"; then
        echo "BBR 模块已存在。"
    else
        echo "BBR 模块不存在, 尝试加载..."
        sudo modprobe tcp_bbr
        if [ $? -ne 0 ]; then
            yellow "加载 BBR 模块失败。可能需要更新内核或手动配置。"
        else
            echo "BBR 模块加载成功。"
        fi
    fi

    echo "尝试启用 BBR..."
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    
    # 检查是否成功
    current_qdisc=$(cat /proc/sys/net/core/default_qdisc)
    current_congestion_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control)

    if [[ "$current_qdisc" == "fq" ]] && [[ "$current_congestion_control" == "bbr" ]]; then
        green "BBR 已成功启用。"
        echo "net.core.default_qdisc = fq" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
    else
        red "启用 BBR 失败。"
        yellow "当前 qdisc: $current_qdisc (期望: fq)"
        yellow "当前 congestion_control: $current_congestion_control (期望: bbr)"
        yellow "你可能需要手动检查内核版本和系统配置。"
        yellow "可以尝试使用第三方脚本如 teddysun/across/bbr.sh，但请注意其风险。"
        read -p "是否尝试使用 teddysun 的 BBR 脚本? (y/N): " use_teddysun
        if [[ "$use_teddysun" =~ ^[Yy]$ ]]; then
            bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
        fi
    fi
    echo ""
}

# 创建快捷方式
create_shortcut() {
  mkdir -p /root/sbox
  cat > /root/sbox/sing.sh << EOF
#!/usr/bin/env bash
bash <(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/test.sh) \$1
EOF
  chmod +x /root/sbox/sing.sh
  ln -sf /root/sbox/sing.sh /usr/local/bin/sing # Changed to /usr/local/bin
  if [ -f /usr/local/bin/sing ]; then
    green "快捷方式 'sing' 创建成功 (/usr/local/bin/sing)。"
  else
    red "快捷方式 'sing' 创建失败。"
  fi
}

# 获取主网络接口
get_main_interface() {
    interface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    if [ -z "$interface" ]; then
        interface=$(ip -6 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    fi
    if [ -z "$interface" ]; then
        red "无法自动获取主网络接口。"
        read -p "请手动输入主网络接口名称 (例如 eth0, ens3): " interface
        if [ -z "$interface" ]; then
            red "未提供接口名称，端口跳跃功能可能无法正常工作。"
            return 1
        fi
    fi
    echo "$interface"
}


# 开启hysteria2端口跳跃
enable_hy2hopping(){
  local interface_name
  interface_name=$(get_main_interface)
  if [ -z "$interface_name" ]; then
      return 1
  fi

  echo "当前网络接口: $interface_name"
  echo "开启端口跳跃"
  hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  read -p "输入UDP端口范围的起始值(默认20000): " -r start_port
  start_port=${start_port:-20000}
  read -p "输入UDP端口范围的结束值(默认30000): " -r end_port
  end_port=${end_port:-30000}

  # 添加规则
  sudo iptables -t nat -A PREROUTING -i "$interface_name" -p udp --dport "$start_port:$end_port" -j DNAT --to-destination ":$hy_current_port" -m comment --comment "hy2_port_hopping"
  sudo ip6tables -t nat -A PREROUTING -i "$interface_name" -p udp --dport "$start_port:$end_port" -j DNAT --to-destination ":$hy_current_port" -m comment --comment "hy2_port_hopping"
  
  # 保存到配置文件，以便卸载时可以精确删除
  sed -i '/^HY_HOPPING_START_PORT=/d' /root/sbox/config
  sed -i '/^HY_HOPPING_END_PORT=/d' /root/sbox/config
  echo "HY_HOPPING_START_PORT='$start_port'" >> /root/sbox/config
  echo "HY_HOPPING_END_PORT='$end_port'" >> /root/sbox/config
  sed -i "s/HY_HOPPING='FALSE'/HY_HOPPING='TRUE'/" /root/sbox/config
  green "端口跳跃规则已添加。"
}

disable_hy2hopping(){
  local interface_name
  interface_name=$(get_main_interface)
  if [ -z "$interface_name" ]; then
      return 1
  fi

  echo "当前网络接口: $interface_name"
  echo "关闭端口跳跃"
  hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  start_port=$(grep -o "HY_HOPPING_START_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  end_port=$(grep -o "HY_HOPPING_END_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')

  if [ -n "$start_port" ] && [ -n "$end_port" ]; then
      # 删除特定规则
      sudo iptables -t nat -D PREROUTING -i "$interface_name" -p udp --dport "$start_port:$end_port" -j DNAT --to-destination ":$hy_current_port" -m comment --comment "hy2_port_hopping" >/dev/null 2>&1
      sudo ip6tables -t nat -D PREROUTING -i "$interface_name" -p udp --dport "$start_port:$end_port" -j DNAT --to-destination ":$hy_current_port" -m comment --comment "hy2_port_hopping" >/dev/null 2>&1
      green "通过注释精确删除端口跳跃规则。"
  else
      yellow "未找到之前保存的端口范围，尝试通用删除（可能误删其他规则，不推荐）。"
      # Fallback - less safe, flushes all PREROUTING in nat table if no comment was found or config missing
      # read -p "警告：无法精确删除规则。是否要清空整个 PREROUTING 链 (nat 表)? (y/N): " confirm_flush
      # if [[ "$confirm_flush" =~ ^[Yy]$ ]]; then
      #    sudo iptables -t nat -F PREROUTING
      #    sudo ip6tables -t nat -F PREROUTING
      #    red "PREROUTING 链已清空。"
      # else
      #    yellow "操作已取消。"
      # fi
      yellow "建议手动检查并删除iptables规则。"
  fi
  
  sed -i "s/HY_HOPPING='TRUE'/HY_HOPPING='FALSE'/" /root/sbox/config
  sed -i '/^HY_HOPPING_START_PORT=/d' /root/sbox/config
  sed -i '/^HY_HOPPING_END_PORT=/d' /root/sbox/config
  echo "端口跳跃已关闭。"
}

view_hy2hopping_rules() {
    echo "IPv4 NAT PREROUTING 规则 (UDP):"
    sudo iptables -t nat -L PREROUTING -n -v | grep "udp" | grep "hy2_port_hopping"
    echo ""
    echo "IPv6 NAT PREROUTING 规则 (UDP):"
    sudo ip6tables -t nat -L PREROUTING -n -v | grep "udp" | grep "hy2_port_hopping"
}


uninstall_singbox() {
    echo "正在停止 sing-box 服务..."
    sudo systemctl stop sing-box
    sudo systemctl disable sing-box > /dev/null 2>&1
    echo "服务已停止并禁用。"

    # 如果开启了端口跳跃，尝试关闭
    if grep -q "HY_HOPPING='TRUE'" /root/sbox/config 2>/dev/null; then
        echo "检测到端口跳跃已开启，正在尝试关闭..."
        disable_hy2hopping
    fi

    echo "正在删除文件..."
    sudo rm -f /etc/systemd/system/sing-box.service
    sudo rm -f /root/sbox/sbconfig_server.json
    sudo rm -f /root/sbox/sing-box
    sudo rm -f /root/sbox/config
    sudo rm -f /usr/local/bin/sing # Adjusted path
    sudo rm -f /root/sbox/sing.sh
    sudo rm -f /root/cert.crt /root/private.key /root/domain.txt # Remove certs and domain file
    sudo rm -rf /root/sbox/

    sudo systemctl daemon-reload # 重新加载 systemd 配置
    echo "卸载完成。"
}

# 申请证书
apply_certificate() {
    read -p "请输入你的域名 (例如: mydomain.com): " domain
    if [ -z "$domain" ]; then
        red "域名不能为空！"
        return 1
    fi
    echo "$domain" > /root/domain.txt

    # 检查80端口是否被占用
    if sudo lsof -i:80 -t >/dev/null; then
        red "错误: 80端口已被占用。请先停止占用80端口的程序 (例如 Nginx, Apache, Caddy 等)，然后再运行此脚本。"
        return 1
    fi
    
    # 安装 acme.sh
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        echo "正在安装 acme.sh..."
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            red "acme.sh 安装失败。"
            return 1
        fi
        # shellcheck source=/dev/null
        source ~/.bashrc # 使 acme.sh 命令可用
         ~/.acme.sh/acme.sh --upgrade --auto-upgrade #升级acme脚本并开启自动更新证书
    else
        echo "acme.sh 已安装。"
    fi

    # 注册邮箱 (可选，但推荐)
    # read -p "请输入你的邮箱 (用于证书申请通知，可留空): " email
    # if [ -n "$email" ]; then
    #    ~/.acme.sh/acme.sh --register-account -m "$email"
    # fi
    
    # 切换默认 CA (可选, Let's Encrypt 是默认)
    # ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

    echo "正在为域名 $domain 申请证书 (standalone模式)..."
    # 使用standalone模式申请证书
    if ~/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256; then
        echo "证书申请成功。"
        echo "正在安装证书到 /root 目录..."
        if ~/.acme.sh/acme.sh --install-cert -d "$domain" --ecc \
            --key-file /root/private.key \
            --fullchain-file /root/cert.crt; then
            green "证书和密钥已成功安装到 /root/private.key 和 /root/cert.crt"
            # 设置定时任务自动续签
            # (acme.sh 默认会添加 cronjob，这里可以确认或自定义)
            # crontab -l | grep -q "acme.sh --cron" || (crontab -l; echo "0 0 * * * \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" > /dev/null") | crontab -
            # echo "已尝试添加证书自动续签任务。"
            return 0
        else
            red "证书安装失败。"
            return 1
        fi
    else
        red "证书申请失败。请检查域名解析、防火墙设置或查看 acme.sh 日志。"
        return 1
    fi
}


# 主程序开始
install_base

if [ "$1" == "uninstall" ]; then
    uninstall_singbox
    exit 0
fi
if [ "$1" == "show" ]; then
    show_client_configuration
    exit 0
fi
if [ "$1" == "update" ]; then
    show_notice "更新 Sing-box 内核..."
    download_singbox
    if [ -f "/root/sbox/sing-box" ] && [ -f "/root/sbox/sbconfig_server.json" ]; then
        if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
            echo "配置文件检查成功。正在重启 sing-box 服务..."
            sudo systemctl restart sing-box
            green "sing-box 服务已重启。"
        else
            red "新的 sing-box 内核与现有配置文件不兼容。请检查错误信息。"
        fi
    else
        yellow "sing-box 未完全安装，无法重启服务。"
    fi
    exit 0
fi


# Check if reality.json, sing-box, and sing-box.service already exist
if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/root/sbox/sing-box" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then
    echo ""
    yellow "sing-box 已安装。"
    echo ""
    echo "请选择操作:"
    echo "1. 重新安装 (会先卸载)"
    echo "2. 显示客户端配置"
    echo "3. 卸载 sing-box"
    echo "4. 更新 sing-box 内核"
    echo "5. 管理 Hy2 端口跳跃"
    echo "6. 启用 BBR 加速"
    echo "7. 重启 sing-box 服务"
    echo "8. 申请/更新SSL证书"
    echo "0. 退出"
    echo ""
    read -p "输入你的选择 (0-8): " choice

    case $choice in
      1)
        show_notice "开始卸载旧版本..."
        uninstall_singbox
        echo "旧版本卸载完成。即将开始全新安装..."
        # Fall through to new installation
        ;;
      2)
        show_client_configuration
        exit 0
        ;;
      3)
        uninstall_singbox
        exit 0
        ;;
      4)
        show_notice "更新 Sing-box 内核..."
        download_singbox
        if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
            echo "配置文件检查成功。正在重启 sing-box 服务..."
            sudo systemctl restart sing-box
            green "sing-box 服务已重启。"
        else
            red "新的 sing-box 内核与现有配置文件不兼容。请检查错误信息。"
        fi
        exit 0
        ;;
      5) # Hy2端口跳跃管理
        while true; do
            ishopping=$(grep '^HY_HOPPING=' /root/sbox/config | cut -d"'" -f2)
            echo ""
            if [ "$ishopping" = "FALSE" ]; then
                green "Hy2 端口跳跃当前状态: 关闭"
                read -p "是否要开启端口跳跃? (y/N): " enable_choice
                if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
                    echo "开始设置端口跳跃范围..."
                    enable_hy2hopping
                else
                    echo "操作取消。"
                    break
                fi
            else
                yellow "Hy2 端口跳跃当前状态: 开启"
                echo ""
                green "请选择操作："
                echo "  1. 关闭端口跳跃"
                echo "  2. 重新设置端口跳跃范围 (会先关闭再开启)"
                echo "  3. 查看当前端口跳跃规则"
                echo "  0. 返回主菜单"
                echo ""
                read -p "请输入对应数字 (0-3): " hopping_input
                echo ""
                case $hopping_input in
                    1)
                      disable_hy2hopping
                      ;;
                    2)
                      disable_hy2hopping
                      echo "旧规则已删除。开始重新设置端口跳跃..."
                      enable_hy2hopping
                      ;;
                    3)
                      view_hy2hopping_rules
                      ;;
                    0)
                      echo "返回主菜单..."
                      break
                      ;;
                    *)
                      red "无效的选项。"
                      ;;
                esac
            fi
            read -p "按 Enter键 继续端口跳跃管理或输入 '0' 退出..." continue_choice
            if [[ "$continue_choice" == "0" ]]; then
                break
            fi
        done
        exit 0
        ;;
      6)
        enable_bbr
        exit 0
        ;;
      7)
        echo "正在重启 sing-box 服务..."
        sudo systemctl restart sing-box
        if sudo systemctl is-active --quiet sing-box; then
            green "sing-box 服务已成功重启。"
        else
            red "sing-box 服务重启失败。请检查日志: sudo journalctl -u sing-box -n 50 --no-pager"
        fi
        ;;
      8)
        apply_certificate
        # 如果证书更新后，需要重启 sing-box 使其加载新证书
        if [ $? -eq 0 ]; then
            echo "证书操作完成。如果证书已更新，建议重启 sing-box 服务。"
            read -p "是否立即重启 sing-box 服务? (y/N): " restart_choice
            if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                sudo systemctl restart sing-box
                green "sing-box 服务已重启。"
            fi
        fi
        exit 0
        ;;
      0)
        echo "退出脚本。"
        exit 0
        ;;
      *)
        red "无效的选择。正在退出。"
        exit 1
        ;;
    esac
fi

# --- 全新安装流程 ---
show_notice "开始全新安装 sing-box..."

if ! apply_certificate; then
    red "证书申请失败，无法继续安装。"
    exit 1
fi

mkdir -p "/root/sbox/"

download_singbox

# vmess ws
yellow "开始配置 Vmess (WS+TLS)"
echo ""
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "请输入 Vmess 端口 (默认 2053): " vmess_port_input
    vmess_port=${vmess_port_input:-2053}
    if sudo lsof -i:"$vmess_port" -t >/dev/null; then
        echo "端口 $vmess_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
default_ws_path="/$(/root/sbox/sing-box generate rand --hex 8)" # 生成随机路径，以 / 开头
read -p "请输入 Vmess WS 路径 (无需加斜杠, 默认随机生成如 ${default_ws_path}): " ws_path_input
ws_path=${ws_path_input:-${default_ws_path#/}} # 移除开头的 / 如果用户输入了
ws_path="/${ws_path#/}" # 确保路径以 / 开头

# hysteria2
green "开始配置 Hysteria2"
echo ""
hy_password=$(/root/sbox/sing-box generate rand --base64 12) # 生成12位随机密码
echo "Hysteria2 密码已自动生成: $hy_password"
echo ""
while true; do
    read -p "请输入 Hysteria2 监听端口 (UDP, 默认 8433): " hy_port_input
    hy_port=${hy_port_input:-8433}
    if sudo lsof -i:udp:"$hy_port" -t >/dev/null; then # 检查UDP端口
        echo "UDP 端口 $hy_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

# ShadowTLS
yellow "开始配置 ShadowTLS (SS + shadow-tls v3)"
echo ""
tls_password=$(/root/sbox/sing-box generate rand --base64 16)
echo "ShadowTLS 密码已自动生成: $tls_password"
echo ""
while true; do
    read -p "请输入 ShadowTLS 监听端口 (TCP, 默认 9433): " tls_port_input
    tls_port=${tls_port_input:-9433}
    if sudo lsof -i:tcp:"$tls_port" -t >/dev/null; then # 检查TCP端口
        echo "TCP 端口 $tls_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

# 获取IP地址
server_ip=$(curl -s4m8 ip.sb -k || curl -s6m8 ip.sb -k || hostname -I | awk '{print $1}')
if [ -z "$server_ip" ]; then
    red "无法自动获取服务器IP地址。"
    read -p "请手动输入服务器公网IP地址: " server_ip
    if [ -z "$server_ip" ]; then
        red "未提供IP地址，安装中止。"
        exit 1
    fi
fi
echo "服务器IP地址: $server_ip"


#config配置文件
cat > /root/sbox/config <<EOF
# Server IP
SERVER_IP='$server_ip'
# Domain
DOMAIN='$(cat /root/domain.txt)'

# Hysteria2
HY_PORT='$hy_port'
HY_PASSWORD='$hy_password'
HY_HOPPING='FALSE' # 端口跳跃默认关闭

# Vmess (WS+TLS)
VMESS_PORT='$vmess_port'
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'

# ShadowTLS (SS + shadow-tls v3)
TLS_PORT='$tls_port'
TLS_PASSWORD='$tls_password'
EOF

current_domain_for_json=$(cat /root/domain.txt)
# sbox配置文件
cat > /root/sbox/sbconfig_server.json << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      { "tag": "dns_proxy", "address": "https://1.1.1.1/dns-query", "detour": "direct" },
      { "tag": "dns_direct", "address": "local" },
      { "tag": "dns_block", "address": "rcode://success" }
    ],
    "rules": [
      { "rule_set": "geosite-category-ads-all", "server": "dns_block" },
      { "outbound": "any", "server": "dns_proxy" }
    ],
    "strategy": "prefer_ipv4",
    "independent_cache": true
  },
  "inbounds": [
    {
        "type": "hysteria2",
        "tag": "hy2-in",
        "listen": "::",
        "listen_port": $hy_port,
        "users": [ { "password": "$hy_password" } ],
        "tls": {
            "enabled": true,
            "alpn": ["h3"],
            "certificate_path": "/root/cert.crt",
            "key_path": "/root/private.key",
            "server_name": "$current_domain_for_json"
        },
        "masquerade": "https://bing.com" // Example masquerade
    },
    {
      "type": "shadowtls",
      "tag": "shadowtls-in",
      "listen": "::",
      "listen_port": $tls_port,
      "version": 3,
      "users": [ { "password": "$tls_password" } ],
      "handshake": { "server": "www.samsung.com", "server_port": 443 },
      "strict_mode": true,
      "detour": "ss-in" // Detour to internal shadowsocks inbound
    },
    {
      "type": "shadowsocks", // Internal inbound for ShadowTLS
      "tag": "ss-in",
      "listen": "127.0.0.1", // Listen only locally
      "listen_port": 65330, // Arbitrary local port, ensure it's not used
      "method": "2022-blake3-aes-128-gcm",
      "password": "$tls_password",
      "multiplex": { "enabled": true, "padding": true }
    },
    {
        "type": "vmess",
        "tag": "vmess-ws-in",
        "listen": "::",
        "listen_port": $vmess_port,
        "users": [ { "uuid": "$vmess_uuid", "alterId": 0 } ],
        "transport": {
            "type": "ws",
            "path": "$ws_path",
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        },
        "tls":{
            "enabled": true,
            "server_name": "$current_domain_for_json",
            "certificate_path": "/root/cert.crt",
            "key_path": "/root/private.key"
        },
        "sniff": true,
        "sniff_override_destination": false
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }, // direct is a built-in action, but can be defined for clarity or specific settings
    { "type": "block", "tag": "block" },   // block is a built-in action
    { "type": "dns", "tag": "dns-out" },   // dns is a built-in action
    {
      "type": "wireguard",
      "tag": "warp-out", // Example WARP outbound, replace with your actual config if used
      "local_address": ["172.16.0.2/32", "2606:4700:110:xxxx:xxxx:xxxx:xxxx:xxxx/128"],
      "private_key": "YOUR_WARP_PRIVATE_KEY_HERE",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "mtu": 1280,
      "reserved": [0,0,0]
    }
  ],
  "route": {
    "rules": [
      { "protocol": "dns", "outbound": "dns-out" }, // Use the defined "dns-out" or simply "dns" action
      { "rule_set": ["geosite-openai","geosite-netflix"], "outbound": "direct" }, // Example: route specific sites directly or via WARP
      // { "rule_set": ["geosite-openai","geosite-netflix"], "outbound": "warp-out" }, // If you want to use WARP for these
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": "geosite-category-ads-all", "outbound": "block" }
    ],
    "rule_set": [
      { "tag": "geosite-openai", "type": "remote", "format": "binary", "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/openai.srs", "download_detour": "direct"},
      { "tag": "geosite-netflix", "type": "remote", "format": "binary", "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/netflix.srs", "download_detour": "direct"},
      { "tag": "geosite-category-ads-all", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs", "download_detour": "direct"}
    ],
    "final": "direct", // Default outbound action
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": { "enabled": true, "path": "cache.db", "store_fakeip": true },
    "clash_api": { "external_controller": "0.0.0.0:9090", "secret": "" } // Optional Clash API
  }
}
EOF

# Create sing-box.service
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root/sbox
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sbox/sing-box run -D /root/sbox -C /root/sbox/sbconfig_server.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity
# Environment="ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS=true" # Only if absolutely needed for very old configs

[Install]
WantedBy=multi-user.target
EOF


# Check configuration and start the service
if /root/sbox/sing-box check -C /root/sbox -c /root/sbox/sbconfig_server.json; then
    echo "配置文件检查成功。正在启动 sing-box 服务..."
    sudo systemctl daemon-reload
    sudo systemctl enable sing-box > /dev/null 2>&1
    sudo systemctl restart sing-box # Use restart to ensure it starts fresh
    
    if sudo systemctl is-active --quiet sing-box; then
        green "sing-box 服务已成功启动并运行。"
    else
        red "sing-box 服务启动失败。请检查日志: sudo journalctl -u sing-box -n 50 --no-pager"
        exit 1
    fi
    
    create_shortcut
    show_client_configuration
    echo ""
    yellow "安装完成！你可以使用 'sing' 命令来管理 sing-box。"
else
    red "配置文件检查失败。请检查 /root/sbox/sbconfig_server.json 中的错误。"
    red "安装中止。"
    exit 1
fi

