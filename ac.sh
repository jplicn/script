#!/bin/bash

# 检查是否已安装acme.sh
if command -v acme.sh &>/dev/null; then
    echo "已检测到 acme.sh 已安装在系统中。"
    
    read -p "是否要卸载 acme.sh? (yes/no): " uninstall_choice
    if [[ $uninstall_choice == "yes" ]]; then
        echo "正在卸载 acme.sh..."
        /root/.acme.sh/acme.sh --uninstall
        rm -rf /root/.acme.sh
        rm -rf /root/server.key
        rm -rf /root/server.crt
        rm -rf /root/domain.txt
        echo "acme.sh 已成功卸载。"
        exit 0
    else
        echo "选择保留 acme.sh，继续执行脚本。"
    fi
fi

# 安装 acme.sh
echo "开始安装 acme.sh..."
curl https://get.acme.sh | sh
apt install socat

# 生成随机字符串作为邮箱用户名
random_string=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
random_email="$random_string@gmail.com"

echo "随机生成的邮箱地址为: $random_email"

# 提示用户输入域名
read -p "请输入解析后的域名: " domain

echo "$domain" > /root/domain.txt  # 将输入的域名写入文件
echo "已输入的域名：$domain" && sleep 1

# 提示用户选择证书机构
echo "请选择证书机构:"
echo "1. Let's Encrypt"
echo "2. Buypass"
echo "3. ZeroSSL"
read -p "请输入选项: " ca_choice

if [[ $ca_choice == "1" ]]; then
    ca="letsencrypt"
elif [[ $ca_choice == "2" ]]; then
    ca="buypass"
elif [[ $ca_choice == "3" ]]; then
    ca="zerossl"
else
    # 如果选择其他机构，提示用户输入机构名称
    read -p "请输入证书机构名称: " custom_ca
    ca="$custom_ca"
fi

# 注册账号并使用随机生成的邮箱
/root/.acme.sh/acme.sh --register-account -m "$random_email" --server "$ca"

# 开放 80 端口
ufw allow 80

/root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --server "$ca"

# 安装证书
/root/.acme.sh/acme.sh --installcert -d "$domain" --ecc --key-file /root/server.key --fullchain-file /root/server.crt
