#!/bin/bash
set -e

# 全局变量

FRP_VERSION=“0.52.3”
INSTALL_DIR=”/opt/frp”
CONFIG_DIR=”/etc/frp”

print_info() { echo “[INFO] $1”; }
print_success() { echo “[SUCCESS] $1”; }
print_error() { echo “[ERROR] $1”; }

# 检测系统

detect_system() {
if [ -f /etc/openwrt_release ]; then
OS_TYPE=“openwrt”
elif [ “$(uname)” = “Darwin” ]; then
OS_TYPE=“darwin”
else
OS_TYPE=“linux”
fi

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
printf “绑定端口 [7000]: “
read port
port=${port:-7000}

```
printf "面板端口 [7500]: "
read dash_port
dash_port=${dash_port:-7500}

printf "用户名 [admin]: "
read user
user=${user:-admin}

printf "密码: "
read pwd

printf "Token: "
read token

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
printf “服务器地址: “
read server

```
printf "服务器端口 [7000]: "
read port
port=${port:-7000}

printf "Token: "
read token

printf "本地端口: "
read local_port

printf "远程端口: "
read remote_port

printf "服务名称 [ssh]: "
read name
name=${name:-ssh}

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
print_error “未找到服务端配置”
return
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
    echo "最近连接的客户端IP:"
    tail -20 /var/log/frps.log | grep "login from" | tail -5 | while IFS= read -r line; do
        client_ip=$(echo "$line" | awk '{print $NF}')
        echo "  $client_ip"
    done
    
    echo ""
    echo "活跃代理:"
    tail -20 /var/log/frps.log | grep "proxy added" | tail -5 | while IFS= read -r line; do
        echo "  $line"
    done
    
    echo ""
    local bind_port=$(grep bind_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    local connections=$(netstat -tn 2>/dev/null | grep ":$bind_port.*ESTABLISHED" | wc -l)
    echo "当前连接数: $connections"
    echo "========================="
fi
printf "按回车返回..."
read dummy
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
if [ -f "$CONFIG_DIR/frps.ini" ] && [ -f "/var/log/frps.log" ]; then
    echo ""
    echo "连接的客户端IP:"
    local bind_port=$(grep bind_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    netstat -tn 2>/dev/null | grep ":$bind_port.*ESTABLISHED" | while IFS= read -r line; do
        client_ip=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
        echo "  来自: $client_ip"
    done
    
    echo ""
    echo "最近日志:"
    tail -5 /var/log/frps.log | while IFS= read -r line; do
        echo "  $line"
    done
fi

if [ -f "$CONFIG_DIR/frpc.ini" ] && [ -f "/var/log/frpc.log" ]; then
    echo ""
    echo "客户端状态:"
    local server_addr=$(grep server_addr "$CONFIG_DIR/frpc.ini" | cut -d'=' -f2 | tr -d ' ')
    local server_port=$(grep server_port "$CONFIG_DIR/frpc.ini" | cut -d'=' -f2 | tr -d ' ')
    echo "  连接到: $server_addr:$server_port"
    
    if netstat -tn 2>/dev/null | grep -q "$server_addr:$server_port.*ESTABLISHED"; then
        echo "  状态: 已连接"
    else
        echo "  状态: 未连接"
    fi
    
    echo ""
    echo "客户端日志:"
    tail -3 /var/log/frpc.log | while IFS= read -r line; do
        echo "  $line"
    done
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
printf “选择: “
read choice
case $choice in
1)
if [ -f /var/log/frps.log ]; then
tail -f /var/log/frps.log
else
print_error “frps日志文件不存在”
fi
;;
2)
if [ -f /var/log/frpc.log ]; then
tail -f /var/log/frpc.log
else
print_error “frpc日志文件不存在”
fi
;;
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
printf “请选择: “
read choice

```
    case $choice in
        1) install_frp && setup_server ;;
        2) install_frp && setup_client ;;
        3) show_status; printf "按回车继续..."; read dummy ;;
        4) restart_services; printf "按回车继续..."; read dummy ;;
        5) view_logs ;;
        f|F) quick_panel ;;
        0) exit 0 ;;
        *) print_error "无效选择"; sleep 1 ;;
    esac
done
```

}

# 启动

main_menu
