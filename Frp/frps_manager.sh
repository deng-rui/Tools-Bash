#!/bin/bash
# frps 管理脚本

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Plain="\033[0m"

SHELL_VERSION="1.0"
GITHUB_RAW="https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main"
GITHUB_PROXY="https://v6.gh-proxy.com"

FRP_VER="0.61.2"
FRPS_PATH="/usr/local/frp"
FRPS_CONF="/usr/local/frp/frps.toml"
SERVICE_FILE="/lib/systemd/system/frps.service"

USE_PROXY=""
DL_URL=""
DASHBOARD_ENABLED="no"
DASHBOARD_PORT="7500"

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
    echo -en "使用GitHub镜像加速? [Y/n]: "
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
    echo "[1] 基础 - 纯TCP转发"
    echo "[2] 标准 - HTTP/HTTPS+面板 (推荐)"
    echo "[3] 高级 - 完整功能"
    echo ""
    echo -n "选择 [1-3] (默认2): "
    read choice
    choice=${choice:-2}
    
    case "$choice" in
        1) template="frps_basic.toml" ;;
        2) template="frps_standard.toml" ;;
        3) template="frps_advanced.toml" ;;
        *) template="frps_standard.toml" ;;
    esac
    
    setup_config
}

setup_config() {
    local tpl_url="${DL_URL}/Frp/frps-config/${template}"
    local tmp_conf="/tmp/frps_tmp.toml"
    
    echo -e "${Green}下载配置...${Plain}"
    if ! download_file "${tpl_url}" "${tmp_conf}"; then
        echo -e "${Red}下载失败${Plain}"
        exit 1
    fi
    
    echo ""
    echo -n "认证令牌 (留空随机生成): "
    read token
    
    if [[ -z "$token" ]]; then
        token=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        echo -e "${Green}生成令牌: ${token}${Plain}"
        echo -e "${Yellow}请保存好，客户端要用${Plain}"
    fi
    
    sed -i "s/your_token_here/${token}/g" "${tmp_conf}"
    
    if [[ "$template" != "frps_basic.toml" ]]; then
        setup_dashboard "${tmp_conf}"
    fi
    
    mkdir -p $(dirname "${FRPS_CONF}")
    mv "${tmp_conf}" "${FRPS_CONF}"
    
    show_info
}

setup_dashboard() {
    local conf="$1"
    echo ""
    echo -n "启用管理面板? [y/n] (n): "
    read enable_dash
    enable_dash=${enable_dash:-n}
    
    if [[ "${enable_dash,,}" != "y" ]]; then
        # 禁用面板
        sed -i '/^webServer\./d' "$conf"
        echo -e "${Yellow}已禁用面板${Plain}"
        DASHBOARD_ENABLED="no"
        return
    fi
    
    DASHBOARD_ENABLED="yes"
    
    echo -n "端口 (7500): "
    read port
    port=${port:-7500}
    sed -i "s/webServer.port = 7500/webServer.port = ${port}/g" "$conf"
    
    echo -n "用户名 (admin): "
    read user
    user=${user:-admin}
    
    echo -n "密码 (admin): "
    read pwd
    pwd=${pwd:-admin}
    
    sed -i "s/webServer.user = \"admin\"/webServer.user = \"${user}\"/g" "$conf"
    sed -i "s/webServer.password = \"admin\"/webServer.password = \"${pwd}\"/g" "$conf"
    
    DASHBOARD_PORT="${port}"
}

show_info() {
    local ip=$(curl -s https://api.ipify.org 2>/dev/null || echo "YOUR_IP")
    
    echo ""
    echo -e "${Green}==============================${Plain}"
    echo -e "服务器: ${ip}"
    echo -e "令牌: ${token}"
    echo -e "配置: ${FRPS_CONF}"
    
    if [[ "$DASHBOARD_ENABLED" == "yes" ]]; then
        echo -e "面板: http://${ip}:${DASHBOARD_PORT}"
    fi
    
    echo -e "${Green}==============================${Plain}"
}

install_frps() {
    check_root
    check_sys
    
    if [[ -f "${FRPS_PATH}/frps" ]] && [[ -f "${SERVICE_FILE}" ]]; then
        echo -e "${Red}已安装frps${Plain}"
        echo -n "重新安装? [y/n]: "
        read reinstall
        [[ "${reinstall,,}" != "y" ]] && return
        uninstall_frps
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
    mkdir -p "${FRPS_PATH}"
    mv "${FILE}/frps" "${FRPS_PATH}/"
    chmod +x "${FRPS_PATH}/frps"
    
    rm -rf "${FILE}" "${FILE}.tar.gz"
    
    select_template
    
    echo -e "${Green}设置服务...${Plain}"
    local svc_url="${DL_URL}/Frp/systemd/frps.service"
    
    if ! download_file "${svc_url}" "${SERVICE_FILE}"; then
        echo -e "${Red}下载服务文件失败${Plain}"
        exit 1
    fi
    
    systemctl daemon-reload
    systemctl enable frps
    systemctl start frps
    
    sleep 2
    if systemctl is-active frps >/dev/null 2>&1; then
        echo -e "${Green}安装完成！${Plain}"
    else
        echo -e "${Red}启动失败，看看日志: journalctl -u frps${Plain}"
    fi
}

uninstall_frps() {
    echo -e "${Green}卸载frps...${Plain}"
    
    systemctl stop frps 2>/dev/null
    systemctl disable frps 2>/dev/null
    
    if [[ -f "${FRPS_CONF}" ]]; then
        backup="${FRPS_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${FRPS_CONF}" "${backup}"
        echo -e "${Green}配置备份: ${backup}${Plain}"
    fi
    
    rm -rf "${FRPS_PATH}"
    rm -f "${SERVICE_FILE}"
    
    systemctl daemon-reload
    systemctl reset-failed
    
    echo -e "${Green}已卸载${Plain}"
}

start_frps() {
    systemctl start frps
    sleep 1
    systemctl is-active frps >/dev/null 2>&1 && echo -e "${Green}已启动${Plain}" || echo -e "${Red}启动失败${Plain}"
}

stop_frps() {
    systemctl stop frps
    echo -e "${Green}已停止${Plain}"
}

restart_frps() {
    systemctl restart frps
    sleep 1
    systemctl is-active frps >/dev/null 2>&1 && echo -e "${Green}已重启${Plain}" || echo -e "${Red}重启失败${Plain}"
}

status_frps() {
    systemctl status frps --no-pager
}

view_config() {
    if [[ -f "${FRPS_CONF}" ]]; then
        echo -e "${Green}==============================${Plain}"
        cat "${FRPS_CONF}"
        echo -e "${Green}==============================${Plain}"
    else
        echo -e "${Red}配置文件不存在${Plain}"
    fi
}

edit_config() {
    [[ ! -f "${FRPS_CONF}" ]] && echo -e "${Red}配置文件不存在${Plain}" && return
    
    echo -e "${Green}编辑配置，保存后记得重启服务${Plain}"
    
    if command -v nano >/dev/null 2>&1; then
        nano "${FRPS_CONF}"
    elif command -v vi >/dev/null 2>&1; then
        vi "${FRPS_CONF}"
    else
        echo -e "${Red}没有找到编辑器${Plain}"
    fi
}

update_template() {
    echo -e "${Green}更新配置模板...${Plain}"
    ask_proxy
    select_template
    restart_frps
}

view_logs() {
    echo -e "${Green}日志 (Ctrl+C退出)${Plain}"
    journalctl -u frps -n 50 -f
}

show_menu() {
    clear
    echo -e "${Green}==============================${Plain}"
    echo -e "${Green}  FRPS 管理 v${SHELL_VERSION}${Plain}"
    echo -e "${Green}==============================${Plain}"
    echo ""
    echo " 1. 安装"
    echo " 2. 卸载"
    echo " 3. 更新配置"
    echo "---"
    echo " 4. 启动"
    echo " 5. 停止"
    echo " 6. 重启"
    echo " 7. 状态"
    echo "---"
    echo " 8. 查看配置"
    echo " 9. 编辑配置"
    echo " 10. 查看日志"
    echo "---"
    echo " 0. 退出"
    echo ""
    read -p "选择 [0-10]: " num
    
    case "$num" in
        1) install_frps ;;
        2) uninstall_frps ;;
        3) update_template ;;
        4) start_frps ;;
        5) stop_frps ;;
        6) restart_frps ;;
        7) status_frps ;;
        8) view_config ;;
        9) edit_config ;;
        10) view_logs ;;
        0) exit 0 ;;
        *) echo -e "${Red}输入错误${Plain}" ;;
    esac
    
    echo ""
    read -p "回车返回..."
    show_menu
}

show_menu


