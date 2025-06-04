#!/bin/bash

# FRP管理脚本 - 支持Linux、OpenWrt和macOS
# 功能：安装、配置、管理FRP服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置文件路径
FRP_DIR="/usr/local/frp"
FRP_CONFIG_DIR="/etc/frp"
FRP_LOG_DIR="/var/log/frp"
FRPS_CONFIG="$FRP_CONFIG_DIR/frps.ini"
FRPC_CONFIG="$FRP_CONFIG_DIR/frpc.ini"
FRPS_LOG="$FRP_LOG_DIR/frps.log"
FRPC_LOG="$FRP_LOG_DIR/frpc.log"

# 检测系统类型
check_system() {
    if [ -f /etc/openwrt_release ]; then
        SYSTEM="openwrt"
    elif [ "$(uname)" = "Darwin" ]; then
        SYSTEM="macos"
    elif [ -f /etc/debian_version ]; then
        SYSTEM="debian"
    elif [ -f /etc/redhat-release ]; then
        SYSTEM="centos"
    else
        SYSTEM="linux"
    fi
}

# 检查权限
check_root() {
    if [ "$SYSTEM" != "macos" ] && [ "$EUID" -ne 0 ]; then
        echo -e "${RED}此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 主菜单
main_menu() {
    clear
    echo -e "${BLUE}==================================${NC}"
    echo -e "${BLUE}       FRP 管理脚本 v1.0          ${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}系统: $SYSTEM${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo "1) 安装 FRP"
    echo "2) 卸载 FRP"
    echo "3) 退出"
    echo -e "${BLUE}==================================${NC}"
    read -rp "请选择操作: " choice

    case "$choice" in
        1)
            install_frp
            ;;
        2)
            uninstall_frp
            ;;
        3)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
    echo
    read -rp "按回车键继续..." -n1 -s
    main_menu
}

# 安装FRP（简化示例）
install_frp() {
    echo -e "${GREEN}开始安装FRP...${NC}"
    mkdir -p $FRP_DIR $FRP_CONFIG_DIR $FRP_LOG_DIR
    echo -e "${YELLOW}请输入版本号 (默认: 0.51.3):${NC}"
    read -r version
    version=${version:-0.51.3}
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) echo -e "${RED}不支持的架构: $ARCH${NC}"; return ;;
    esac
    OS="linux"
    url="https://github.com/fatedier/frp/releases/download/v$version/frp_${version}_${OS}_${ARCH}.tar.gz"
    wget -O /tmp/frp.tar.gz "$url"
    tar -xzf /tmp/frp.tar.gz -C /tmp
    cp /tmp/frp_${version}_${OS}_${ARCH}/frp* $FRP_DIR/
    chmod +x $FRP_DIR/frp*
    echo -e "${GREEN}FRP 安装完成！${NC}"
}

# 卸载FRP
uninstall_frp() {
    echo -e "${RED}确定要卸载FRP吗？（yes确认）${NC}"
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        echo "取消卸载"
        return
    fi
    rm -rf $FRP_DIR $FRP_CONFIG_DIR $FRP_LOG_DIR
    echo -e "${GREEN}FRP已卸载${NC}"
}

# 初始化
check_system
check_root
main_menu
