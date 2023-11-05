#!/bin/bash

# Function: Print text with a delay between each character
print_with_delay() {
    local text="$1"
    local delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

# Function: Print text in red color
red() {
    echo -e "\033[31m\033[01m$*\033[0m"
}

# Function: Print text in green color
green() {
    echo -e "\033[32m\033[01m$*\033[0m"
}

# Function: Print text in yellow color
yellow() {
    echo -e "\033[33m\033[01m$*\033[0m"
}

# Function: Display a formatted notice message
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

# Function: Install required dependencies
install_base() {
    local packages=("qrencode")
    for package in "${packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            echo "Installing $package..."
            if [ -n "$(command -v apt)" ]; then
                sudo apt update > /dev/null 2>&1
                sudo apt install -y "$package" > /dev/null 2>&1
            elif [ -n "$(command -v yum)" ]; then
                sudo yum install -y "$package"
            elif [ -n "$(command -v dnf)" ]; then
                sudo dnf install -y "$package"
            else
                echo "Unable to install $package. Please install it manually and run the script again."
                exit 1
            fi
            echo "$package has been installed."
        else
            echo "$package is already installed."
        fi
    done
}

# Function: Download Sing-Box and set it up
download_singbox() {
    local arch=$(uname -m)
    echo "Architecture: $arch"

    # Map architecture names
    case $arch in
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

    # Fetch the latest release version number from GitHub API
    local latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | sort -V | tail -n 1)
    local latest_version=${latest_version_tag#v}  # Remove 'v' prefix from version number
    echo "Latest version: $latest_version"

    # Prepare package names and download URL
    local package_name="sing-box-${latest_version}-linux-${arch}"
    local url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"

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

# Function: Download Cloudflared and set it up
download_cloudflared() {
    local arch=$(uname -m)

    # Map architecture names
    case $arch in
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

    # Download Cloudflared for Linux
    local cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}"
    curl -sLo "/root/sbox/cloudflared-linux" "$cf_url"
    chmod +x /root/sbox/cloudflared-linux
    echo ""
}

# Function: Display client configuration details
show_client_configuration() {
    # Get server IP
    local server_ip=$(grep -o "SERVER_IP='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')

    # Display Reality configuration
    local reality_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local reality_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local reality_uuid=$(grep -o "REALITY_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local public_key=$(grep -o "PUBLIC_KEY='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local short_id=$(grep -o "SHORT_ID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local reality_link="vless://$reality_uuid@$server_ip:$reality_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-REALITY"

    echo ""
    echo ""
    show_notice "$(red "Reality Configuration")"
    echo ""
    echo ""
    red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$reality_link"
    echo ""
    red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""

    # Display Hysteria2 configuration
    local hy_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local hy_server_name=$(grep -o "HY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local hy_password=$(grep -o "HY_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local hy2_link="hysteria2://$hy_password@$server_ip:$hy_port?insecure=1&sni=$hy_server_name"

    echo ""
    echo ""
    show_notice "$(green "Hysteria2 Configuration")"
    echo ""
    echo ""
    green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$hy2_link"
    echo ""
    green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""

    # Display Vmess configuration
    local vmess_uuid=$(grep -o "VMESS_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local ws_path=$(grep -o "WS_PATH='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    local vmesswss_link='vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$server_ip'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}?ed=2048'","port":"443","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
    local vmessws_link='vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$server_ip'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}?ed=2048'","port":"80","ps":"sing-box-vmess","tls":"","type":"none","v":"2"}' | base64 -w 0)

    echo ""
    echo ""
    show_notice "$(yellow "Vmess Configuration")"
    echo ""
    echo ""
    yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$vmesswss_link"
    echo ""
    yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$vmessws_link"
    echo ""
    yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
}

# Function: Enable BBR congestion control algorithm
enable_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}

# Function: Modify Sing-Box server configuration
modify_singbox() {
    # Modify Reality configuration
    show_notice "Modifying Reality Configuration"
    echo ""
    local reality_current_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "Enter the new port number (current port: $reality_current_port): " reality_port
        reality_port=${reality_port:-$reality_current_port}
        if [ "$reality_port" -eq "$reality_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$reality_port\b"; then
            echo "Port $reality_port is already in use. Please choose a different port."
        else
            break
        fi
    done
    echo ""
    local reality_current_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    read -p "Enter the domain name to steal (current domain: $reality_current_server_name): " reality_server_name
    reality_server_name=${reality_server_name:-$reality_current_server_name}
    echo ""

    # Modify Hysteria2 configuration
    show_notice "Modifying Hysteria2 Configuration"
    echo ""
    local hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "Enter the new port number (current port: $hy_current_port): " hy_port
        hy_port=${hy_port:-$hy_current_port}
        if [ "$hy_port" -eq "$hy_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$hy_port\b"; then
            echo "Port $hy_port is already in use. Please choose a different port."
        else
            break
        fi
    done
    echo ""

    # Update Sing-Box configuration
    sed -i "s/REALITY_PORT='[^']*'/REALITY_PORT='$reality_port'/" /root/sbox/config
    sed -i "s/REALITY_SERVER_NAME='[^']*'/REALITY_SERVER_NAME='$reality_server_name'/" /root/sbox/config
    sed -i "s/HY_PORT='[^']*'/HY_PORT='$hy_port'/" /root/sbox/config

    # Restart Sing-Box service
    systemctl restart sing-box
}

# Function: Uninstall Sing-Box server
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

    echo "Uninstallation completed."
}

# Install required dependencies
install_base

# Check if Sing-Box is already installed
if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/root/sbox/cloudflared-linux" ] && [ -f "/root/sbox/sing-box" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then
    echo "Sing-Box is already installed."
    echo ""
    echo "Please choose an option:"
    echo ""
    echo "1. Reinstall Sing-Box"
    echo "2. Modify Configuration"
    echo "3. Display Client Configuration"
    echo "4. Uninstall Sing-Box"
    echo "5. Update Sing-Box Kernel"
    echo "6. Manually Restart Cloudflared"
    echo "7. Enable BBR Congestion Control"
    echo "8. Restart Sing-Box"
    echo ""
    read -p "Enter your choice (1-8): " choice

    case $choice in
        1)
            show_notice "Starting reinstallation..."
            # Uninstall previous installation
            uninstall_singbox
            ;;
        2)
            # Modify Sing-Box configuration
            modify_singbox
            # Display client configuration
            show_client_configuration
            exit 0
            ;;
        3)
            # Display client configuration
            show_client_configuration
            exit 0
            ;;
        4)
            # Uninstall Sing-Box
            uninstall_singbox
            exit 0
            ;;
        5)
            show_notice "Updating Sing-Box..."
            download_singbox
            # Check configuration and start the service
            if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
                echo "Configuration checked successfully. Starting Sing-Box service..."
                systemctl restart sing-box
            fi
            echo ""
            exit 0
            ;;
        6)
            systemctl stop argo
            systemctl start argo
            echo "Restart completed. View the new client information."
            show_client_configuration
            exit 0
            ;;
        7)
            enable_bbr
            exit 0
            ;;
        8)
            systemctl restart sing-box
            echo "Restart completed."
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

# Create necessary directories
mkdir -p "/root/sbox/"

# Download Sing-Box and set it up
download_singbox

# Download Cloudflared and set it up
download_cloudflared

# Configure Reality
red "Configuring Reality"
echo ""
key_pair=$(/root/sbox/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
reality_uuid=$(/root/sbox/sing-box generate uuid)
short_id=$(/root/sbox/sing-box generate rand --hex 8)
echo "UUID and Short ID generated."
echo ""
while true; do
    read -p "Enter the Reality port number (default: 443): " reality_port
    reality_port=${reality_port:-443}
    if ss -tuln | grep -q ":$reality_port\b"; then
        echo "Port $reality_port is already in use. Please choose a different port."
    else
        break
    fi
done
echo ""
read -p "Enter the domain name to steal (default: itunes.apple.com): " reality_server_name
reality_server_name=${reality_server_name:-itunes.apple.com}
echo ""

# Configure Hysteria2
green "Configuring Hysteria2"
echo ""
hy_password=$(/root/sbox/sing-box generate rand --hex 8)
echo "Generated an 8-character random password."
echo ""
while true; do
    read -p "Enter the Hysteria2 listen port (default: 8443): " hy_port
    hy_port=${hy_port:-8443}
    if ss -tuln | grep -q ":$hy_port\b"; then
        echo "Port $hy_port is already in use. Please choose a different port."
    else
        break
    fi
done
echo ""
read -p "Enter the self-signed certificate domain (default: bing.com): " hy_server_name
hy_server_name=${hy_server_name:-bing.com}
mkdir -p /root/sbox/self-cert/ && openssl ecparam -genkey -name prime256v1 -out /root/sbox/self-cert/private.key && openssl req -new -x509 -days 36500 -key /root/sbox/self-cert/private.key -out /root/sbox/self-cert/cert.pem -subj "/CN=${hy_server_name}"
echo ""
echo "Self-signed certificate generated."
echo ""

# Configure Vmess
yellow "Configuring Vmess"
echo ""
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "Enter the Vmess port (default: 18443): " vmess_port
    vmess_port=${vmess_port:-18443}
    if ss -tuln | grep -q ":$vmess_port\b"; then
        echo "Port $vmess_port is already in use. Please choose a different port."
    else
        break
    fi
done
echo ""
read -p "Enter the WS path (without a slash, default: randomly generated): " ws_path
ws_path=${ws_path:-$(/root/sbox/sing-box generate rand --hex 6)}

# Get server IP
server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

# Create configuration file
cat > /root/sbox/config <<EOF
# Server IP
SERVER_IP='$server_ip'

# Sing-Box
# Reality
PRIVATE_KEY='$private_key'
PUBLIC_KEY='$public_key'
SHORT_ID='$short_id'
REALITY_UUID='$reality_uuid'
REALITY_PORT='$reality_port'
REALITY_SERVER_NAME='$reality_server_name'

# Hysteria2
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

# Create Sing-Box service file
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
    echo "Configuration checked successfully. Starting Sing-Box service..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box

    show_client_configuration
else
    echo "Error in configuration. Aborting."
fi
