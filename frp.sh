#!/bin/bash
set -e

# 颜色定义

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
BLUE=’\033[0;34m’
NC=’\033[0m’

# 全局变量

FRP_VERSION=“0.52.3”
INSTALL_DIR=”/opt/frp”
CONFIG_DIR=”/etc/frp”

print_info() { printf “%b[INFO]%b %s\n” “$BLUE” “$NC” “$1”; }
print_success() { printf “%b[SUCCESS]%b %s\n” “$GREEN” “$NC” “$1”; }
print_error() { printf “%b[ERROR]%b %s\n” “$RED” “$NC” “$1”; }

# 检测系统

detect_system() {
if [ -f /etc/openwrt_release ]; then OS_TYPE=“openwrt”
elif [ “$(uname)” = “Darwin” ]; then OS_TYPE=“darwin”
else OS_TYPE=“linux”; fi

```
case $(uname -m) in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armv6l) ARCH="arm" ;;
    *) print_error "不支持的架构"; exit 1 ;;
esac
print_success "系统: $OS_TYPE, 架构: $ARCH"
```

}

# 下载安装

install_frp() {
detect_system
local filename=“frp_${FRP_VERSION}*${OS_TYPE}*${ARCH}”
local url=“https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${filename}.tar.gz”

```
print_info "下载 FRP..."
local temp_dir=$(mktemp -d)
cd "$temp_dir"

if command -v wget >/dev/null; then
    wget -O frp.tar.gz "$url"
else
    curl -L -o frp.tar.gz "$url"
fi

tar -xzf frp.tar.gz
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
cp "${filename}"/frp* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/frp*
cd / && rm -rf "$temp_dir"
print_success "FRP 安装完成"
```

}

# 服务端配置

setup_server() {
print_info “配置服务端…”
read -p “端口 [7000]: “ port; port=${port:-7000}
read -p “面板端口 [7500]: “ dash_port; dash_port=${dash_port:-7500}
read -p “用户名 [admin]: “ user; user=${user:-admin}
read -p “密码: “ pwd
read -p “Token: “ token

```
cat > "$CONFIG_DIR/frps.ini" <<EOF
```

[common]
bind_port = $port
dashboard_port = $dash_port
dashboard_user = $user
dashboard_pwd = $pwd
authentication_method = token
token = $token
log_file = /var/log/frps.log
log_level = info
max_clients = 50
allow_ports = 1000-65535
EOF

```
mkdir -p /var/log && touch /var/log/frps.log
create_service "frps"
print_success "服务端配置完成"
```

}

# 客户端配置

setup_client() {
print_info “配置客户端…”
read -p “服务器地址: “ server
read -p “服务器端口 [7000]: “ port; port=${port:-7000}
read -p “Token: “ token
read -p “本地端口: “ local_port
read -p “远程端口: “ remote_port
read -p “服务名称 [ssh]: “ name; name=${name:-ssh}

```
cat > "$CONFIG_DIR/frpc.ini" <<EOF
```

[common]
server_addr = $server
server_port = $port
authentication_method = token
token = $token
log_file = /var/log/frpc.log
log_level = info

[$name]
type = tcp
local_ip = 127.0.0.1
local_port = $local_port
remote_port = $remote_port
EOF

```
mkdir -p /var/log && touch /var/log/frpc.log
create_service "frpc"
print_success "客户端配置完成"
```

}

# 创建服务

create_service() {
local service=$1
if [ “$OS_TYPE” = “openwrt” ]; then
cat > “/etc/init.d/$service” <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
procd_open_instance
procd_set_param command $INSTALL_DIR/$service -c $CONFIG_DIR/$service.ini
procd_set_param respawn
procd_close_instance
}
EOF
chmod +x “/etc/init.d/$service”
“/etc/init.d/$service” enable && “/etc/init.d/$service” start
else
cat > “/etc/systemd/system/$service.service” <<EOF
[Unit]
Description=FRP $service
After=network.target

[Service]
Type=simple
Restart=on-failure
ExecStart=$INSTALL_DIR/$service -c $CONFIG_DIR/$service.ini

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable “$service” && systemctl start “$service”
fi
print_success “$service 服务已启动”
}

# 快速面板

quick_panel() {
if [ ! -f “$CONFIG_DIR/frps.ini” ]; then
print_error “未找到服务端配置”; return
fi

```
local port=$(grep dashboard_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
local user=$(grep dashboard_user "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
local pwd=$(grep dashboard_pwd "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
local ip=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_IP")

echo "========================="
echo "FRP 管理面板"
echo "========================="
echo "地址: http://$ip:$port"
echo "用户: $user"
echo "密码: $pwd"
echo "========================="

# 显示连接信息
if [ -f "/var/log/frps.log" ]; then
    echo "最近连接:"
    tail -10 /var/log/frps.log | grep "login from\|proxy added" | tail -5
    echo "========================="
fi
read -p "按回车返回..."
```

}

# 查看状态

show_status() {
echo “=== FRP 状态 ===”
for service in frps frpc; do
if [ -f “$CONFIG_DIR/$service.ini” ]; then
printf “$service: “
if [ “$OS_TYPE” = “openwrt” ]; then
“/etc/init.d/$service” status 2>/dev/null || echo “未运行”
else
systemctl is-active “$service” 2>/dev/null || echo “未运行”
fi
fi
done

```
# 显示连接详情
if [ -f "/var/log/frps.log" ]; then
    echo ""
    echo "活跃连接:"
    local bind_port=$(grep bind_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    netstat -tn 2>/dev/null | grep ":$bind_port.*ESTABLISHED" | while read line; do
        echo "  $(echo $line | awk '{print $5}' | cut -d: -f1)"
    done
fi

if [ -f "/var/log/frpc.log" ]; then
    echo ""
    echo "客户端日志:"
    tail -3 /var/log/frpc.log
fi
```

}

# 重启服务

restart_services() {
for service in frps frpc; do
if [ -f “$CONFIG_DIR/$service.ini” ]; then
if [ “$OS_TYPE” = “openwrt” ]; then
“/etc/init.d/$service” restart
else
systemctl restart “$service”
fi
print_success “$service 已重启”
fi
done
}

# 查看日志

view_logs() {
echo “1. frps日志  2. frpc日志”
read -p “选择: “ choice
case $choice in
1) [ -f /var/log/frps.log ] && tail -f /var/log/frps.log ;;
2) [ -f /var/log/frpc.log ] && tail -f /var/log/frpc.log ;;
esac
}

# 主菜单

main_menu() {
while true; do
clear
echo “===============================”
echo “    FRP 一键管理脚本 v1.0”
echo “===============================”
echo “1. 安装服务端”
echo “2. 安装客户端”
echo “3. 查看状态”
echo “4. 重启服务”
echo “5. 查看日志”
echo “f. 快速面板”
echo “0. 退出”
echo “===============================”
read -p “请选择: “ choice

```
    case $choice in
        1) install_frp && setup_server ;;
        2) install_frp && setup_client ;;
        3) show_status; read -p "按回车继续..." ;;
        4) restart_services; read -p "按回车继续..." ;;
        5) view_logs ;;
        f|F) quick_panel ;;
        0) exit 0 ;;
        *) print_error "无效选择" ;;
    esac
done
```

}

# 启动

main_menu
