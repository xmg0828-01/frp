#!/bin/bash

# FRP 管理脚本 - 全新版本

# 避免语法错误，使用最基础的shell语法

FRP_VERSION=“0.52.3”

show_info() {
echo “[INFO] $1”
}

show_success() {
echo “[SUCCESS] $1”
}

show_error() {
echo “[ERROR] $1”
}

# 获取系统架构

get_arch() {
arch_name=$(uname -m)
if test “$arch_name” = “x86_64”; then
echo “amd64”
elif test “$arch_name” = “aarch64”; then
echo “arm64”
elif test “$arch_name” = “armv7l”; then
echo “arm”
else
echo “amd64”
fi
}

# 获取操作系统

get_os() {
if test -f /etc/openwrt_release; then
echo “openwrt”
elif test “$(uname)” = “Darwin”; then
echo “darwin”
else
echo “linux”
fi
}

# 下载安装FRP

install_frp() {
os_type=$(get_os)
arch_type=$(get_arch)

```
show_info "下载 FRP $FRP_VERSION for $os_type-$arch_type"

filename="frp_${FRP_VERSION}_${os_type}_${arch_type}"
url="https://github.com/fatedier/frp/releases/download/v$FRP_VERSION/${filename}.tar.gz"

cd /tmp
if command -v wget >/dev/null 2>&1; then
    wget -q "$url"
else
    curl -s -L -O "$url"
fi

tar -xzf "${filename}.tar.gz"

mkdir -p /opt/frp
mkdir -p /etc/frp

cp "${filename}/frps" /opt/frp/
cp "${filename}/frpc" /opt/frp/
chmod +x /opt/frp/frps
chmod +x /opt/frp/frpc

rm -rf "${filename}"*

show_success "FRP 安装完成"
```

}

# 配置服务端

setup_server() {
show_info “配置 FRP 服务端”

```
printf "服务端口 [7000]: "
read server_port
if test -z "$server_port"; then
    server_port="7000"
fi

printf "管理面板端口 [7500]: "
read dash_port
if test -z "$dash_port"; then
    dash_port="7500"
fi

printf "管理员用户名 [admin]: "
read admin_user
if test -z "$admin_user"; then
    admin_user="admin"
fi

printf "管理员密码: "
read admin_pass

printf "连接Token: "
read auth_token

# 创建配置文件
cat > /etc/frp/frps.ini << EOF
```

[common]
bind_port = $server_port
dashboard_port = $dash_port
dashboard_user = $admin_user
dashboard_pwd = $admin_pass
authentication_method = token
token = $auth_token
log_file = /var/log/frps.log
log_level = info
max_clients = 100
allow_ports = 1000-65535
EOF

```
mkdir -p /var/log
touch /var/log/frps.log

# 创建服务
os_type=$(get_os)
if test "$os_type" = "openwrt"; then
    cat > /etc/init.d/frps << 'INITD_EOF'
```

#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
procd_open_instance
procd_set_param command /opt/frp/frps -c /etc/frp/frps.ini
procd_set_param respawn
procd_close_instance
}
INITD_EOF
chmod +x /etc/init.d/frps
/etc/init.d/frps enable
/etc/init.d/frps start
else
cat > /etc/systemd/system/frps.service << SYSTEMD_EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
ExecStart=/opt/frp/frps -c /etc/frp/frps.ini
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF
systemctl daemon-reload
systemctl enable frps
systemctl start frps
fi

```
show_success "服务端配置完成"
```

}

# 配置客户端

setup_client() {
show_info “配置 FRP 客户端”

```
printf "服务器地址: "
read server_addr

printf "服务器端口 [7000]: "
read server_port
if test -z "$server_port"; then
    server_port="7000"
fi

printf "连接Token: "
read auth_token

printf "本地端口: "
read local_port

printf "远程端口: "
read remote_port

printf "服务名称 [ssh]: "
read service_name
if test -z "$service_name"; then
    service_name="ssh"
fi

# 创建配置文件
cat > /etc/frp/frpc.ini << EOF
```

[common]
server_addr = $server_addr
server_port = $server_port
authentication_method = token
token = $auth_token
log_file = /var/log/frpc.log
log_level = info

[$service_name]
type = tcp
local_ip = 127.0.0.1
local_port = $local_port
remote_port = $remote_port
EOF

```
mkdir -p /var/log
touch /var/log/frpc.log

# 创建服务
os_type=$(get_os)
if test "$os_type" = "openwrt"; then
    cat > /etc/init.d/frpc << 'INITD_EOF'
```

#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
procd_open_instance
procd_set_param command /opt/frp/frpc -c /etc/frp/frpc.ini
procd_set_param respawn
procd_close_instance
}
INITD_EOF
chmod +x /etc/init.d/frpc
/etc/init.d/frpc enable
/etc/init.d/frpc start
else
cat > /etc/systemd/system/frpc.service << SYSTEMD_EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
Type=simple
ExecStart=/opt/frp/frpc -c /etc/frp/frpc.ini
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc
fi

```
show_success "客户端配置完成"
```

}

# 显示管理面板信息

show_dashboard() {
if test ! -f /etc/frp/frps.ini; then
show_error “未找到服务端配置文件”
return
fi

```
dash_port=$(grep "dashboard_port" /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
admin_user=$(grep "dashboard_user" /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
admin_pass=$(grep "dashboard_pwd" /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')

# 获取服务器IP
server_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)
if test -z "$server_ip"; then
    server_ip="YOUR_SERVER_IP"
fi

clear
echo "=================================="
echo "         FRP 管理面板"
echo "=================================="
echo "访问地址: http://$server_ip:$dash_port"
echo "用户名: $admin_user"
echo "密码: $admin_pass"
echo "=================================="

# 显示连接信息
if test -f /var/log/frps.log; then
    echo ""
    echo "最近连接的客户端IP:"
    tail -20 /var/log/frps.log | grep "login from" | tail -5 | while read line; do
        client_ip=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
        if test -n "$client_ip"; then
            echo "  $client_ip"
        fi
    done
    
    echo ""
    echo "当前活跃连接:"
    bind_port=$(grep "bind_port" /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
    netstat -tn 2>/dev/null | grep ":$bind_port.*ESTABLISHED" | while read line; do
        remote_ip=$(echo "$line" | awk '{print $5}' | cut -d':' -f1)
        echo "  $remote_ip"
    done
    
    echo ""
    echo "活跃代理:"
    tail -20 /var/log/frps.log | grep "proxy added" | tail -5
fi

echo "=================================="
printf "按回车键返回主菜单..."
read dummy_input
```

}

# 显示服务状态

show_status() {
echo “=== FRP 服务状态 ===”

```
os_type=$(get_os)

# 检查frps状态
if test -f /etc/frp/frps.ini; then
    printf "frps (服务端): "
    if test "$os_type" = "openwrt"; then
        if pgrep -f frps >/dev/null 2>&1; then
            echo "运行中"
        else
            echo "未运行"
        fi
    else
        if systemctl is-active frps >/dev/null 2>&1; then
            echo "运行中"
        else
            echo "未运行"
        fi
    fi
fi

# 检查frpc状态
if test -f /etc/frp/frpc.ini; then
    printf "frpc (客户端): "
    if test "$os_type" = "openwrt"; then
        if pgrep -f frpc >/dev/null 2>&1; then
            echo "运行中"
        else
            echo "未运行"
        fi
    else
        if systemctl is-active frpc >/dev/null 2>&1; then
            echo "运行中"
        else
            echo "未运行"
        fi
    fi
fi

# 显示连接统计
if test -f /var/log/frps.log; then
    echo ""
    echo "连接统计:"
    today_date=$(date '+%Y/%m/%d')
    connection_count=$(grep "$today_date" /var/log/frps.log | grep -c "login from" 2>/dev/null)
    if test -z "$connection_count"; then
        connection_count="0"
    fi
    echo "  今日连接次数: $connection_count"
    
    bind_port=$(grep "bind_port" /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
    active_count=$(netstat -tn 2>/dev/null | grep -c ":$bind_port.*ESTABLISHED")
    if test -z "$active_count"; then
        active_count="0"
    fi
    echo "  当前活跃连接: $active_count"
fi

# 显示客户端日志
if test -f /var/log/frpc.log; then
    echo ""
    echo "客户端最新日志:"
    tail -3 /var/log/frpc.log
fi
```

}

# 重启服务

restart_services() {
os_type=$(get_os)

```
if test -f /etc/frp/frps.ini; then
    if test "$os_type" = "openwrt"; then
        /etc/init.d/frps restart
    else
        systemctl restart frps
    fi
    show_success "frps 重启完成"
fi

if test -f /etc/frp/frpc.ini; then
    if test "$os_type" = "openwrt"; then
        /etc/init.d/frpc restart
    else
        systemctl restart frpc
    fi
    show_success "frpc 重启完成"
fi
```

}

# 查看日志

view_logs() {
echo “选择要查看的日志:”
echo “1. frps (服务端)”
echo “2. frpc (客户端)”
printf “请选择: “
read log_choice

```
if test "$log_choice" = "1"; then
    if test -f /var/log/frps.log; then
        tail -f /var/log/frps.log
    else
        echo "frps 日志文件不存在"
    fi
elif test "$log_choice" = "2"; then
    if test -f /var/log/frpc.log; then
        tail -f /var/log/frpc.log
    else
        echo "frpc 日志文件不存在"
    fi
else
    echo "无效选择"
fi
```

}

# 卸载FRP

uninstall_frp() {
printf “确认卸载 FRP? 输入 yes 确认: “
read confirm_input

```
if test "$confirm_input" = "yes"; then
    os_type=$(get_os)
    
    # 停止服务
    if test "$os_type" = "openwrt"; then
        /etc/init.d/frps stop 2>/dev/null
        /etc/init.d/frpc stop 2>/dev/null
        rm -f /etc/init.d/frps
        rm -f /etc/init.d/frpc
    else
        systemctl stop frps 2>/dev/null
        systemctl stop frpc 2>/dev/null
        systemctl disable frps 2>/dev/null
        systemctl disable frpc 2>/dev/null
        rm -f /etc/systemd/system/frps.service
        rm -f /etc/systemd/system/frpc.service
        systemctl daemon-reload
    fi
    
    # 删除文件
    rm -rf /opt/frp
    rm -rf /etc/frp
    rm -f /var/log/frps.log
    rm -f /var/log/frpc.log
    
    show_success "FRP 卸载完成"
else
    echo "取消卸载"
fi
```

}

# 主循环

while true; do
clear
echo “=================================”
echo “       FRP 管理脚本 v1.1”
echo “=================================”
echo “1. 安装服务端”
echo “2. 安装客户端”
echo “3. 查看状态”
echo “4. 重启服务”
echo “5. 查看日志”
echo “6. 卸载 FRP”
echo “f. 管理面板”
echo “0. 退出”
echo “=================================”
printf “请选择: “
read menu_choice

```
if test "$menu_choice" = "1"; then
    install_frp
    setup_server
    printf "按回车键继续..."
    read dummy_input
elif test "$menu_choice" = "2"; then
    install_frp
    setup_client
    printf "按回车键继续..."
    read dummy_input
elif test "$menu_choice" = "3"; then
    show_status
    printf "按回车键继续..."
    read dummy_input
elif test "$menu_choice" = "4"; then
    restart_services
    printf "按回车键继续..."
    read dummy_input
elif test "$menu_choice" = "5"; then
    view_logs
elif test "$menu_choice" = "6"; then
    uninstall_frp
    printf "按回车键继续..."
    read dummy_input
elif test "$menu_choice" = "f" -o "$menu_choice" = "F"; then
    show_dashboard
elif test "$menu_choice" = "0"; then
    echo "退出脚本"
    exit 0
else
    echo "无效选择，请重试"
    sleep 1
fi
```

done
