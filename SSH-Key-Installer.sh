#!/usr/bin/env bash
#=============================================================
# https://github.com/P3TERX/SSH_Key_Installer
# Description: Install SSH keys via GitHub, URL or local files
# Version: 2.8
# Author: P3TERX
# Modify: Dr
# Blog: https://p3terx.com
#=============================================================
# Changelog v2.8:
# - Support for /etc/ssh/sshd_config.d/ directory (modern approach)
# - Improved handling of commented configuration options
# - Better error handling and code optimization
# - Auto-detect and use appropriate config file location
#=============================================================
# eg.
# bash <(curl -fsSL https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main/SSH-Key-Installer.sh) -o -d -g

VERSION=2.8
RED_FONT_PREFIX="\033[31m"
LIGHT_GREEN_FONT_PREFIX="\033[1;32m"
FONT_COLOR_SUFFIX="\033[0m"
INFO="[${LIGHT_GREEN_FONT_PREFIX}INFO${FONT_COLOR_SUFFIX}]"
ERROR="[${RED_FONT_PREFIX}ERROR${FONT_COLOR_SUFFIX}]"
[ $EUID != 0 ] && SUDO=sudo

USAGE() {
    echo "
SSH Key Installer $VERSION

Usage:
  bash <(curl -fsSL https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main/SSH-Key-Installer.sh) [options...] <arg>

Options:
  -o	Overwrite mode, this option is valid at the top
  -g	Get the public key from GitHub, the arguments is the GitHub ID
  -u	Get the public key from the URL, the arguments is the URL
  -f	Get the public key from the local file, the arguments is the local file path
  -p	Change SSH port, the arguments is port number
  -d	Disable password login"
}

if [ $# -eq 0 ]; then
    USAGE
    exit 1
fi

get_sshd_config() {
    if [ $(uname -o) == Android ]; then
        echo "$PREFIX/etc/ssh/sshd_config"
    else
        # Check if sshd_config.d directory exists and is included in main config
        if [ -d "/etc/ssh/sshd_config.d" ] && grep -qE "^Include\s+/etc/ssh/sshd_config\.d/.*\.conf" /etc/ssh/sshd_config 2>/dev/null; then
            echo "/etc/ssh/sshd_config.d/90-ssh-key-installer.conf"
        else
            echo "/etc/ssh/sshd_config"
        fi
    fi
}

ensure_config_file() {
    local config_file=$1
    # For sshd_config.d, create new file if it doesn't exist
    if [[ "$config_file" == *"/sshd_config.d/"* ]] && [ ! -f "$config_file" ]; then
        echo -e "${INFO} Creating new config file in sshd_config.d..."
        $SUDO touch "$config_file"
        $SUDO chmod 600 "$config_file"
    fi
}

set_sshd_option() {
    local option=$1
    local value=$2
    local config_file=$3
    
    if [ $(uname -o) == Android ]; then
        if grep -q "^${option} " "$config_file" 2>/dev/null; then
            # Uncommented line exists, replace it
            sed -i "s@^${option} .*@${option} ${value}@" "$config_file" || return 1
        elif grep -q "^#${option} " "$config_file" 2>/dev/null; then
            # Commented line exists, uncomment and set value
            sed -i "s@^#${option} .*@${option} ${value}@" "$config_file" || return 1
        else
            # Option doesn't exist, append it
            echo "${option} ${value}" >>"$config_file" || return 1
        fi
    else
        if [[ "$config_file" == *"/sshd_config.d/"* ]]; then
            # For sshd_config.d file, simpler logic (no comments expected)
            if grep -q "^${option} " "$config_file" 2>/dev/null; then
                $SUDO sed -i "s@^${option} .*@${option} ${value}@" "$config_file" || return 1
            else
                echo "${option} ${value}" | $SUDO tee -a "$config_file" >/dev/null || return 1
            fi
        else
            # For main config file, handle commented lines
            if grep -q "^${option} " "$config_file" 2>/dev/null; then
                # Uncommented line exists, replace it
                $SUDO sed -i "s@^${option} .*@${option} ${value}@" "$config_file" || return 1
            elif grep -q "^#${option} " "$config_file" 2>/dev/null; then
                # Commented line exists, uncomment and set value
                $SUDO sed -i "s@^#${option} .*@${option} ${value}@" "$config_file" || return 1
            else
                # Option doesn't exist, append it
                echo "${option} ${value}" | $SUDO tee -a "$config_file" >/dev/null || return 1
            fi
        fi
    fi
    return 0
}

get_github_key() {
    if [ -z "${KEY_ID}" ]; then
        read -e -p "Please enter the GitHub account: " KEY_ID
        [ -z "${KEY_ID}" ] && echo -e "${ERROR} Invalid input." && exit 1
    fi
    echo -e "${INFO} The GitHub account is: ${KEY_ID}"
    echo -e "${INFO} Get key from GitHub..."
    PUB_KEY=$(curl -fsSL https://github.com/${KEY_ID}.keys)
    if [ "${PUB_KEY}" == "Not Found" ]; then
        echo -e "${ERROR} GitHub account not found."
        exit 1
    elif [ -z "${PUB_KEY}" ]; then
        echo -e "${ERROR} This account ssh key does not exist."
        exit 1
    fi
}

get_url_key() {
    if [ -z "${KEY_URL}" ]; then
        read -e -p "Please enter the URL: " KEY_URL
        [ -z "${KEY_URL}" ] && echo -e "${ERROR} Invalid input." && exit 1
    fi
    echo -e "${INFO} Get key from URL..."
    PUB_KEY=$(curl -fsSL "${KEY_URL}")
    if [ -z "${PUB_KEY}" ]; then
        echo -e "${ERROR} Failed to get key from URL or the content is empty."
        exit 1
    fi
}

get_local_key() {
    if [ -z "${KEY_PATH}" ]; then
        read -e -p "Please enter the path: " KEY_PATH
        [ -z "${KEY_PATH}" ] && echo -e "${ERROR} Invalid input." && exit 1
    fi
    if [ ! -f "${KEY_PATH}" ]; then
        echo -e "${ERROR} File '${KEY_PATH}' does not exist."
        exit 1
    fi
    echo -e "${INFO} Get key from ${KEY_PATH}..."
    PUB_KEY=$(cat "${KEY_PATH}")
    if [ -z "${PUB_KEY}" ]; then
        echo -e "${ERROR} File '${KEY_PATH}' is empty."
        exit 1
    fi
}

install_key() {
    [ -z "${PUB_KEY}" ] && echo -e "${ERROR} ssh key does not exist." && exit 1

    SSHD_CONFIG=$(get_sshd_config)
    echo -e "${INFO} Using SSH config file: $SSHD_CONFIG"
    ensure_config_file "$SSHD_CONFIG"

    # Check if PubkeyAuthentication needs to be set
    local need_set=0
    if [[ "$SSHD_CONFIG" == *"/sshd_config.d/"* ]]; then
        # For sshd_config.d file, ensure PubkeyAuthentication yes exists
        grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG" 2>/dev/null || need_set=1
    else
        # For main config file, only skip if uncommented "PubkeyAuthentication yes" exists
        if ! grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG" 2>/dev/null; then
            need_set=1
        fi
    fi

    if [ $need_set -eq 1 ]; then
        echo -e "${INFO} Setting PubkeyAuthentication to yes..."
        if set_sshd_option "PubkeyAuthentication" "yes" "$SSHD_CONFIG"; then
            [ $(uname -o) == Android ] && RESTART_SSHD=2 || RESTART_SSHD=1
            echo -e "${INFO} PubkeyAuthentication set to yes."
        else
            echo -e "${ERROR} Failed to set PubkeyAuthentication to yes!"
            exit 1
        fi
    fi

    if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
        echo -e "${INFO} '${HOME}/.ssh/authorized_keys' is missing..."
        echo -e "${INFO} Creating ${HOME}/.ssh/authorized_keys..."
        mkdir -p "${HOME}/.ssh/"
        touch "${HOME}/.ssh/authorized_keys"
        if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
            echo -e "${ERROR} Failed to create SSH key file."
            exit 1
        else
            echo -e "${INFO} Key file created, proceeding..."
        fi
    fi
    
    if [ "${OVERWRITE}" == 1 ]; then
        echo -e "${INFO} Overwriting SSH key..."
        printf '%s\n' "${PUB_KEY}" >"${HOME}/.ssh/authorized_keys"
    else
        echo -e "${INFO} Adding SSH key..."
        printf '\n%s\n' "${PUB_KEY}" >>"${HOME}/.ssh/authorized_keys"
    fi
    chmod 700 "${HOME}/.ssh/"
    chmod 600 "${HOME}/.ssh/authorized_keys"

    if grep -qF "${PUB_KEY}" "${HOME}/.ssh/authorized_keys"; then
        echo -e "${INFO} SSH Key installed successfully!"
    else
        echo -e "${ERROR} SSH key installation failed!"
        exit 1
    fi
}

change_port() {
    echo -e "${INFO} Changing SSH port to ${SSH_PORT} ..."
    SSHD_CONFIG=$(get_sshd_config)
    echo -e "${INFO} Using SSH config file: $SSHD_CONFIG"
    ensure_config_file "$SSHD_CONFIG"

    if set_sshd_option "Port" "${SSH_PORT}" "$SSHD_CONFIG"; then
        echo -e "${INFO} SSH port changed successfully!"
        [ $(uname -o) == Android ] && RESTART_SSHD=2 || RESTART_SSHD=1
    else
        echo -e "${ERROR} SSH port change failed!"
        exit 1
    fi
}

disable_password() {
    SSHD_CONFIG=$(get_sshd_config)
    echo -e "${INFO} Using SSH config file: $SSHD_CONFIG"
    ensure_config_file "$SSHD_CONFIG"

    if set_sshd_option "PasswordAuthentication" "no" "$SSHD_CONFIG"; then
        echo -e "${INFO} Disabled password login in SSH."
        [ $(uname -o) == Android ] && RESTART_SSHD=2 || RESTART_SSHD=1
    else
        echo -e "${ERROR} Disable password login failed!"
        exit 1
    fi
}

while getopts "og:u:f:p:d" OPT; do
    case $OPT in
    o)
        OVERWRITE=1
        ;;
    g)
        KEY_ID=$OPTARG
        get_github_key
        install_key
        ;;
    u)
        KEY_URL=$OPTARG
        get_url_key
        install_key
        ;;
    f)
        KEY_PATH=$OPTARG
        get_local_key
        install_key
        ;;
    p)
        SSH_PORT=$OPTARG
        change_port
        ;;
    d)
        disable_password
        ;;
    ?)
        USAGE
        exit 1
        ;;
    :)
        USAGE
        exit 1
        ;;
    *)
        USAGE
        exit 1
        ;;
    esac
done

if [ "$RESTART_SSHD" = 1 ]; then
    echo -e "${INFO} Restarting sshd..."
    $SUDO systemctl restart sshd && echo -e "${INFO} Done."
elif [ "$RESTART_SSHD" = 2 ]; then
    echo -e "${INFO} Restart sshd or Termux App to take effect."
fi
