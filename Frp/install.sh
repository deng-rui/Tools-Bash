#!/bin/bash
# FRP 快速安装

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Plain="\033[0m"

GITHUB_RAW="https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main"
GITHUB_PROXY="https://v6.gh-proxy.com"

USE_PROXY=""
DL_URL=""

banner() {
    clear
    echo -e "${Green}==============================${Plain}"
    echo -e "${Green}  FRP 安装工具${Plain}"
    echo -e "${Green}==============================${Plain}"
    echo ""
}

ask_proxy() {
    echo -e "${Yellow}国内网络建议用镜像加速${Plain}"
    echo -n "使用GitHub镜像? [Y/n]: "
    read use_proxy
    use_proxy=${use_proxy:-y}
    
    if [[ "${use_proxy,,}" == "y" ]]; then
        USE_PROXY="yes"
        DL_URL="${GITHUB_PROXY}/${GITHUB_RAW}"
        echo -e "${Green}已启用镜像${Plain}"
    else
        DL_URL="${GITHUB_RAW}"
        echo -e "${Green}使用官方地址${Plain}"
    fi
    echo ""
}

download_run() {
    local script="$1"
    local desc="$2"
    
    echo -e "${Green}下载 ${desc}...${Plain}"
    
    local url="${DL_URL}/Frp/${script}"
    local tmp="/tmp/${script}"
    
    if wget --no-check-certificate -O "${tmp}" "${url}" 2>/dev/null; then
        chmod +x "${tmp}"
        echo -e "${Green}下载完成${Plain}"
        echo ""
        bash "${tmp}"
    else
        echo -e "${Red}下载失败${Plain}"
        
        if [[ "$USE_PROXY" == "yes" ]]; then
            echo -e "${Yellow}尝试直连...${Plain}"
            local direct="${GITHUB_RAW}/Frp/${script}"
            if wget --no-check-certificate -O "${tmp}" "${direct}" 2>/dev/null; then
                chmod +x "${tmp}"
                echo -e "${Green}下载完成${Plain}"
                echo ""
                bash "${tmp}"
                return 0
            fi
        fi
        
        echo -e "${Red}请检查网络${Plain}"
        exit 1
    fi
}

menu() {
    banner
    
    echo -e "${Yellow}选择要安装的组件:${Plain}"
    echo ""
    echo "[1] FRP服务端 (frps)"
    echo "    在有公网IP的服务器上装"
    echo ""
    echo "[2] FRP客户端 (frpc)"
    echo "    在需要穿透的设备上装"
    echo ""
    echo "[0] 退出"
    echo ""
    
    read -p "选择 [0-2]: " choice
    
    case "$choice" in
        1)
            ask_proxy
            download_run "frps_manager.sh" "FRPS管理脚本"
            ;;
        2)
            ask_proxy
            download_run "frpc_manager.sh" "FRPC管理脚本"
            ;;
        0)
            echo -e "${Green}退出${Plain}"
            exit 0
            ;;
        *)
            echo -e "${Red}输入错误${Plain}"
            sleep 2
            menu
            ;;
    esac
}

# 检查wget
if ! command -v wget >/dev/null 2>&1; then
    echo -e "${Yellow}安装wget...${Plain}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y wget
    elif command -v yum >/dev/null 2>&1; then
        yum install -y wget
    else
        echo -e "${Red}请先安装wget${Plain}"
        exit 1
    fi
fi

menu
