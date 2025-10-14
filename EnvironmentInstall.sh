#!/bin/bash

BAN_IPV6=0
INSTALL_JAVA=0
INSTALL_XANMOD=0
USER="deng-rui"

while getopts "bjx" opt; do
  case $opt in
    b) BAN_IPV6=1 ;;  # -b 表示禁用 IPv6
    j) INSTALL_JAVA=1 ;;  # -j 表示安装 Java
    x) INSTALL_XANMOD=1 ;;  # -x 表示安装 Xanmod LTS 内核
    ?) echo "无效参数。使用: $0 [-b] [-j] [-x]"; exit 1 ;;
  esac
done

echo "执行默认安装：wget, curl, screen, unzip, ca-certificates"
sudo apt update
sudo apt install wget curl screen unzip ca-certificates -y
sudo apt upgrade -y
sudo apt dist-upgrade -y

if [ $BAN_IPV6 -eq 1 ]; then
  echo "Ban V6"
  echo "# made for disabled IPv6 in $(date +%F)" >> /etc/sysctl.conf
  echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
  echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
  echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
  sysctl -p
  echo "IPv6 已禁用"
fi

if [ $INSTALL_JAVA -eq 1 ]; then
  echo "Install Zulu 24 JDK"
  sudo apt install gnupg -y
  curl -s https://repos.azul.com/azul-repo.key | sudo gpg --dearmor -o /usr/share/keyrings/azul.gpg
  echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" | sudo tee /etc/apt/sources.list.d/zulu.list
  sudo apt update
  sudo apt install zulu24-jdk -y
  echo "Zulu 24 JDK 已安装"
fi

if [ $INSTALL_XANMOD -eq 1 ]; then
  echo "Install Xanmod LTS Kernel"
  sudo apt install gnupg
  wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor -vo /etc/apt/keyrings/xanmod-archive-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-release.list
  sudo apt install linux-xanmod-lts -y  # 安装 LTS 内核
  echo "Xanmod LTS 内核已安装。请重启系统以应用更改"
fi

echo "执行 SSH 密钥安装脚本..."
bash <(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main/SSH-Key-Installer.sh) -o -d -g $USER

echo "脚本执行完成"
