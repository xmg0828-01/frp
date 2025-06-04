#!/bin/bash

# FRP管理脚本 - 支持Linux、OpenWrt和macOS

# 功能：安装、配置、管理FRP服务

# 颜色定义

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
BLUE=’\033[0;34m’
NC=’\033[0m’

# 配置文件路径

FRP_DIR=”/usr/local/frp”
FRP_CONFIG_DIR=”/etc/frp”
FRP_LOG_DIR=”/var/log/frp”
FRPS_CONFIG=”$FRP_CONFIG_DIR/frps.ini”
FRPC_CONFIG=”$FRP_CONFIG_DIR/frpc.ini”
FRPS_LOG=”$FRP_LOG_DIR/frps.log”
FRPC_LOG=”$FRP_LOG_DIR/frpc.log”

# 检测系统类型

check_system() {
if [ -f /etc/openwrt_release ]; then
SYSTEM=“openwrt”
elif [ “$(uname)” = “Darwin” ]; then
SYSTEM=“macos”
elif [ -f /etc/debian_version ]; then
SYSTEM=“debian”
elif [ -f /etc/redhat-release ]; then
SYSTEM=“centos”
else
SYSTEM=“linux”
fi
}

# 检测架构

check_arch() {
ARCH=$(uname -m)
if [ “$SYSTEM” = “macos” ]; then
case $ARCH in
x86_64)
ARCH=“amd64”
OS=“darwin”
;;
arm64)
ARCH=“arm64”
OS=“darwin”
;;
*)
echo -e “${RED}不支持的Mac架构: $ARCH${NC}”
exit 1
;;
esac
else
OS=“linux”
case $ARCH in
x86_64)
ARCH=“amd64”
;;
aarch64)
ARCH=“arm64”
;;
armv7l)
ARCH=“arm”
;;
*)
echo -e “${RED}不支持的架构: $ARCH${NC}”
exit 1
;;
esac
fi
}

# 创建必要目录

create_dirs() {
if [ “$SYSTEM” = “macos” ]; then
sudo mkdir -p $FRP_DIR
sudo mkdir -p $FRP_CONFIG_DIR
sudo mkdir -p $FRP_LOG_DIR
else
mkdir -p $FRP_DIR
mkdir -p $FRP_CONFIG_DIR
mkdir -p $FRP_LOG_DIR
fi
}

# 下载FRP

download_frp() {
local version=$1
local type=$2

```
echo -e "${BLUE}正在下载FRP ${version}...${NC}"

local url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_${OS}_${ARCH}.tar.gz"
local temp_file="/tmp/frp_${version}.tar.gz"

if command -v wget >/dev/null 2>&1; then
    wget -O "$temp_file" "$url" || return 1
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$temp_file" "$url" || return 1
else
    echo -e "${RED}请先安装wget或curl${NC}"
    return 1
fi

tar -xzf "$temp_file" -C /tmp/

if [ "$type" = "server" ] || [ "$type" = "both" ]; then
    if [ "$SYSTEM" = "macos" ]; then
        sudo cp "/tmp/frp_${version}_${OS}_${ARCH}/frps" "$FRP_DIR/"
        sudo chmod +x "$FRP_DIR/frps"
    else
        cp "/tmp/frp_${version}_${OS}_${ARCH}/frps" "$FRP_DIR/"
        chmod +x "$FRP_DIR/frps"
    fi
fi

if [ "$type" = "client" ] || [ "$type" = "both" ]; then
    if [ "$SYSTEM" = "macos" ]; then
        sudo cp "/tmp/frp_${version}_${OS}_${ARCH}/frpc" "$FRP_DIR/"
        sudo chmod +x "$FRP_DIR/frpc"
    else
        cp "/tmp/frp_${version}_${OS}_${ARCH}/frpc" "$FRP_DIR/"
        chmod +x "$FRP_DIR/frpc"
    fi
fi

rm -rf "/tmp/frp_${version}_${OS}_${ARCH}" "$temp_file"

echo -e "${GREEN}FRP下载完成${NC}"
```

}

# 创建系统服务

create_service() {
local service_type=$1
local service_name=“frp${service_type}”
local exec_name=“frp${service_type}”
local config_file=”$FRP_CONFIG_DIR/frp${service_type}.ini”

```
if [ "$SYSTEM" = "openwrt" ]; then
    # OpenWrt init.d脚本
    cat > "/etc/init.d/$service_name" <<EOF
```

#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
$FRP_DIR/$exec_name -c $config_file > $FRP_LOG_DIR/${exec_name}.log 2>&1 &
echo $! > /var/run/${service_name}.pid
}

stop() {
if [ -f /var/run/${service_name}.pid ]; then
kill $(cat /var/run/${service_name}.pid)
rm -f /var/run/${service_name}.pid
fi
}

restart() {
stop
sleep 1
start
}
EOF
chmod +x “/etc/init.d/$service_name”
/etc/init.d/$service_name enable
elif [ “$SYSTEM” = “macos” ]; then
# macOS launchd plist
local plist_file=”/Library/LaunchDaemons/com.frp.${service_name}.plist”
sudo tee “$plist_file” > /dev/null <<EOF

<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.frp.${service_name}</string>
    <key>ProgramArguments</key>
    <array>
        <string>$FRP_DIR/$exec_name</string>
        <string>-c</string>
        <string>$config_file</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$FRP_LOG_DIR/${exec_name}.log</string>
    <key>StandardErrorPath</key>
    <string>$FRP_LOG_DIR/${exec_name}.log</string>
</dict>
</plist>
EOF
        echo -e "${GREEN}macOS服务创建完成${NC}"
        echo -e "${YELLOW}使用以下命令管理服务:${NC}"
        echo "启动: sudo launchctl load -w $plist_file"
        echo "停止: sudo launchctl unload -w $plist_file"
    else
        # Systemd服务
        cat > "/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=FRP ${service_type} Service
After=network.target

[Service]
Type=simple
ExecStart=$FRP_DIR/$exec_name -c $config_file
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ${service_name}
fi
}

# 配置FRP服务器

configure_frps() {
echo -e “${BLUE}配置FRP服务器${NC}”

```
read -p "请输入监听端口 [7000]: " bind_port
bind_port=${bind_port:-7000}

read -p "请输入Dashboard端口 [7500]: " dashboard_port
dashboard_port=${dashboard_port:-7500}

read -p "请输入Dashboard用户名 [admin]: " dashboard_user
dashboard_user=${dashboard_user:-admin}

read -p "请输入Dashboard密码 [admin]: " dashboard_pwd
dashboard_pwd=${dashboard_pwd:-admin}

read -p "请输入Token [123456]: " token
token=${token:-123456}

if [ "$SYSTEM" = "macos" ]; then
    sudo tee "$FRPS_CONFIG" > /dev/null <<EOF
```

[common]
bind_port = $bind_port
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
token = $token
log_file = $FRPS_LOG
log_level = info
log_max_days = 7
EOF
else
cat > “$FRPS_CONFIG” <<EOF
[common]
bind_port = $bind_port
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
token = $token
log_file = $FRPS_LOG
log_level = info
log_max_days = 7
EOF
fi

```
echo -e "${GREEN}FRP服务器配置完成${NC}"
```

}

# 配置FRP客户端

configure_frpc() {
echo -e “${BLUE}配置FRP客户端${NC}”

```
read -p "请输入服务器地址: " server_addr
if [ -z "$server_addr" ]; then
    echo -e "${RED}服务器地址不能为空${NC}"
    return 1
fi

read -p "请输入服务器端口 [7000]: " server_port
server_port=${server_port:-7000}

read -p "请输入Token [123456]: " token
token=${token:-123456}

if [ "$SYSTEM" = "macos" ]; then
    sudo tee "$FRPC_CONFIG" > /dev/null <<EOF
```

[common]
server_addr = $server_addr
server_port = $server_port
token = $token
log_file = $FRPC_LOG
log_level = info
log_max_days = 7

# 示例配置

# [ssh]

# type = tcp

# local_ip = 127.0.0.1

# local_port = 22

# remote_port = 6000

# [web]

# type = http

# local_port = 80

# custom_domains = www.example.com

EOF
else
cat > “$FRPC_CONFIG” <<EOF
[common]
server_addr = $server_addr
server_port = $server_port
token = $token
log_file = $FRPC_LOG
log_level = info
log_max_days = 7

# 示例配置

# [ssh]

# type = tcp

# local_ip = 127.0.0.1

# local_port = 22

# remote_port = 6000

# [web]

# type = http

# local_port = 80

# custom_domains = www.example.com

EOF
fi

```
echo -e "${GREEN}FRP客户端基础配置完成${NC}"
echo -e "${YELLOW}请编辑 $FRPC_CONFIG 添加具体的代理规则${NC}"
```

}

# 添加客户端规则

add_client_rule() {
echo -e “${BLUE}添加客户端代理规则${NC}”

```
read -p "请输入规则名称: " rule_name
if [ -z "$rule_name" ]; then
    echo -e "${RED}规则名称不能为空${NC}"
    return 1
fi

echo "请选择代理类型:"
echo "1) TCP"
echo "2) HTTP"
echo "3) HTTPS"
echo "4) UDP"
read -p "请选择 [1-4]: " proxy_type

case $proxy_type in
    1)
        type="tcp"
        read -p "请输入本地IP [127.0.0.1]: " local_ip
        local_ip=${local_ip:-127.0.0.1}
        read -p "请输入本地端口: " local_port
        read -p "请输入远程端口: " remote_port
        
        if [ "$SYSTEM" = "macos" ]; then
            sudo tee -a "$FRPC_CONFIG" > /dev/null <<EOF
```

[$rule_name]
type = $type
local_ip = $local_ip
local_port = $local_port
remote_port = $remote_port
EOF
else
cat >> “$FRPC_CONFIG” <<EOF

[$rule_name]
type = $type
local_ip = $local_ip
local_port = $local_port
remote_port = $remote_port
EOF
fi
;;
2)
type=“http”
read -p “请输入本地端口: “ local_port
read -p “请输入自定义域名: “ custom_domains

```
        if [ "$SYSTEM" = "macos" ]; then
            sudo tee -a "$FRPC_CONFIG" > /dev/null <<EOF
```

[$rule_name]
type = $type
local_port = $local_port
custom_domains = $custom_domains
EOF
else
cat >> “$FRPC_CONFIG” <<EOF

[$rule_name]
type = $type
local_port = $local_port
custom_domains = $custom_domains
EOF
fi
;;
3)
type=“https”
read -p “请输入本地端口: “ local_port
read -p “请输入自定义域名: “ custom_domains

```
        if [ "$SYSTEM" = "macos" ]; then
            sudo tee -a "$FRPC_CONFIG" > /dev/null <<EOF
```

[$rule_name]
type = $type
local_port = $local_port
custom_domains = $custom_domains
EOF
else
cat >> “$FRPC_CONFIG” <<EOF

[$rule_name]
type = $type
local_port = $local_port
custom_domains = $custom_domains
EOF
fi
;;
4)
type=“udp”
read -p “请输入本地IP [127.0.0.1]: “ local_ip
local_ip=${local_ip:-127.0.0.1}
read -p “请输入本地端口: “ local_port
read -p “请输入远程端口: “ remote_port

```
        if [ "$SYSTEM" = "macos" ]; then
            sudo tee -a "$FRPC_CONFIG" > /dev/null <<EOF
```

[$rule_name]
type = $type
local_ip = $local_ip
local_port = $local_port
remote_port = $remote_port
EOF
else
cat >> “$FRPC_CONFIG” <<EOF

[$rule_name]
type = $type
local_ip = $local_ip
local_port = $local_port
remote_port = $remote_port
EOF
fi
;;
*)
echo -e “${RED}无效的选择${NC}”
return 1
;;
esac

```
echo -e "${GREEN}规则添加成功${NC}"
```

}

# 查看服务状态

check_status() {
local service=$1

```
if [ "$SYSTEM" = "openwrt" ]; then
    if [ -f "/var/run/frp${service}.pid" ] && kill -0 $(cat /var/run/frp${service}.pid) 2>/dev/null; then
        echo -e "${GREEN}FRP${service} 正在运行${NC}"
        echo "PID: $(cat /var/run/frp${service}.pid)"
    else
        echo -e "${RED}FRP${service} 未运行${NC}"
    fi
elif [ "$SYSTEM" = "macos" ]; then
    if sudo launchctl list | grep -q "com.frp.frp${service}"; then
        echo -e "${GREEN}FRP${service} 正在运行${NC}"
        sudo launchctl list | grep "com.frp.frp${service}"
    else
        echo -e "${RED}FRP${service} 未运行${NC}"
    fi
else
    systemctl status frp${service} --no-pager
fi
```

}

# 查看日志

view_logs() {
local service=$1
local log_file=”$FRP_LOG_DIR/frp${service}.log”

```
if [ -f "$log_file" ]; then
    echo -e "${BLUE}=== FRP${service} 日志 ===${NC}"
    if [ "$SYSTEM" = "macos" ]; then
        sudo tail -n 50 "$log_file"
    else
        tail -n 50 "$log_file"
    fi
else
    echo -e "${YELLOW}日志文件不存在${NC}"
fi
```

}

# 查看管理面板和连接信息

view_dashboard() {
echo -e “${BLUE}=== FRP管理信息 ===${NC}”

```
# 检查FRPS状态
if [ -f "$FRPS_CONFIG" ]; then
    if [ "$SYSTEM" = "macos" ]; then
        local dashboard_port=$(sudo grep "dashboard_port" "$FRPS_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        local bind_port=$(sudo grep "bind_port" "$FRPS_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    else
        local dashboard_port=$(grep "dashboard_port" "$FRPS_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        local bind_port=$(grep "bind_port" "$FRPS_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    fi
    
    echo -e "${GREEN}FRP服务器信息:${NC}"
    echo "监听端口: $bind_port"
    echo "Dashboard地址: http://localhost:$dashboard_port"
    
    # 显示连接的客户端
    if [ "$SYSTEM" = "openwrt" ]; then
        if [ -f "/var/run/frps.pid" ] && kill -0 $(cat /var/run/frps.pid) 2>/dev/null; then
            echo -e "\n${GREEN}已连接的客户端:${NC}"
            netstat -tn 2>/dev/null | grep ":$bind_port" | grep ESTABLISHED | awk '{print $5}' | cut -d':' -f1 | sort | uniq
        fi
    elif [ "$SYSTEM" = "macos" ]; then
        if sudo launchctl list | grep -q "com.frp.frps"; then
            echo -e "\n${GREEN}已连接的客户端:${NC}"
            sudo lsof -i :$bind_port | grep ESTABLISHED | awk '{print $9}' | cut -d':' -f1 | cut -d'>' -f2 | sort | uniq
        fi
    else
        if systemctl is-active frps >/dev/null 2>&1; then
            echo -e "\n${GREEN}已连接的客户端:${NC}"
            ss -tn state established "( sport = :$bind_port )" | tail -n +2 | awk '{print $4}' | cut -d':' -f1 | sort | uniq
        fi
    fi
fi

# 检查FRPC状态
if [ -f "$FRPC_CONFIG" ]; then
    if [ "$SYSTEM" = "macos" ]; then
        local server_addr=$(sudo grep "server_addr" "$FRPC_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        local server_port=$(sudo grep "server_port" "$FRPC_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    else
        local server_addr=$(grep "server_addr" "$FRPC_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        local server_port=$(grep "server_port" "$FRPC_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    fi
    
    echo -e "\n${GREEN}FRP客户端信息:${NC}"
    echo "服务器地址: $server_addr:$server_port"
    
    # 显示配置的规则
    echo -e "\n${GREEN}配置的代理规则:${NC}"
    if [ "$SYSTEM" = "macos" ]; then
        sudo grep "^\[" "$FRPC_CONFIG" | grep -v "\[common\]" | tr -d '[]'
    else
        grep "^\[" "$FRPC_CONFIG" | grep -v "\[common\]" | tr -d '[]'
    fi
fi
```

}

# 启动服务

start_service() {
local service=$1

```
if [ "$SYSTEM" = "openwrt" ]; then
    /etc/init.d/frp${service} start
elif [ "$SYSTEM" = "macos" ]; then
    sudo launchctl load -w "/Library/LaunchDaemons/com.frp.frp${service}.plist"
else
    systemctl start frp${service}
fi

echo -e "${GREEN}FRP${service} 启动完成${NC}"
```

}

# 停止服务

stop_service() {
local service=$1

```
if [ "$SYSTEM" = "openwrt" ]; then
    /etc/init.d/frp${service} stop
elif [ "$SYSTEM" = "macos" ]; then
    sudo launchctl unload -w "/Library/LaunchDaemons/com.frp.frp${service}.plist"
else
    systemctl stop frp${service}
fi

echo -e "${GREEN}FRP${service} 停止完成${NC}"
```

}

# 重启服务

restart_service() {
local service=$1

```
if [ "$SYSTEM" = "openwrt" ]; then
    /etc/init.d/frp${service} restart
elif [ "$SYSTEM" = "macos" ]; then
    stop_service $service
    sleep 1
    start_service $service
else
    systemctl restart frp${service}
fi

echo -e "${GREEN}FRP${service} 重启完成${NC}"
```

}

# 卸载FRP

uninstall_frp() {
echo -e “${RED}确定要卸载FRP吗？这将删除所有配置和日志文件。${NC}”
read -p “输入 ‘yes’ 确认卸载: “ confirm

```
if [ "$confirm" != "yes" ]; then
    echo "取消卸载"
    return
fi

# 停止服务
if [ "$SYSTEM" = "openwrt" ]; then
    [ -f "/etc/init.d/frps" ] && /etc/init.d/frps stop && /etc/init.d/frps disable
    [ -f "/etc/init.d/frpc" ] && /etc/init.d/frpc stop && /etc/init.d/frpc disable
    rm -f /etc/init.d/frps /etc/init.d/frpc
elif [ "$SYSTEM" = "macos" ]; then
    sudo launchctl unload -w "/Library/LaunchDaemons/com.frp.frps.plist" 2>/dev/null
    sudo launchctl unload -w "/Library/LaunchDaemons/com.frp.frpc.plist" 2>/dev/null
    sudo rm -f /Library/LaunchDaemons/com.frp.frps.plist
    sudo rm -f /Library/LaunchDaemons/com.frp.frpc.plist
else
    systemctl stop frps frpc 2>/dev/null
    systemctl disable frps frpc 2>/dev/null
    rm -f /etc/systemd/system/frps.service /etc/systemd/system/frpc.service
    systemctl daemon-reload
fi

# 删除文件
if [ "$SYSTEM" = "macos" ]; then
    sudo rm -rf $FRP_DIR
    sudo rm -rf $FRP_CONFIG_DIR
    sudo rm -rf $FRP_LOG_DIR
else
    rm -rf $FRP_DIR
    rm -rf $FRP_CONFIG_DIR
    rm -rf $FRP_LOG_DIR
fi

echo -e "${GREEN}FRP卸载完成${NC}"
```

}

# 主菜单

main_menu() {
clear
echo -e “${BLUE}==================================${NC}”
echo -e “${BLUE}       FRP 管理脚本 v1.0          ${NC}”
echo -e “${BLUE}==================================${NC}”
echo -e “${GREEN}系统: $SYSTEM | 架构: $ARCH${NC}”
echo -e “${BLUE}==================================${NC}”
echo “1) 安装 FRP 服务端”
echo “2) 安装 FRP 客户端”
echo “3) 安装 FRP 服务端+客户端”
echo “4) 配置 FRP 服务端”
echo “5) 配置 FRP 客户端”
echo “6) 添加客户端代理规则”
echo “7) 启动 FRP 服务端”
echo “8) 启动 FRP 客户端”
echo “9) 停止 FRP 服务端”
echo “10) 停止 FRP 客户端”
echo “11) 重启 FRP 服务端”
echo “12) 重启 FRP 客户端”
echo “13) 查看 FRP 服务端状态”
echo “14) 查看 FRP 客户端状态”
echo “15) 查看 FRP 服务端日志”
echo “16) 查看 FRP 客户端日志”
echo “17) 编辑服务端配置”
echo “18) 编辑客户端配置”
echo “19) 卸载 FRP”
echo “f) 查看管理面板信息”
echo “0) 退出”
echo -e “${BLUE}==================================${NC}”

```
read -p "请选择操作: " choice

case $choice in
    1)
        check_arch
        create_dirs
        read -p "请输入FRP版本号 [0.51.3]: " version
        version=${version:-0.51.3}
        download_frp "$version" "server" && \
        configure_frps && \
        create_service "s"
        ;;
    2)
        check_arch
        create_dirs
        read -p "请输入FRP版本号 [0.51.3]: " version
        version=${version:-0.51.3}
        download_frp "$version" "client" && \
        configure_frpc && \
        create_service "c"
        ;;
    3)
        check_arch
        create_dirs
        read -p "请输入FRP版本号 [0.51.3]: " version
        version=${version:-0.51.3}
        download_frp "$version" "both" && \
        configure_frps && \
        configure_frpc && \
        create_service "s" && \
        create_service "c"
        ;;
    4)
        configure_frps
        ;;
    5)
        configure_frpc
        ;;
    6)
        add_client_rule
        ;;
    7)
        start_service "s"
        ;;
    8)
        start_service "c"
        ;;
    9)
        stop_service "s"
        ;;
    10)
        stop_service "c"
        ;;
    11)
        restart_service "s"
        ;;
    12)
        restart_service "c"
        ;;
    13)
        check_status "s"
        ;;
    14)
        check_status "c"
        ;;
    15)
        view_logs "s"
        ;;
    16)
        view_logs "c"
        ;;
    17)
        if [ "$SYSTEM" = "macos" ]; then
            sudo ${EDITOR:-vi} "$FRPS_CONFIG"
        else
            ${EDITOR:-vi} "$FRPS_CONFIG"
        fi
        ;;
    18)
        if [ "$SYSTEM" = "macos" ]; then
            sudo ${EDITOR:-vi} "$FRPC_CONFIG"
        else
            ${EDITOR:-vi} "$FRPC_CONFIG"
        fi
        ;;
    19)
        uninstall_frp
        ;;
    f|F)
        view_dashboard
        ;;
    0)
        echo "退出脚本"
        exit 0
        ;;
    *)
        echo -e "${RED}无效的选择${NC}"
        ;;
esac

echo
read -p "按回车键继续..." -n1 -s
main_menu
```

}

# 初始化

check_system

# 检查权限

if [ “$SYSTEM” != “macos” ] && [ $EUID -ne 0 ]; then
echo -e “${RED}此脚本需要root权限运行${NC}”
exit 1
fi

# 运行主菜单

main_menu
