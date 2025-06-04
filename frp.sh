#!/bin/bash
set -e

FRP_VERSION=“0.52.3”
INSTALL_DIR=”/opt/frp”
CONFIG_DIR=”/etc/frp”

echo_info() {
echo “[INFO] $1”
}

echo_success() {
echo “[SUCCESS] $1”
}

echo_error() {
echo “[ERROR] $1”
}

detect_system() {
if [ -f /etc/openwrt_release ]; then
OS_TYPE=“openwrt”
elif [ “$(uname)” = “Darwin” ]; then
OS_TYPE=“darwin”
else
OS_TYPE=“linux”
fi

```
case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armv6l) ARCH="arm" ;;
    *) echo_error "不支持的架构"; exit 1 ;;
esac
echo_success "系统: $OS_TYPE-$ARCH"
```

}

download_frp() {
detect_system
filename=“frp_${FRP_VERSION}*${OS_TYPE}*${ARCH}”
url=“https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${filename}.tar.gz”

```
echo_info "下载 FRP..."
temp_dir="/tmp/frp_$$"
mkdir -p "$temp_dir"
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
cd /
rm -rf "$temp_dir"
echo_success "安装完成"
```

}

config_server() {
echo_info “配置服务端…”
printf “端口 [7000]: “
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
mkdir -p /var/log
touch /var/log/frps.log
make_service "frps"
echo_success "服务端配置完成"
```

}

config_client() {
echo_info “配置客户端…”
printf “服务器地址: “
read server

```
printf "端口 [7000]: "
read port
port=${port:-7000}

printf "Token: "
read token

printf "本地端口: "
read local_port

printf "远程端口: "
read remote_port

printf "服务名 [ssh]: "
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
mkdir -p /var/log
touch /var/log/frpc.log
make_service "frpc"
echo_success "客户端配置完成"
```

}

make_service() {
service=$1
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
“/etc/init.d/$service” enable
“/etc/init.d/$service” start
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
systemctl enable “$service”
systemctl start “$service”
fi
echo_success “$service 启动完成”
}

panel_info() {
if [ ! -f “$CONFIG_DIR/frps.ini” ]; then
echo_error “未找到服务端配置”
return
fi

```
port=$(grep dashboard_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
user=$(grep dashboard_user "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
pwd=$(grep dashboard_pwd "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
ip=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_IP")

clear
echo "========================="
echo "FRP 管理面板"
echo "========================="
echo "地址: http://$ip:$port"
echo "用户: $user"
echo "密码: $pwd"
echo "========================="

if [ -f "/var/log/frps.log" ]; then
    echo "最近连接的客户端IP:"
    tail -20 /var/log/frps.log | grep "login from" | tail -5 | while read line; do
        client_ip=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
        if [ -n "$client_ip" ]; then
            echo "  $client_ip"
        fi
    done
    
    echo ""
    echo "当前活跃连接:"
    bind_port=$(grep bind_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    netstat -tn 2>/dev/null | grep ":$bind_port.*ESTABLISHED" | while read line; do
        echo "  $(echo $line | awk '{print $5}' | cut -d: -f1)"
    done
    
    echo ""
    echo "活跃代理:"
    tail -20 /var/log/frps.log | grep "proxy added" | tail -5
    echo "========================="
fi

printf "按回车返回..."
read dummy
```

}

check_status() {
echo “=== FRP 状态 ===”

```
for service in frps frpc; do
    if [ -f "$CONFIG_DIR/$service.ini" ]; then
        printf "$service: "
        if [ "$OS_TYPE" = "openwrt" ]; then
            if pgrep -f "$service" >/dev/null; then
                echo "运行中"
            else
                echo "未运行"
            fi
        else
            if systemctl is-active "$service" >/dev/null 2>&1; then
                echo "运行中"
            else
                echo "未运行"
            fi
        fi
    fi
done

if [ -f "/var/log/frps.log" ]; then
    echo ""
    echo "连接统计:"
    today=$(date '+%Y/%m/%d')
    count=$(grep "$today" /var/log/frps.log | grep -c "login from" 2>/dev/null || echo "0")
    echo "  今日连接: $count 次"
    
    bind_port=$(grep bind_port "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    active=$(netstat -tn 2>/dev/null | grep -c ":$bind_port.*ESTABLISHED" || echo "0")
    echo "  活跃连接: $active 个"
fi

if [ -f "/var/log/frpc.log" ]; then
    echo ""
    echo "客户端日志:"
    tail -3 /var/log/frpc.log
fi
```

}

restart_all() {
for service in frps frpc; do
if [ -f “$CONFIG_DIR/$service.ini” ]; then
if [ “$OS_TYPE” = “openwrt” ]; then
“/etc/init.d/$service” restart
else
systemctl restart “$service”
fi
echo_success “$service 重启完成”
fi
done
}

show_logs() {
echo “1. frps日志  2. frpc日志”
printf “选择: “
read choice
case $choice in
1)
if [ -f /var/log/frps.log ]; then
tail -f /var/log/frps.log
else
echo “日志不存在”
fi
;;
2)
if [ -f /var/log/frpc.log ]; then
tail -f /var/log/frpc.log
else
echo “日志不存在”
fi
;;
esac
}

remove_all() {
printf “确定卸载? (yes/no): “
read confirm
if [ “$confirm” = “yes” ]; then
for service in frps frpc; do
if [ “$OS_TYPE” = “openwrt” ]; then
“/etc/init.d/$service” stop 2>/dev/null || true
rm -f “/etc/init.d/$service”
else
systemctl stop “$service” 2>/dev/null || true
systemctl disable “$service” 2>/dev/null || true
rm -f “/etc/systemd/system/$service.service”
fi
done

```
    rm -rf "$INSTALL_DIR" "$CONFIG_DIR"
    rm -f /var/log/frp*.log
    
    if [ "$OS_TYPE" != "openwrt" ]; then
        systemctl daemon-reload
    fi
    
    echo_success "卸载完成"
fi
```

}

while true; do
clear
echo “===============================”
echo “    FRP 管理脚本 v1.0”
echo “===============================”
echo “1. 安装服务端”
echo “2. 安装客户端”
echo “3. 查看状态”
echo “4. 重启服务”
echo “5. 查看日志”
echo “6. 卸载”
echo “f. 管理面板”
echo “0. 退出”
echo “===============================”
printf “选择: “
read choice

```
case $choice in
    1)
        download_frp
        config_server
        printf "按回车继续..."
        read dummy
        ;;
    2)
        download_frp
        config_client
        printf "按回车继续..."
        read dummy
        ;;
    3)
        check_status
        printf "按回车继续..."
        read dummy
        ;;
    4)
        restart_all
        printf "按回车继续..."
        read dummy
        ;;
    5)
        show_logs
        ;;
    6)
        remove_all
        printf "按回车继续..."
        read dummy
        ;;
    f|F)
        panel_info
        ;;
    0)
        exit 0
        ;;
    *)
        echo "无效选择"
        sleep 1
        ;;
esac
```

done
