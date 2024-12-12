echo "Ban V6"
echo "# made for disabled IPv6 in $(date +%F)">>/etc/sysctl.conf
echo 'net.ipv6.conf.all.disable_ipv6 = 1'>>/etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1'>>/etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6 = 1'>>/etc/sysctl.conf
sysctl -p

echo "Install Zulu JDK"
sudo apt update
sudo apt install gnupg ca-certificates curl -y
curl -s https://repos.azul.com/azul-repo.key | sudo gpg --dearmor -o /usr/share/keyrings/azul.gpg
echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" | sudo tee /etc/apt/sources.list.d/zulu.list
sudo apt update
sudo apt install zulu21-jdk -y

sudo apt install wget curl screen -y
sudo apt upgrade -y
sudo apt dist-upgrade
