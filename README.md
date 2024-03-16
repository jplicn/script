# script

## 使用前从private变为public

### Docker安装
````
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/docker_install.sh)"
````
### Singbox脚本
````
bash <(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/sing.sh)
````

### Hy2脚本
````
bash <(curl -fsSL https://raw.githubusercontent.com/jplicn/script/master/hy2.sh)
````

### 申请证书：
````
bash <(wget -qO- https://raw.githubusercontent.com/jplicn/script/master/ac.sh)
````


#### 其他细节：
  - 安装acme：curl https://get.acme.sh | sh
  - 安装socat：apt install socat
  - 添加软链接：ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
  - 注册账号： acme.sh --register-account -m my@example.com
  - 开放80端口：ufw allow 80
  - 申请证书： acme.sh  --issue -d 你的域名  --standalone -k ec-256
  - 安装证书： acme.sh --installcert -d 你的域名 --ecc  --key-file   /root/trojan/server.key   --fullchain-file /root/trojan/server.crt 
#### 如果默认CA无法颁发，则可以切换下列CA：
  - 切换 Let’s Encrypt：acme.sh --set-default-ca --server letsencrypt
  - 切换 Buypass：acme.sh --set-default-ca --server buypass
  - 切换 ZeroSSL：acme.sh --set-default-ca --server zerossl
#### 自签证书：
  - 生成私钥：openssl ecparam -genkey -name prime256v1 -out ca.key
  - 生成证书：openssl req -new -x509 -days 36500 -key ca.key -out ca.crt  -subj "/CN=bing.com"

### 解包（其中tuic.sh为举例）
````
wget https://gitlab.com/rwkgyg/tuic-yg/raw/main/tuic.sh
bash <(curl https://raw.githubusercontent.com/jplicn/script/master/unpack.sh) tuic.sh
````

### DD系统

dd.sh & dd22.sh, 指令在电报

### 其他测试
bash <(wget -qO- https://raw.githubusercontent.com/jplicn/script/master/test.sh)
