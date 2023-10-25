#!/bin/bash

# 更新包索引
sudo apt-get update

# 安装必要的工具
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# 添加 Docker 的官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# 添加 Docker 的存储库到 APT 源
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# 再次更新包索引
sudo apt-get update

# 安装 Docker
sudo apt-get install -y docker-ce

# 验证 Docker 是否安装成功
sudo docker run hello-world

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 赋予 Docker Compose 可执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证 Docker Compose 是否安装成功
docker-compose --version
