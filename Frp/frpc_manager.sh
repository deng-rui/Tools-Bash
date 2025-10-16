#!/bin/bash
# frpc 管理脚本

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Plain="\033[0m"

SHELL_VERSION="1.0"
GITHUB_RAW="https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main"
GITHUB_PROXY="https://v6.gh-proxy.com"

FRP_VER="0.61.2"
FRPC_PATH="/usr/local/frp"
FRPC_CONF="/usr/local/frp/frpc.toml"
SERVICE_FILE="/lib/systemd/system/frpc.service"

USE_PROXY=""
DL_URL=""

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Red}需要root权限，请用sudo运行${Plain}" && exit 1
}

check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -qi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -qi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -qi "debian"; then
        release="debian"
    elif cat /proc/version | grep -qi "ubuntu"; then
        release="ubuntu"
    fi
    
    bit=$(uname -m)
    case "$bit" in
        x86_64) bit="amd64" ;;
        aarch64) bit="arm64" ;;
        armv7l) bit="arm" ;;
        *) echo -e "${Red}不支持的架构: $bit${Plain}" && exit 1 ;;
    esac
}

ask_proxy() {
    echo -e "\n${Yellow}国内网络可能需要加速${Plain}"
    echo -n "使用GitHub镜像加速? [Y/n]: "
    read use_proxy
    use_proxy=${use_proxy:-y}
    
    if [[ "${use_proxy,,}" == "y" ]]; then
        USE_PROXY="yes"
        DL_URL="${GITHUB_PROXY}/${GITHUB_RAW}"
        echo -e "${Green}已启用镜像加速${Plain}"
    else
        DL_URL="${GITHUB_RAW}"
        echo -e "${Green}使用官方地址${Plain}"
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    
    if ! wget --no-check-certificate -O "${output}" "${url}" 2>/dev/null; then
        if [[ "$USE_PROXY" == "yes" ]]; then
            echo -e "${Yellow}尝试直连...${Plain}"
            local direct="${url/${GITHUB_PROXY}\//}"
            wget --no-check-certificate -O "${output}" "${direct}" 2>/dev/null && return 0
        fi
        return 1
    fi
    return 0
}

get_frp() {
    local file="frp_${FRP_VER}_linux_${bit}"
    local url="https://github.com/fatedier/frp/releases/download/v${FRP_VER}/${file}.tar.gz"
    
    [[ "$USE_PROXY" == "yes" ]] && url="${GITHUB_PROXY}/${url}"
    
    download_file "${url}" "${file}.tar.gz"
}

select_template() {
    clear
    echo -e "${Green}==============================${Plain}"
    echo -e "${Green}  选择配置模板${Plain}"
    echo -e "${Green}==============================${Plain}"
    echo ""
    echo "[1] 基础 - SSH端口转发"
    echo "[2] Web - HTTP/HTTPS穿透"
    echo "[3] 空白 - 自己配置"
    echo ""
    echo -n "选择 [1-3] (默认1): "
    read choice
    choice=${choice:-1}
    
    case "$choice" in
        1) template="frpc_basic.toml" ;;
        2) template="frpc_web.toml" ;;
        3) template="blank" ;;
        *) template="frpc_basic.toml" ;;
    esac
    
    setup_config
}

setup_config() {
    local tmp_conf="/tmp/frpc_tmp.toml"
    
    if [[ "$template" == "blank" ]]; then
        cat > "${tmp_conf}" <<'EOF'
serverAddr = "your_server_ip"
serverPort = 7000
auth.token = "your_token"

log.to = "./frpc.log"
log.level = "info"
log.maxDays = 3
EOF
    else
        local tpl_url="${DL_URL}/Frp/frpc-config/${template}"
        echo -e "${Green}下载配置...${Plain}"
        if ! download_file "${tpl_url}" "${tmp_conf}"; then
            echo -e "${Yellow}下载失败，用空白模板${Plain}"
            cat > "${tmp_conf}" <<'EOF'
serverAddr = "your_server_ip"
serverPort = 7000
auth.token = "your_token"

log.to = "./frpc.log"
log.level = "info"
log.maxDays = 3
EOF
        fi
    fi
    
    echo ""
    echo -n "服务器地址: "
    read addr
    while [[ -z "$addr" ]]; do
        echo -e "${Red}不能为空${Plain}"
        echo -n "服务器地址: "
        read addr
    done
    
    echo -n "服务器端口 (7000): "
    read port
    port=${port:-7000}
    
    echo -n "认证令牌: "
    read token
    while [[ -z "$token" ]]; do
        echo -e "${Red}不能为空${Plain}"
        echo -n "认证令牌: "
        read token
    done
    
    sed -i "s/your_server_ip/${addr}/g" "${tmp_conf}"
    sed -i "s/serverPort = 7000/serverPort = ${port}/g" "${tmp_conf}"
    sed -i "s/your_token/${token}/g" "${tmp_conf}"
    
    mkdir -p $(dirname "${FRPC_CONF}")
    mv "${tmp_conf}" "${FRPC_CONF}"
    
    echo -e "${Green}配置已保存: ${FRPC_CONF}${Plain}"
}

install_frpc() {
    check_root
    check_sys
    
    if [[ -f "${FRPC_PATH}/frpc" ]] && [[ -f "${SERVICE_FILE}" ]]; then
        echo -e "${Red}已安装frpc${Plain}"
        echo -n "重新安装? [y/n]: "
        read reinstall
        [[ "${reinstall,,}" != "y" ]] && return
        uninstall_frpc
    fi
    
    [[ -z "${release}" ]] && echo -e "${Red}不支持的系统${Plain}" && exit 1
    
    echo -e "${Green}安装依赖...${Plain}"
    if [[ ${release} == "centos" ]]; then
        yum install -y wget curl tar sed
    else
        apt-get update && apt-get install -y wget curl tar sed
    fi
    
    ask_proxy
    
    echo -e "${Green}检测架构: ${bit}${Plain}"
    
    cd /tmp
    echo -e "${Green}下载frp...${Plain}"
    if ! get_frp; then
        echo -e "${Red}下载失败${Plain}"
        exit 1
    fi
    
    FILE="frp_${FRP_VER}_linux_${bit}"
    
    echo -e "${Green}解压...${Plain}"
    tar -zxf "${FILE}.tar.gz"
    
    echo -e "${Green}安装...${Plain}"
    mkdir -p "${FRPC_PATH}"
    mv "${FILE}/frpc" "${FRPC_PATH}/"
    chmod +x "${FRPC_PATH}/frpc"
    
    rm -rf "${FILE}" "${FILE}.tar.gz"
    
    select_template
    
    echo -e "${Green}设置服务...${Plain}"
    local svc_url="${DL_URL}/Frp/systemd/frpc.service"
    
    if ! download_file "${svc_url}" "${SERVICE_FILE}"; then
        echo -e "${Red}下载服务文件失败${Plain}"
        exit 1
    fi
    
    systemctl daemon-reload
    systemctl enable frpc
    systemctl start frpc
    
    sleep 2
    if systemctl is-active frpc >/dev/null 2>&1; then
        echo -e "${Green}安装完成！${Plain}"
    else
        echo -e "${Red}启动失败，看看日志: journalctl -u frpc${Plain}"
    fi
}

uninstall_frpc() {
    echo -e "${Green}卸载frpc...${Plain}"
    
    systemctl stop frpc 2>/dev/null
    systemctl disable frpc 2>/dev/null
    
    if [[ -f "${FRPC_CONF}" ]]; then
        backup="${FRPC_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${FRPC_CONF}" "${backup}"
        echo -e "${Green}配置备份: ${backup}${Plain}"
    fi
    
    rm -rf "${FRPC_PATH}"
    rm -f "${SERVICE_FILE}"
    
    systemctl daemon-reload
    systemctl reset-failed
    
    echo -e "${Green}已卸载${Plain}"
}

add_proxy() {
    [[ ! -f "${FRPC_CONF}" ]] && echo -e "${Red}配置文件不存在，先安装${Plain}" && return
    
    echo -e "\n${Green}==============================${Plain}"
    echo -e "${Green}  添加代理${Plain}"
    echo -e "${Green}==============================${Plain}"
    echo "[1] TCP"
    echo "[2] UDP"
    echo "[3] HTTP"
    echo "[4] HTTPS"
    echo "[5] STCP"
    echo ""
    echo -n "选择类型 [1-5]: "
    read type_num
    
    case "$type_num" in
        1) add_tcp ;;
        2) add_udp ;;
        3) add_http ;;
        4) add_https ;;
        5) add_stcp ;;
        *) echo -e "${Red}输入错误${Plain}" ;;
    esac
}

add_tcp() {
    echo -e "\n${Green}TCP代理${Plain}"
    
    echo -n "名称: "
    read name
    [[ -z "$name" ]] && echo -e "${Red}不能为空${Plain}" && return
    
    echo -n "本地IP (127.0.0.1): "
    read local_ip
    local_ip=${local_ip:-127.0.0.1}
    
    echo -n "本地端口: "
    read local_port
    
    echo -n "远程端口: "
    read remote_port
    
    cat >> "${FRPC_CONF}" <<EOF

[[proxies]]
name = "${name}"
type = "tcp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    echo -e "${Green}已添加${Plain}"
    restart_frpc
}

add_udp() {
    echo -e "\n${Green}UDP代理${Plain}"
    
    echo -n "名称: "
    read name
    [[ -z "$name" ]] && return
    
    echo -n "本地IP (127.0.0.1): "
    read local_ip
    local_ip=${local_ip:-127.0.0.1}
    
    echo -n "本地端口: "
    read local_port
    
    echo -n "远程端口: "
    read remote_port
    
    cat >> "${FRPC_CONF}" <<EOF

[[proxies]]
name = "${name}"
type = "udp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF
    
    echo -e "${Green}已添加${Plain}"
    restart_frpc
}

add_http() {
    echo -e "\n${Green}HTTP代理${Plain}"
    
    echo -n "名称: "
    read name
    [[ -z "$name" ]] && return
    
    echo -n "本地IP (127.0.0.1): "
    read local_ip
    local_ip=${local_ip:-127.0.0.1}
    
    echo -n "本地端口 (80): "
    read local_port
    local_port=${local_port:-80}
    
    echo -n "域名 (空格分隔): "
    read domains
    
    IFS=' ' read -ra domain_array <<< "$domains"
    domain_toml="["
    for i in "${!domain_array[@]}"; do
        [[ $i -gt 0 ]] && domain_toml+=", "
        domain_toml+="\"${domain_array[$i]}\""
    done
    domain_toml+="]"
    
    cat >> "${FRPC_CONF}" <<EOF

[[proxies]]
name = "${name}"
type = "http"
localIP = "${local_ip}"
localPort = ${local_port}
customDomains = ${domain_toml}
EOF
    
    echo -e "${Green}已添加${Plain}"
    restart_frpc
}

add_https() {
    echo -e "\n${Green}HTTPS代理${Plain}"
    
    echo -n "名称: "
    read name
    [[ -z "$name" ]] && return
    
    echo -n "本地IP (127.0.0.1): "
    read local_ip
    local_ip=${local_ip:-127.0.0.1}
    
    echo -n "本地端口 (443): "
    read local_port
    local_port=${local_port:-443}
    
    echo -n "域名 (空格分隔): "
    read domains
    
    IFS=' ' read -ra domain_array <<< "$domains"
    domain_toml="["
    for i in "${!domain_array[@]}"; do
        [[ $i -gt 0 ]] && domain_toml+=", "
        domain_toml+="\"${domain_array[$i]}\""
    done
    domain_toml+="]"
    
    cat >> "${FRPC_CONF}" <<EOF

[[proxies]]
name = "${name}"
type = "https"
localIP = "${local_ip}"
localPort = ${local_port}
customDomains = ${domain_toml}
EOF
    
    echo -e "${Green}已添加${Plain}"
    restart_frpc
}

add_stcp() {
    echo -e "\n${Green}STCP代理${Plain}"
    
    echo -n "名称: "
    read name
    [[ -z "$name" ]] && return
    
    echo -n "本地IP (127.0.0.1): "
    read local_ip
    local_ip=${local_ip:-127.0.0.1}
    
    echo -n "本地端口: "
    read local_port
    
    echo -n "密钥: "
    read secret
    
    cat >> "${FRPC_CONF}" <<EOF

[[proxies]]
name = "${name}"
type = "stcp"
localIP = "${local_ip}"
localPort = ${local_port}
secretKey = "${secret}"
EOF
    
    echo -e "${Green}已添加${Plain}"
    restart_frpc
}

show_proxies() {
    [[ ! -f "${FRPC_CONF}" ]] && echo -e "${Red}配置文件不存在${Plain}" && return
    
    echo -e "${Green}==============================${Plain}"
    echo -e "${Green}  代理列表${Plain}"
    echo -e "${Green}==============================${Plain}"
    
    awk '/^\[\[proxies\]\]/{flag=1; next} /^\[\[/{flag=0} flag && /^name =/{print}' "${FRPC_CONF}" | nl
    
    echo -e "${Green}==============================${Plain}"
}

start_frpc() {
    systemctl start frpc
    sleep 1
    systemctl is-active frpc >/dev/null 2>&1 && echo -e "${Green}已启动${Plain}" || echo -e "${Red}启动失败${Plain}"
}

stop_frpc() {
    systemctl stop frpc
    echo -e "${Green}已停止${Plain}"
}

restart_frpc() {
    systemctl restart frpc
    sleep 1
    systemctl is-active frpc >/dev/null 2>&1 && echo -e "${Green}已重启${Plain}" || echo -e "${Red}重启失败${Plain}"
}

status_frpc() {
    systemctl status frpc --no-pager
}

view_config() {
    if [[ -f "${FRPC_CONF}" ]]; then
        echo -e "${Green}==============================${Plain}"
        cat "${FRPC_CONF}"
        echo -e "${Green}==============================${Plain}"
    else
        echo -e "${Red}配置文件不存在${Plain}"
    fi
}

edit_config() {
    [[ ! -f "${FRPC_CONF}" ]] && echo -e "${Red}配置文件不存在${Plain}" && return
    
    echo -e "${Green}编辑配置，保存后记得重启服务${Plain}"
    
    if command -v nano >/dev/null 2>&1; then
        nano "${FRPC_CONF}"
    elif command -v vi >/dev/null 2>&1; then
        vi "${FRPC_CONF}"
    else
        echo -e "${Red}没有找到编辑器${Plain}"
    fi
}

view_logs() {
    echo -e "${Green}日志 (Ctrl+C退出)${Plain}"
    journalctl -u frpc -n 50 -f
}

show_menu() {
    clear
    echo -e "${Green}==============================${Plain}"
    echo -e "${Green}  FRPC 管理 v${SHELL_VERSION}${Plain}"
    echo -e "${Green}==============================${Plain}"
    echo ""
    echo " 1. 安装"
    echo " 2. 卸载"
    echo "---"
    echo " 3. 添加代理"
    echo " 4. 查看代理"
    echo "---"
    echo " 5. 启动"
    echo " 6. 停止"
    echo " 7. 重启"
    echo " 8. 状态"
    echo "---"
    echo " 9. 查看配置"
    echo " 10. 编辑配置"
    echo " 11. 查看日志"
    echo "---"
    echo " 0. 退出"
    echo ""
    read -p "选择 [0-11]: " num
    
    case "$num" in
        1) install_frpc ;;
        2) uninstall_frpc ;;
        3) add_proxy ;;
        4) show_proxies ;;
        5) start_frpc ;;
        6) stop_frpc ;;
        7) restart_frpc ;;
        8) status_frpc ;;
        9) view_config ;;
        10) edit_config ;;
        11) view_logs ;;
        0) exit 0 ;;
        *) echo -e "${Red}输入错误${Plain}" ;;
    esac
    
    echo ""
    read -p "回车返回..."
    show_menu
}

show_menu
