#!/usr/bin/env bash

# 当前脚本版本号
VERSION='v1.0'

# 各变量默认值
# GH_PROXY='https://ghproxy.com/' # 不稳定，暂不使用
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
START_PORT_DEFAULT=$((RANDOM % 19001 + 3000))
MIN_PORT=1000
MAX_PORT=65525
TLS_SERVER=addons.mozilla.org
PROTOCAL_LIST=("reality" "hysteria2" "tuic" "vless+ws+tls" )
CONSECUTIVE_PORTS=${#PROTOCAL_LIST[@]}

trap "rm -rf $TEMP_DIR >/dev/null 2>&1 ; echo -e '\n' ;exit 1" INT QUIT TERM EXIT

mkdir -p $TEMP_DIR

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="1. Sing-box Family bucket v1.0; 2. After installing, add [ sb ] shortcut."
C[1]="1. Sing-box 全家桶 v1.0; 2. 安装后，增加 [ sb ] 的快捷运行方式"
E[2]="This project is designed to add sing-box support for multiple protocols to VPS, details: \n Script Features:\n\t • Deploy multiple protocols with one click, there is always one for you!\n\t • Custom ports for nat machine with limited open ports.\n\t • Built-in warp chained proxy to unlock chatGPT.\n\t • No domain name is required.\n\t • Support system: Ubuntu, Debian, CentOS, Alpine and Arch Linux 3.\n\t • Support architecture: AMD,ARM and s390x\n"
C[2]="本项目专为 VPS 添加 sing-box 支持的多种协议, 详细说明: \n 脚本特点:\n\t • 一键部署多协议，总有一款适合你\n\t • 自定义端口，适合有限开放端口的 nat 小鸡\n\t • 内置 warp 链式代理解锁 chatGPT\n\t • 不需要域名\n\t • 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统\n\t • 支持硬件结构类型: AMD 和 ARM\n"
E[5]="The script supports Debian, Ubuntu, CentOS, Alpine, Fedora or Arch systems only. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[5]="本脚本只支持 Debian、Ubuntu、CentOS、Alpine、Fedora 或 Arch 系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[6]="Curren operating system is \$SYS.\\\n The system lower than \$SYSTEM \${MAJOR[int]} is not supported. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[6]="当前操作是 \$SYS\\\n 不支持 \$SYSTEM \${MAJOR[int]} 以下系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[7]="Install dependence-list:"
C[7]="安装依赖列表:"
E[8]="All dependencies already exist and do not need to be installed additionally."
C[8]="所有依赖已存在，不需要额外安装"
E[9]="To upgrade, press [y]. No upgrade by default:"
C[9]="升级请按 [y]，默认不升级:"
E[10]="Please enter VPS IP \(Default is: \${SERVER_IP_DEFAULT}\):"
C[10]="请输入 VPS IP \(默认为: \${SERVER_IP_DEFAULT}\):"
E[11]="Please enter the starting port number. Must be \${MIN_PORT} - \${MAX_PORT}, consecutive \${NUM} free ports are required \(Default is: \${START_PORT_DEFAULT}\):"
C[11]="请输入开始的端口号，必须是 \${MIN_PORT} - \${MAX_PORT}，需要连续\${NUM}个空闲的端口 \(默认为: \${START_PORT_DEFAULT}\):"
E[15]="Sing-box script has not been installed yet."
C[15]="Sing-box 脚本还没有安装"
E[16]="Sing-box is completely uninstalled."
C[16]="Sing-box 已彻底卸载"
E[17]="Version"
C[17]="脚本版本"
E[18]="New features"
C[18]="功能新增"
E[19]="System infomation"
C[19]="系统信息"
E[20]="Operating System"
C[20]="当前操作系统"
E[21]="Kernel"
C[21]="内核"
E[22]="Architecture"
C[22]="处理器架构"
E[23]="Virtualization"
C[23]="虚拟化"
E[24]="Choose:"
C[24]="请选择:"
E[26]="Not install"
C[26]="未安装"
E[27]="close"
C[27]="关闭"
E[28]="open"
C[28]="开启"
E[29]="View links (sb -n)"
C[29]="查看节点信息 (sb -n)"
E[30]="Change listen ports (sb -p)"
C[30]="更换监听端口 (sb -p)"
E[31]="Sync Sing-box to the latest version (sb -v)"
C[31]="同步 Sing-box 至最新版本 (sb -v)"
E[32]="Upgrade kernel, turn on BBR (sb -b)"
C[32]="升级内核、安装BBR (sb -b)"
E[33]="Uninstall (sb -u)"
C[33]="卸载 (sb -u)"
E[34]="Install script"
C[34]="安装脚本"
E[35]="Exit"
C[35]="退出"
E[36]="Please enter the correct number"
C[36]="请输入正确数字"
E[37]="successful"
C[37]="成功"
E[38]="failed"
C[38]="失败"
E[39]="Sing-box is not installed."
C[39]="Sing-box 未安装"
E[40]="Sing-box local verion: \$LOCAL.\\\t The newest verion: \$ONLINE"
C[40]="Sing-box 本地版本: \$LOCAL.\\\t 最新版本: \$ONLINE"
E[41]="No upgrade required."
C[41]="不需要升级"
E[42]="Downloading the latest version Sing-box failed, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[42]="下载最新版本 Sing-box 失败，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[44]="Ports are in used:  \${IN_USED[*]}"
C[44]="正在使用中的端口: \${IN_USED[*]}"
E[45]="Ports used: \${NOW_START_PORT} - \$((NOW_START_PORT+NOW_CONSECUTIVE_PORTS-1))"
C[45]="使用端口: \${NOW_START_PORT} - \$((NOW_START_PORT+NOW_CONSECUTIVE_PORTS-1))"
E[46]="Warp / warp-go was detected to be running. Please enter the correct server IP:"
C[46]="检测到 warp / warp-go 正在运行，请输入确认的服务器 IP:"
E[54]="The contents of the \$V2RAYN_PROTOCAL configuration file need to be updated for the \$V2RAYN_KERNEL kernel."
C[54]="\$V2RAYN_PROTOCAL 配置文件内容，需要更新 \$V2RAYN_KERNEL 内核"
E[56]="Process ID"
C[56]="进程ID"
E[57]="Runtime"
C[57]="运行时长"
E[58]="Memory Usage"
C[58]="内存占用"
E[60]="The order of the selected protocols and ports is as follows:"
C[60]="选择的协议及端口次序如下:"
E[61]="(DNS your own domain in Cloudflare is required.)"
C[61]="(必须在 Cloudflare 解析自有域名)"
E[64]="Please select the protocols to be removed (multiple selections possible):"
C[64]="请选择需要删除的协议（可以多选）:"
E[66]="Please select the protocols to be added (multiple choices possible):"
C[66]="请选择需要增加的协议（可以多选）:"
E[68]="Press [n] if there is an error, other keys to continue:"
C[68]="如有错误请按 [n]，其他键继续:"
E[70]="Please set inSecure in tls to true."
C[70]="请把 tls 里的 inSecure 设置为 true"
E[71]="Create shortcut [ sb ] successfully."
C[71]="创建快捷 [ sb ] 指令成功!"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }
text() { grep -q '\$' <<< "${E[$*]}" && eval echo "\$(eval echo "\${${L}[$*]}")" || eval echo "\${${L}[$*]}"; }

# 选择中英语言
select_language() {
  if [ -z "$L" ]; then
    case $(cat $WORK_DIR/language 2>&1) in
      E ) L=E ;;
      C ) L=C ;;
      * ) [ -z "$L" ] && L=C ;;
    esac
  fi
}

# 字母与数字的 ASCII 码值转换
asc(){
  if [[ "$1" = [a-z] ]]; then
    [ "$2" = '++' ] && printf "\\$(printf '%03o' "$[ $(printf "%d" "'$1'") + 1 ]")" || printf "%d" "'$1'"
  else
    [[ "$1" =~ ^[0-9]+$ ]] && printf "\\$(printf '%03o' "$1")"
  fi
}

check_root() {
  [ "$(id -u)" != 0 ] && error "\n 必须以root方式运行脚本，可以输入 sudo -i 后重新下载运行 \n"
}

check_arch() {
  # 判断处理器架构
  case $(uname -m) in
    aarch64|arm64 ) SING_BOX_ARCH=arm64 ;;
    x86_64|amd64 ) [[ "$(awk -F ':' '/flags/{print $2; exit}' /proc/cpuinfo)" =~ avx2 ]] && SING_BOX_ARCH=amd64v3 || SING_BOX_ARCH=amd64 ;;
    armv7l ) SING_BOX_ARCH=armv7 ;;
    * ) error " 当前架构 \$(uname -m) 暂不支持 "
  esac
}

# 查安装及运行状态；状态码: 26 未安装， 27 已安装未运行， 28 运行中
check_install() {
  STATUS=$(text 26) && [ -s /etc/systemd/system/sing-box.service ] && STATUS=$(text 27) && [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS=$(text 28)
  if [[ $STATUS = "$(text 26)" ]] && [ ! -s $WORK_DIR/sing-box ]; then
    {
    local ONLINE=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | sed "s@.*\"v\(.*\)\",@\1@g")
    ONLINE=${ONLINE:-'1.6.0'}
    wget -c ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box
    [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ] && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $TEMP_DIR
    }&
  fi
}


# 检查qrencode并安装
if ! command -v qrencode &> /dev/null; then
    sudo apt-get install -y qrencode &> /dev/null
fi

# 为了适配 alpine，定义 cmd_systemctl 的函数
cmd_systemctl() {
  local ENABLE_DISABLE=$1
  local APP=$2
  if [ "$ENABLE_DISABLE" = 'enable' ]; then
    if [ "$SYSTEM" = 'Alpine' ]; then
      systemctl start $APP
      cat > /etc/local.d/$APP.start << EOF
#!/usr/bin/env bash

systemctl start $APP
EOF
      chmod +x /etc/local.d/$APP.start
      rc-update add local >/dev/null 2>&1
    else
      systemctl enable --now $APP
    fi

  elif [ "$ENABLE_DISABLE" = 'disable' ]; then
    if [ "$SYSTEM" = 'Alpine' ]; then
      systemctl stop $APP
      rm -f /etc/local.d/$APP.start
    else
      systemctl disable --now $APP
    fi
  fi
}


# 检测 sing-box 的状态
check_sing-box_stats(){
  case "$STATUS" in
    "$(text 26)" )
      error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 27)" )
      cmd_systemctl enable sing-box && info "\n Sing-box $(text 28) $(text 37) \n" || error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 28)" )
      info "\n Sing-box $(text 28) $(text 37) \n"
  esac
}

check_system_info() {
  # 判断虚拟化
  if [ $(type -p systemd-detect-virt) ]; then
    VIRT=$(systemd-detect-virt)
  elif [ $(type -p hostnamectl) ]; then
    VIRT=$(hostnamectl | awk '/Virtualization/{print $NF}')
  elif [ $(type -p virt-what) ]; then
    VIRT=$(virt-what)
  fi

  [ -s /etc/os-release ] && SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
  [[ -z "$SYS" && $(type -p hostnamectl) ]] && SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
  [[ -z "$SYS" && $(type -p lsb_release) ]] && SYS="$(lsb_release -sd)"
  [[ -z "$SYS" && -s /etc/lsb-release ]] && SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
  [[ -z "$SYS" && -s /etc/redhat-release ]] && SYS="$(grep . /etc/redhat-release)"
  [[ -z "$SYS" && -s /etc/issue ]] && SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "amazon linux" "arch linux" "alpine" "fedora")
  RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Arch" "Alpine" "Fedora")
  EXCLUDE=("")
  MAJOR=("9" "16" "7" "7" "3" "" "37")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "pacman -Sy" "apk update -f" "dnf -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "pacman -S --noconfirm" "apk add --no-cache" "dnf -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "pacman -Rcnsu --noconfirm" "apk del -f" "dnf -y autoremove")

  for int in "${!REGEX[@]}"; do [[ $(tr 'A-Z' 'a-z' <<< "$SYS") =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break; done
  [ -z "$SYSTEM" ] && error " $(text 5) "

  # 先排除 EXCLUDE 里包括的特定系统，其他系统需要作大发行版本的比较
  for ex in "${EXCLUDE[@]}"; do [[ ! $(tr 'A-Z' 'a-z' <<< "$SYS")  =~ $ex ]]; done &&
  [[ "$(echo "$SYS" | sed "s/[^0-9.]//g" | cut -d. -f1)" -lt "${MAJOR[int]}" ]] && error " $(text 6) "
}

# 检测 IPv4 IPv6 信息
check_system_ip() {
  IP4=$(wget -4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=1 http://ip-api.com/json/) &&
  WAN4=$(expr "$IP4" : '.*query\":[ ]*\"\([^"]*\).*') &&
  COUNTRY4=$(expr "$IP4" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG4=$(expr "$IP4" : '.*isp\":[ ]*\"\([^"]*\).*') 

  IP6=$(wget -6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=1 https://api.ip.sb/geoip) &&
  WAN6=$(expr "$IP6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
  COUNTRY6=$(expr "$IP6" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG6=$(expr "$IP6" : '.*isp\":[ ]*\"\([^"]*\).*') 
}

# 输入起始 port 函数
enter_start_port() {
  local NUM=$1
  local PORT_ERROR_TIME=6
  while true; do
    [ "$PORT_ERROR_TIME" -lt 6 ] && unset IN_USED START_PORT
    (( PORT_ERROR_TIME-- )) || true
    if [ "$PORT_ERROR_TIME" = 0 ]; then
      error "\n $(text 3) \n"
    else
      [ -z "$START_PORT" ] && reading "\n $(text 11) " START_PORT
    fi
    START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
    if [[ "$START_PORT" =~ ^[1-9][0-9]{3,4}$ && "$START_PORT" -ge "$MIN_PORT" && "$START_PORT" -le "$MAX_PORT" ]]; then
      for port in $(eval echo {$START_PORT..$[START_PORT+NUM-1]}); do
        if [ "$SYSTEM" = 'Alpine' ]; then
          netstat -an | awk '/:[0-9]+/{print $4}' | awk -F ":" '{print $NF}' | grep -q $port && IN_USED+=("$port")
        else
          lsof -i:$port >/dev/null 2>&1 && IN_USED+=("$port")
        fi
      done
      [ "${#IN_USED[*]}" -eq 0 ] && break || warning "\n $(text 44) \n"
    fi
  done
}

# 定义 Sing-box 变量
sing-box_variable() {
  if grep -qi 'cloudflare' <<< "$ASNORG4$ASNORG6"; then
    local a=6
    until [ -n "$SERVER_IP" ]; do
      ((a--)) || true
      [ "$a" = 0 ] && error "\n $(text 3) \n"
      reading "\n $(text 46) " SERVER_IP
    done
    if [[ "$SERVER_IP" =~ : ]]; then
      WARP_ENDPOINT=2606:4700:d0::a29f:c101
      DOMAIN_STRATEG=prefer_ipv6
    else
      WARP_ENDPOINT=162.159.193.10
      DOMAIN_STRATEG=prefer_ipv4
    fi
  elif [ -n "$WAN4" ]; then
    SERVER_IP_DEFAULT=$WAN4
    WARP_ENDPOINT=162.159.193.10
    DOMAIN_STRATEG=prefer_ipv4
  elif [ -n "$WAN6" ]; then
    SERVER_IP_DEFAULT=$WAN6
    WARP_ENDPOINT=2606:4700:d0::a29f:c101
    DOMAIN_STRATEG=prefer_ipv6
  fi

# 自动选择全部协议
MAX_CHOOSE_PROTOCALS=$(asc $[CONSECUTIVE_PORTS+96+1])
INSTALL_PROTOCALS=($(eval echo {b..$MAX_CHOOSE_PROTOCALS}))

# 显示选择协议及其次序，输入开始端口号
if [ -z "$START_PORT" ]; then
  hint "\n $(text 60) "
  for d in "${!INSTALL_PROTOCALS[@]}"; do
    hint " $[d+1]. ${PROTOCAL_LIST[$(($(asc ${INSTALL_PROTOCALS[d]}) - 98))]} "
  done
  enter_start_port ${#INSTALL_PROTOCALS[@]}
fi

# 如果已经有默认的服务器IP可用，那么使用默认的IP，如果服务器IP为空，那么提示用户输入
SERVER_IP=${SERVER_IP_DEFAULT}
[ -z "$SERVER_IP" ] && reading "\n $(text 10) " SERVER_IP
[ -z "$SERVER_IP" ] && error " $(text 47) "

# 生成默认的UUID并赋值给UUID变量
UUID_DEFAULT=$($TEMP_DIR/sing-box generate uuid)
UUID=${UUID_DEFAULT}

  # 输入节点名，以系统的 hostname 作为默认
  if [ -s /etc/hostname ]; then
    NODE_NAME_DEFAULT="$(cat /etc/hostname)"
  elif [ $(type -p hostname) ]; then
    NODE_NAME_DEFAULT="$(hostname)"
  else
    NODE_NAME_DEFAULT="Sing-Box"
  fi
}

check_dependencies() {
  # 如果是 Alpine，先升级 wget ，安装 systemctl-py 版
  if [ "$SYSTEM" = 'Alpine' ]; then
    CHECK_WGET=$(wget 2>&1 | head -n 1)
    grep -qi 'busybox' <<< "$CHECK_WGET" && ${PACKAGE_INSTALL[int]} wget >/dev/null 2>&1

    DEPS_CHECK=("bash" "python3" "rc-update" "openssl" "virt-what")
    DEPS_INSTALL=("bash" "python3" "openrc" "openssl" "virt-what")
    for g in "${!DEPS_CHECK[@]}"; do [ ! $(type -p ${DEPS_CHECK[g]}) ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]}); done
    if [ "${#DEPS[@]}" -ge 1 ]; then
      info "\n $(text 7) ${DEPS[@]} \n"
      ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
      ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
    fi

    [ ! $(type -p systemctl) ] && wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py -O /bin/systemctl && chmod a+x /bin/systemctl
  fi

  # 检测 Linux 系统的依赖，升级库并重新安装依赖
  unset DEPS_CHECK DEPS_INSTALL DEPS
  DEPS_CHECK=("wget" "systemctl" "ip" "unzip" "lsof" "bash" "openssl")
  DEPS_INSTALL=("wget" "systemctl" "iproute2" "unzip" "lsof" "bash" "openssl")
  for g in "${!DEPS_CHECK[@]}"; do [ ! $(type -p ${DEPS_CHECK[g]}) ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]}); done
  if [ "${#DEPS[@]}" -ge 1 ]; then
    info "\n $(text 7) ${DEPS[@]} \n"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
  else
    info "\n $(text 8) \n"
  fi
}

# 生成 sing-box 配置文件
sing-box_json() {
  local IS_CHANGE=$1
  mkdir -p $WORK_DIR/conf $WORK_DIR/logs

  # 生成 dns 配置
  [ "$IS_CHANGE" != 'change' ] && cat > $WORK_DIR/conf/00_log.json << EOF
{
    "log":{
        "disabled":false,
        "level":"error",
        "output":"$WORK_DIR/logs/box.log",
        "timestamp":true
    }
}
EOF
  # 生成 outbound 配置
  [ "$IS_CHANGE" != 'change' ] && cat > $WORK_DIR/conf/01_outbounds.json << EOF
{
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct",
            "domain_strategy":"$DOMAIN_STRATEG"
        },
        {
            "type":"direct",
            "tag":"warp-IPv4-out",
            "detour":"wireguard-out",
            "domain_strategy":"ipv4_only"
        },
        {
            "type":"direct",
            "tag":"warp-IPv6-out",
            "detour":"wireguard-out",
            "domain_strategy":"ipv6_only"
        },
        {
            "type":"wireguard",
            "tag":"wireguard-out",
            "server":"${WARP_ENDPOINT}",
            "server_port":2408,
            "local_address":[
                "172.16.0.2/32",
                "2606:4700:110:8a36:df92:102a:9602:fa18/128"
            ],
            "private_key":"YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
            "peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
            "reserved":[
                78,
                135,
                76
            ],
            "mtu":1280
        },
        {
            "type":"block",
            "tag":"block"
        }
    ]
}
EOF

  # 生成 route 配置
  [ "$IS_CHANGE" != 'change' ] && cat > $WORK_DIR/conf/02_route.json << EOF
{
    "route":{
        "geoip":{
            "download_url":"https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
            "download_detour":"direct"
        },
        "geosite":{
            "download_url":"https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
            "download_detour":"direct"
        },
        "rules":[
            {
                "geosite":[
                    "openai"
                ],
                "outbound":"warp-IPv6-out"
            }
        ]
    }
}
EOF

  # 第1个协议为 b  (a为全部)，生成 Reality 配置
  CHECK_PROTOCALS=b
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    [[ -z "$REALITY_PRIVATE" || -z "$REALITY_PUBLIC" ]] && REALITY_KEYPAIR=$($TEMP_DIR/sing-box generate reality-keypair)
    [ -z "$REALITY_PRIVATE" ] && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$REALITY_PUBLIC" ] && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$PORT_REALITY" ] && PORT_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")]
    cat > $WORK_DIR/conf/11_REALITY_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"reality-in",
            "listen":"::",
            "listen_port":$PORT_REALITY,
            "users":[
                {
                    "uuid":"$UUID",
                    "flow":"xtls-rprx-vision"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"$TLS_SERVER",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"$TLS_SERVER",
                        "server_port":443
                    },
                    "private_key":"$REALITY_PRIVATE",
                    "short_id":[
                        ""
                    ]
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Hysteria2 配置
  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    [ -z "$PORT_HYSTERIA2" ] && PORT_HYSTERIA2=$[START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")]
    cat > $WORK_DIR/conf/12_HYSTERIA2_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"hysteria2-in",
            "listen":"::",
            "listen_port":$PORT_HYSTERIA2,
            "users":[
                {
                    "password":"$UUID"
                }
            ],
            "ignore_client_bandwidth":false,
            "obfs":{
                "type":"salamander",
                "password":"$UUID"
            },
            "tls":{
                "enabled":true,
                "server_name":"",
                "alpn":[
                    "h3"
                ],
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"/root/cert.crt",
                "key_path":"/root/private.key"
            }
        }
    ]
}
EOF
  fi

  # 生成 Tuic V5 配置
  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    [ -z "$PORT_TUIC" ] && PORT_TUIC=$[START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")]
    cat > $WORK_DIR/conf/13_TUIC_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
            "sniff":true,
            "tag":"tuic-in",
            "sniff_override_destination":true,
            "listen":"::",
            "listen_port":$PORT_TUIC,
            "users":[
                {
                    "uuid":"$UUID",
                    "password":"$UUID"
                }
            ],
            "congestion_control":"bbr",
            "tls":{
                "enabled":true,
                "alpn":[
                    "h3"
                ],
                "certificate_path":"/root/cert.crt",
                "key_path":"/root/private.key"
            }
        }
    ]
}
EOF
  fi

 # 生成 vless + ws + tls 配置
  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    [ -z "$PORT_VLESS_WS" ] && PORT_VLESS_WS=$[START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")]
    cat > $WORK_DIR/conf/18_VLESS_WS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff_override_destination":true,
            "sniff":true,
            "tag":"vless-ws-in",
            "listen":"::",
            "listen_port":${PORT_VLESS_WS},
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "name":"sing-box",
                    "uuid":"${UUID}"
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/${UUID}-vless",
                "max_early_data":2048,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "tls":{
                "enabled":true,
                "server_name":"$(cat /root/domain.txt)",
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"/root/cert.crt",
                "key_path":"/root/private.key"
            }
        }
    ]
}
EOF
  fi

}

# Sing-box 生成守护进程文件
sing-box_systemd() {
  cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=$WORK_DIR
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=$WORK_DIR/sing-box run -C $WORK_DIR/conf/
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
}

install_sing-box() {
  sing-box_variable
  [ ! -d /etc/systemd/system ] && mkdir -p /etc/systemd/system
  [ ! -d $WORK_DIR/logs ] && mkdir -p $WORK_DIR/logs
  ssl_certificate
  sing-box_json
  echo "$L" > $WORK_DIR/language
  cp $TEMP_DIR/sing-box $WORK_DIR
  sing-box_systemd

  # 如果 Alpine 系统，放到开机自启动
  if [ "$SYSTEM" = 'Alpine' ]; then
    cat > /etc/local.d/sing-box.start << EOF
#!/usr/bin/env bash

systemctl start sing-box
EOF
    chmod +x /etc/local.d/sing-box.start
    rc-update add local >/dev/null 2>&1
  fi

  # 再次检测状态，运行 Sing-box
  check_install

  check_sing-box_stats
}

export_list() {
  check_install
  if [ -s $WORK_DIR/list ]; then
    SERVER_IP=${SERVER_IP:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n "s/.*{name.*server:[ ]*\([^,]\+\).*/\1/pg" | sed -n '1p')"}
    UUID=${UUID:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed -En 's/.*password:[ ]+[\"]*|.*uuid:[ ]+[\"]*(.*)/\1/gp' | sed "s/\([^,\"]\+\).*/\1/g")"}
    SHADOWTLS_PASSWORD=${SHADOWTLS_PASSWORD:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n 's/.*{name.*password:[ ]*\"\([^\"]\+\)".*shadow-tls.*/\1/pg')"}
    TLS_SERVER=${TLS_SERVER:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -Em1 '{name.*shadow-tls|{name.*public-key' | sed -n "s/.*servername:[ ]\+\([^\,]\+\).*/\1/gp; s/.*host:[ ]\+\"\([^\"]\+\).*/\1/gp")"}
    NODE_NAME=${NODE_NAME:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed 's/- {name:[ ]\+"//; s/[ ]\+ShadowTLS[ ]\+v3.*//; s/[ ]\+vless-reality-vision.*//; s/[ ]\+hysteria2.*//; s/[ ]\+tuic.*//; s/[ ]\+ss.*//; s/[ ]\+trojan.*//; s/[ ]\+trojan.*//; s/[ ]\+vmess[ ]\+ws.*//; s/[ ]\+vless[ ]\+.*//')"}
    REALITY_PUBLIC=${REALITY_PUBLIC:-"$(sed -n 's/.*{name.*public-key:[ ]*\([^,]\+\).*/\1/pg' $WORK_DIR/list)"}
    [ -s $WORK_DIR/conf/*_REALITY_inbounds.json ] && PORT_REALITY=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_REALITY_inbounds.json)
    [ -s $WORK_DIR/conf/*_HYSTERIA2_inbounds.json ] && PORT_HYSTERIA2=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_HYSTERIA2_inbounds.json)
    [ -s $WORK_DIR/conf/*_TUIC_inbounds.json ] && PORT_TUIC=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_TUIC_inbounds.json)
    [ -s $WORK_DIR/conf/*_VLESS_WS_inbounds.json ] && WS_SERVER_IP=${WS_SERVER_IP:-"$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}')"} && VLESS_HOST_DOMAIN=${VLESS_HOST_DOMAIN:-"$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}')"} && PORT_VLESS_WS=${PORT_VLESS_WS:-"$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_VLESS_WS_inbounds.json)"} && CDN=${CDN:-"$(sed -n "s/.*{name.*vless[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)"}
  fi

  # IPv6 时的 IP 处理
  if [[ "$SERVER_IP" =~ : ]]; then
    SERVER_IP_1="[$SERVER_IP]"
    SERVER_IP_2="[[$SERVER_IP]]"
  else
    SERVER_IP_1="$SERVER_IP"
    SERVER_IP_2="$SERVER_IP"
  fi

  # 生成配置文件
  cat >> $WORK_DIR/list << EOF
*******************************************
┌────────────────┐
│                │
│    $(warning "NekoBox")     │
│                │
└────────────────┘
EOF
# 生成 vless 链接和二维码
if [ -n "$PORT_REALITY" ]; then
  vless_link="vless://${UUID}@${SERVER_IP_1}:${PORT_REALITY}?security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&flow=xtls-rprx-vision&encryption=none#${NODE_NAME}%20vless-reality-vision"
  cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "$vless_link")
EOF

fi

# 生成 hy2 链接和二维码
if [ -n "$PORT_HYSTERIA2" ]; then
  hy2_link="hy2://${UUID}@${SERVER_IP_1}:${PORT_HYSTERIA2}?obfs=salamander&obfs-password=${UUID}&sni=$(cat /root/domain.txt)#${NODE_NAME}%20hysteria2"
  cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "$hy2_link")
EOF
  
fi

# 生成 tuic 链接和二维码
if [ -n "$PORT_TUIC" ]; then
  tuic_link="tuic://${UUID}:${UUID}@${SERVER_IP_1}:${PORT_TUIC}?congestion_control=bbr&alpn=h3&udp_relay_mode=native&allow_insecure=0&sni=$(cat /root/domain.txt)#${NODE_NAME}%20tuic"
  cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "$tuic_link")
EOF
 
fi

# 生成Vless链接和二维码

if [ -n "$PORT_VLESS_WS" ]; then

  vless_link="vless://${UUID}@$(cat /root/domain.txt):443?security=tls&sni=${cat /root/domain.txt}&type=ws&path=/${UUID}-vless?ed%3D2048&host=${cat /root/domain.txt}&encryption=none#${NODE_NAME}%20vless%20ws
  cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless_link")
EOF



  cat >> $WORK_DIR/list << EOF
*******************************************
EOF
  cat $WORK_DIR/list
  qrencode -t UTF8 "$vless_link"
  qrencode -t UTF8 "$hy2_link"
  qrencode -t UTF8 "$tuic_link"
  qrencode -t UTF8 "$vless_link"

}

# 创建快捷方式
create_shortcut() {
  cat > $WORK_DIR/sb.sh << EOF
#!/usr/bin/env bash

bash <(wget -qO- https://raw.githubusercontent.com/jplicn/script/master/singF.sh) \$1
EOF
  chmod +x $WORK_DIR/sb.sh
  ln -sf $WORK_DIR/sb.sh /usr/bin/sb
  [ -s /usr/bin/sb ] && info "\n $(text 71) "
}

# 卸载 Sing-box 全家桶
uninstall() {
  if [ -d $WORK_DIR ]; then
    [ "$SYSTEM" = 'Alpine' ] && systemctl stop sing-box 2>/dev/null || cmd_systemctl disable sing-box 2>/dev/null
    rm -rf $WORK_DIR $TEMP_DIR /etc/systemd/system/sing-box.service /usr/bin/sb
    info "\n $(text 16) \n"
  else
    error "\n $(text 15) \n"
  fi

  # 如果 Alpine 系统，删除开机自启动
  [ "$SYSTEM" = 'Alpine' ] && ( rm -f /etc/local.d/sing-box.start; rc-update add local >/dev/null 2>&1 )
}

# Sing-box 的最新版本
version() {
  local ONLINE=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | sed "s@.*\"v\(.*\)\",@\1@g")
  local LOCAL=$($WORK_DIR/sing-box version | awk '/version/{print $NF}')
  info "\n $(text 40) "
  [[ -n "$ONLINE" && "$ONLINE" != "$LOCAL" ]] && reading "\n $(text 9) " UPDATE || info " $(text 41) "

  if [[ "$UPDATE" = [Yy] ]]; then
    check_system_info
    wget -c ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box

    if [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ]; then
      systemctl stop sing-box
      chmod +x $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $WORK_DIR/sing-box
      systemctl start sing-box && sleep 2 && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error "Sing-box $(text 28) $(text 38) "
    else
      local error "\n $(text 42) "
    fi
  fi
}

# 判断当前 Sing-box 的运行状态，并对应的给菜单和动作赋值
menu_setting() {
  OPTION[0]="0.  $(text 35)"
  ACTION[0]() { exit; }

  if [[ "$STATUS" =~ $(text 27)|$(text 28) ]]; then
    # 查进程号，sing-box 运行时长 和 内存占用
    if [ "$STATUS" = "$(text 28)" ]; then
      if [ "$SYSTEM" = 'Alpine' ]; then
        PS=$(ps -ef | grep -nm1 "$WORK_DIR/conf/")
        PS_ROW=$(awk -F ':' 'NR==1 {print $1}' <<< "$PS")
        PID=$(sed "s/[0-9]\+:[ ]*\([0-9]\+\) .*/\1/" <<< "$PS")
        RUNTIME=$(ps -o etime | sed -n ${PS_ROW}p)
      else
        SYSTEMCTL_STATUS=$(systemctl status sing-box)
        PID=$(awk '/PID/{print $3}' <<< "$SYSTEMCTL_STATUS")
        RUNTIME=$(awk '/Active:/{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}' <<< "$SYSTEMCTL_STATUS")
      fi
      MEMORY_USAGE="$(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$PID/status)"
    fi
    NOW_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*)
    NOW_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$NOW_PORTS")
    NOW_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$NOW_PORTS")
    [ -s $WORK_DIR/sing-box ] && SING_BOX_VERSION="version: $($WORK_DIR/sing-box version | awk '/version/{print $NF}')"
    [ -s $WORK_DIR/conf/02_route.json ] && { grep -q 'direct' $WORK_DIR/conf/02_route.json && RETURN_STATUS=$(text 27) || RETURN_STATUS=$(text 28); }
    OPTION[1]="1.  $(text 29)"
    [ "$STATUS" = "$(text 28)" ] && OPTION[2]="2.  $(text 27) Sing-box (sb -o)" || OPTION[2]="2.  $(text 28) Sing-box (sb -o)"
    OPTION[3]="3.  $(text 30)"
    OPTION[4]="4.  $(text 31)"
    OPTION[5]="5.  $(text 32)"
    OPTION[6]="6.  $(text 33)"

    ACTION[1]() { export_list; exit 0; }
    [ "$STATUS" = "$(text 28)" ] && ACTION[2]() { cmd_systemctl disable sing-box; [ "$(systemctl is-active sing-box)" = 'inactive' ] && info " Sing-box $(text 27) $(text 37)" || error " Sing-box $(text 27) $(text 38) "; } || ACTION[2]() { cmd_systemctl enable sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "; }
    ACTION[3]() { change_start_port; exit; }
    ACTION[4]() { version; exit; }
    ACTION[5]() { bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh); exit; }
    ACTION[6]() { uninstall; exit; }

  else
    OPTION[1]="1.  $(text 34)"
    OPTION[2]="2.  $(text 32)"
    OPTION[3]="3.  安装acme脚本"

    ACTION[1]() { install_sing-box; export_list; create_shortcut; exit; }
    ACTION[2]() { bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh); exit; }
    ACTION[3]() { bash <(wget -qO- https://raw.githubusercontent.com/jplicn/script/master/acme.sh); exit; }
  fi
}

menu() {
  clear
  hint " $(text 2) "
  echo -e "======================================================================================================================\n"
  info " $(text 17): $VERSION\n $(text 18): $(text 1)\n $(text 19):\n\t $(text 20): $SYS\n\t $(text 21): $(uname -r)\n\t $(text 22): $SING_BOX_ARCH\n\t $(text 23): $VIRT "
  info "\t IPv4: $WAN4 $WARPSTATUS4 $COUNTRY4  $ASNORG4 "
  info "\t IPv6: $WAN6 $WARPSTATUS6 $COUNTRY6  $ASNORG6 "
  info "\t Sing-box: $STATUS\t $SING_BOX_VERSION "
  net_congestion_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
  info "\t 当前拥塞控制算法: $net_congestion_control"
  [ -n "$PID" ] && info "\t $(text 56): $PID "
  [ -n "$RUNTIME" ] && info "\t $(text 57): $RUNTIME "
  [ -n "$MEMORY_USAGE" ] && info "\t $(text 58): $MEMORY_USAGE MB"
  [ -n "$NOW_START_PORT" ] && info "\t $(text 45) "
  echo -e "\n======================================================================================================================\n"
  for ((b=1;b<${#OPTION[*]};b++)); do hint " ${OPTION[b]} "; done
  hint " ${OPTION[0]} "
  reading "\n $(text 24) " CHOOSE

  # 输入必须是数字且少于等于最大可选项
  if grep -qE "^[0-9]$" <<< "$CHOOSE" && [ "$CHOOSE" -lt "${#OPTION[*]}" ]; then
    ACTION[$CHOOSE]
  else
    warning " $(text 36) [0-$((${#OPTION[*]}-1))] " && sleep 1 && menu
  fi
}

select_language
check_root
check_arch
check_system_info
check_dependencies
check_system_ip
check_install
menu_setting
menu
