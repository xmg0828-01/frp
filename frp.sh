#!/bin/bash

# FRP 一键部署脚本

# 支持系统: Linux, macOS, OpenWrt

# 支持架构: x86_64, arm64, armv7, mips

set -e

# 颜色定义

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
BLUE=’\033[0;34m’
NC=’\033[0m’

# 版本信息

FRP_VERSION=“0.52.3”
SCRIPT_VERSION=“1.0.0”

# 全局变量

INSTALL_DIR=”/opt/frp”
CONFIG_DIR=”/etc/frp”
SERVICE_DIR=”/etc/systemd/system”
FRP_USER=“frp”
ARCH=””
OS_TYPE=””
DOWNLOAD_URL=””

# 打印函数

print_info() {
printf “${BLUE}[INFO]${NC} %s\n” “$1”
}

print_success() {
printf “${GREEN}[SUCCESS]${NC} %s\n” “$1”
}

print_warning() {
printf “${YELLOW}[WARNING]${NC} %s\n” “$1”
}

print_error() {
printf “${RED}[ERROR]${NC} %s\n” “$1”
}

# 检测系统类型和架构

detect_system() {
print_info “检测系统信息…”

```
# 检测操作系统
if [[ -f /etc/openwrt_release ]]; then
    OS_TYPE="openwrt"
    print_info "检测到 OpenWrt 系统"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="darwin"
    print_info "检测到 macOS 系统"
elif [[ -f /etc/os-release ]] || [[ -f /etc/debian_version ]] || [[ -f /etc/redhat-release ]]; then
    OS_TYPE="linux"
    print_info "检测到 Linux 系统"
else
    print_error "不支持的操作系统"
    exit 1
fi

# 检测架构
local machine=$(uname -m)
case $machine in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l|armv6l)
        ARCH="arm"
        ;;
    mips|mipsel)
        ARCH="mips"
        ;;
    *)
        print_error "不支持的架构: $machine"
        exit 1
        ;;
esac

print_success "系统: $OS_TYPE, 架构: $ARCH"
```

}

# 下载 FRP

download_frp() {
print_info “下载 FRP v$FRP_VERSION…”

```
local filename="frp_${FRP_VERSION}_${OS_TYPE}_${ARCH}"
if [[ "$OS_TYPE" == "darwin" ]]; then
    filename="frp_${FRP_VERSION}_darwin_${ARCH}"
fi

DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${filename}.tar.gz"

# 创建临时目录
local temp_dir=$(mktemp -d)
cd "$temp_dir"

print_info "下载地址: $DOWNLOAD_URL"

# 尝试使用不同的下载工具
if command -v wget >/dev/null 2>&1; then
    wget -O frp.tar.gz "$DOWNLOAD_URL" || {
        print_error "下载失败，请检查网络连接"
        exit 1
    }
elif command -v curl >/dev/null 2>&1; then
    curl -L -o frp.tar.gz "$DOWNLOAD_URL" || {
        print_error "下载失败，请检查网络连接"
        exit 1
    }
else
    print_error "需要安装 wget 或 curl"
    exit 1
fi

# 解压文件
tar -xzf frp.tar.gz
cd "${filename}"

# 创建安装目录
sudo mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"

# 复制文件
sudo cp frps frpc "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/frps" "$INSTALL_DIR/frpc"

# 清理临时文件
cd /
rm -rf "$temp_dir"

print_success "FRP 下载安装完成"
```

}

# 创建用户

create_user() {
if [[ “$OS_TYPE” != “openwrt” ]]; then
if ! id “$FRP_USER” >/dev/null 2>&1; then
print_info “创建 FRP 用户…”
sudo useradd -r -s /bin/false “$FRP_USER” 2>/dev/null || true
fi
fi
}

# 生成服务端配置

generate_server_config() {
print_info “配置 FRP 服务端…”

```
echo "请输入服务端配置信息:"
read -p "绑定端口 (默认 7000): " bind_port
bind_port=${bind_port:-7000}

read -p "Dashboard 端口 (默认 7500): " dashboard_port
dashboard_port=${dashboard_port:-7500}

read -p "Dashboard 用户名 (默认 admin): " dashboard_user
dashboard_user=${dashboard_user:-admin}

read -p "Dashboard 密码: " dashboard_pwd
while [[ -z "$dashboard_pwd" ]]; do
    read -p "密码不能为空，请重新输入: " dashboard_pwd
done

read -p "认证 Token: " auth_token
while [[ -z "$auth_token" ]]; do
    read -p "Token 不能为空，请重新输入: " auth_token
done

# 生成配置文件
sudo tee "$CONFIG_DIR/frps.ini" > /dev/null <<EOF
```

[common]
bind_port = $bind_port
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
authentication_method = token
token = $auth_token

# 日志配置

log_file = /var/log/frps.log
log_level = info
log_max_days = 3

# 其他配置

max_clients = 10
allow_ports = 2000-3000,3001,3003,4000-50000
EOF

```
sudo mkdir -p /var/log
sudo touch /var/log/frps.log

if [[ "$OS_TYPE" != "openwrt" ]]; then
    sudo chown "$FRP_USER:$FRP_USER" /var/log/frps.log
    sudo chown -R "$FRP_USER:$FRP_USER" "$CONFIG_DIR"
fi

print_success "服务端配置生成完成"
print_info "Dashboard 地址: http://YOUR_SERVER_IP:$dashboard_port"
print_info "用户名: $dashboard_user"
print_info "密码: $dashboard_pwd"
```

}

# 生成客户端配置

generate_client_config() {
print_info “配置 FRP 客户端…”

```
echo "请输入客户端配置信息:"
read -p "服务器地址: " server_addr
while [[ -z "$server_addr" ]]; do
    read -p "服务器地址不能为空，请重新输入: " server_addr
done

read -p "服务器端口 (默认 7000): " server_port
server_port=${server_port:-7000}

read -p "认证 Token: " auth_token
while [[ -z "$auth_token" ]]; do
    read -p "Token 不能为空，请重新输入: " auth_token
done

echo "选择服务类型:"
echo "1. SSH (端口 22)"
echo "2. HTTP (端口 80)"
echo "3. HTTPS (端口 443)"
echo "4. 自定义端口"
read -p "请选择 (1-4): " service_type

local service_name=""
local local_port=""
local remote_port=""
local service_type_name=""

case $service_type in
    1)
        service_name="ssh"
        local_port="22"
        service_type_name="tcp"
        read -p "远程端口 (用于 SSH 连接): " remote_port
        ;;
    2)
        service_name="web"
        local_port="80"
        service_type_name="http"
        read -p "自定义域名 (可选): " custom_domain
        ;;
    3)
        service_name="web_https"
        local_port="443"
        service_type_name="https"
        read -p "自定义域名 (可选): " custom_domain
        ;;
    4)
        read -p "服务名称: " service_name
        read -p "本地端口: " local_port
        read -p "远程端口: " remote_port
        service_type_name="tcp"
        ;;
    *)
        print_error "无效选择"
        exit 1
        ;;
esac

# 生成配置文件
cat > /tmp/frpc_config <<EOF
```

[common]
server_addr = $server_addr
server_port = $server_port
authentication_method = token
token = $auth_token

# 日志配置

log_file = /var/log/frpc.log
log_level = info
log_max_days = 3

[$service_name]
type = $service_type_name
local_ip = 127.0.0.1
local_port = $local_port
EOF

```
if [[ "$service_type_name" == "tcp" && -n "$remote_port" ]]; then
    echo "remote_port = $remote_port" >> /tmp/frpc_config
elif [[ "$service_type_name" == "http" || "$service_type_name" == "https" ]] && [[ -n "$custom_domain" ]]; then
    echo "custom_domains = $custom_domain" >> /tmp/frpc_config
fi

sudo mv /tmp/frpc_config "$CONFIG_DIR/frpc.ini"
sudo mkdir -p /var/log
sudo touch /var/log/frpc.log

if [[ "$OS_TYPE" != "openwrt" ]]; then
    sudo chown "$FRP_USER:$FRP_USER" /var/log/frpc.log
    sudo chown -R "$FRP_USER:$FRP_USER" "$CONFIG_DIR"
fi

print_success "客户端配置生成完成"
```

}

# 创建 systemd 服务

create_systemd_service() {
if [[ “$OS_TYPE” == “openwrt” ]]; then
create_openwrt_service
return
fi

```
local service_name=$1
local binary_name=$2
local config_file=$3

print_info "创建 $service_name systemd 服务..."

sudo tee "$SERVICE_DIR/$service_name.service" > /dev/null <<EOF
```

[Unit]
Description=FRP $service_name
After=network.target

[Service]
Type=simple
User=$FRP_USER
Restart=on-failure
RestartSec=5s
ExecStart=$INSTALL_DIR/$binary_name -c $config_file
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=control-group

[Install]
WantedBy=multi-user.target
EOF

```
sudo systemctl daemon-reload
sudo systemctl enable "$service_name"

print_success "$service_name 服务创建完成"
```

}

# 创建 OpenWrt 服务

create_openwrt_service() {
print_info “创建 OpenWrt 服务脚本…”

```
# 创建启动脚本
sudo tee /etc/init.d/frps > /dev/null <<'EOF'
```

#!/bin/sh /etc/rc.common

START=99
STOP=15

USE_PROCD=1
PROG=/opt/frp/frps
CONF=/etc/frp/frps.ini

start_service() {
procd_open_instance
procd_set_param command $PROG -c $CONF
procd_set_param respawn
procd_close_instance
}
EOF

```
sudo tee /etc/init.d/frpc > /dev/null <<'EOF'
```

#!/bin/sh /etc/rc.common

START=99
STOP=15

USE_PROCD=1
PROG=/opt/frp/frpc
CONF=/etc/frp/frpc.ini

start_service() {
procd_open_instance
procd_set_param command $PROG -c $CONF
procd_set_param respawn
procd_close_instance
}
EOF

```
sudo chmod +x /etc/init.d/frps /etc/init.d/frpc

print_success "OpenWrt 服务脚本创建完成"
```

}

# 启动服务

start_service() {
local service_name=$1

```
if [[ "$OS_TYPE" == "openwrt" ]]; then
    print_info "启动 $service_name 服务..."
    sudo /etc/init.d/$service_name enable
    sudo /etc/init.d/$service_name start
    
    if sudo /etc/init.d/$service_name status | grep -q "running"; then
        print_success "$service_name 服务启动成功"
    else
        print_error "$service_name 服务启动失败"
    fi
else
    print_info "启动 $service_name 服务..."
    sudo systemctl start "$service_name"
    
    if sudo systemctl is-active --quiet "$service_name"; then
        print_success "$service_name 服务启动成功"
    else
        print_error "$service_name 服务启动失败"
        sudo systemctl status "$service_name"
    fi
fi
```

}

# 显示连接信息

show_connection_info() {
local mode=$1

```
if [[ "$mode" == "server" ]]; then
    print_info "=== 服务端信息 ==="
    echo "配置文件: $CONFIG_DIR/frps.ini"
    echo "日志文件: /var/log/frps.log"
    
    local bind_port=$(grep "bind_port" "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    local dashboard_port=$(grep "dashboard_port" "$CONFIG_DIR/frps.ini" | cut -d'=' -f2 | tr -d ' ')
    
    echo "服务端口: $bind_port"
    echo "管理面板: http://$(curl -s ifconfig.me):$dashboard_port"
    
elif [[ "$mode" == "client" ]]; then
    print_info "=== 客户端信息 ==="
    echo "配置文件: $CONFIG_DIR/frpc.ini"
    echo "日志文件: /var/log/frpc.log"
    
    print_info "客户端连接配置:"
    cat "$CONFIG_DIR/frpc.ini"
fi
```

}

# 主菜单

main_menu() {
echo “”
echo “======================================”
echo “      FRP 一键部署脚本 v$SCRIPT_VERSION”
echo “======================================”
echo “1. 安装 FRP 服务端 (frps)”
echo “2. 安装 FRP 客户端 (frpc)”
echo “3. 查看服务状态”
echo “4. 重启服务”
echo “5. 查看日志”
echo “6. 卸载 FRP”
echo “0. 退出”
echo “======================================”
read -p “请选择操作 (0-6): “ choice

```
case $choice in
    1)
        install_server
        ;;
    2)
        install_client
        ;;
    3)
        check_status
        ;;
    4)
        restart_service
        ;;
    5)
        view_logs
        ;;
    6)
        uninstall_frp
        ;;
    0)
        print_info "退出脚本"
        exit 0
        ;;
    *)
        print_error "无效选择"
        main_menu
        ;;
esac
```

}

# 安装服务端

install_server() {
print_info “开始安装 FRP 服务端…”

```
detect_system
download_frp
create_user
generate_server_config

if [[ "$OS_TYPE" != "openwrt" ]]; then
    create_systemd_service "frps" "frps" "$CONFIG_DIR/frps.ini"
else
    create_openwrt_service
fi

start_service "frps"
show_connection_info "server"

print_success "FRP 服务端安装完成！"
```

}

# 安装客户端

install_client() {
print_info “开始安装 FRP 客户端…”

```
detect_system
download_frp
create_user
generate_client_config

if [[ "$OS_TYPE" != "openwrt" ]]; then
    create_systemd_service "frpc" "frpc" "$CONFIG_DIR/frpc.ini"
else
    create_openwrt_service
fi

start_service "frpc"
show_connection_info "client"

print_success "FRP 客户端安装完成！"
```

}

# 检查服务状态

check_status() {
if [[ “$OS_TYPE” == “openwrt” ]]; then
echo “=== FRP 服务状态 ===”
for service in frps frpc; do
if [[ -f “/etc/init.d/$service” ]]; then
echo -n “$service: “
/etc/init.d/$service status
fi
done
else
echo “=== FRP 服务状态 ===”
for service in frps frpc; do
if systemctl list-unit-files | grep -q “$service.service”; then
echo -n “$service: “
systemctl is-active “$service” 2>/dev/null || echo “inactive”
fi
done
fi
}

# 重启服务

restart_service() {
echo “选择要重启的服务:”
echo “1. frps (服务端)”
echo “2. frpc (客户端)”
echo “3. 全部重启”
read -p “请选择 (1-3): “ restart_choice

```
case $restart_choice in
    1)
        if [[ "$OS_TYPE" == "openwrt" ]]; then
            /etc/init.d/frps restart
        else
            sudo systemctl restart frps
        fi
        print_success "frps 重启完成"
        ;;
    2)
        if [[ "$OS_TYPE" == "openwrt" ]]; then
            /etc/init.d/frpc restart
        else
            sudo systemctl restart frpc
        fi
        print_success "frpc 重启完成"
        ;;
    3)
        if [[ "$OS_TYPE" == "openwrt" ]]; then
            /etc/init.d/frps restart
            /etc/init.d/frpc restart
        else
            sudo systemctl restart frps frpc
        fi
        print_success "所有服务重启完成"
        ;;
    *)
        print_error "无效选择"
        ;;
esac
```

}

# 查看日志

view_logs() {
echo “选择要查看的日志:”
echo “1. frps 日志”
echo “2. frpc 日志”
read -p “请选择 (1-2): “ log_choice

```
case $log_choice in
    1)
        if [[ -f "/var/log/frps.log" ]]; then
            tail -f /var/log/frps.log
        else
            print_error "frps 日志文件不存在"
        fi
        ;;
    2)
        if [[ -f "/var/log/frpc.log" ]]; then
            tail -f /var/log/frpc.log
        else
            print_error "frpc 日志文件不存在"
        fi
        ;;
    *)
        print_error "无效选择"
        ;;
esac
```

}

# 卸载 FRP

uninstall_frp() {
print_warning “确定要卸载 FRP 吗？这将删除所有配置文件和日志。”
read -p “输入 ‘yes’ 确认卸载: “ confirm

```
if [[ "$confirm" == "yes" ]]; then
    print_info "正在卸载 FRP..."
    
    # 停止并删除服务
    if [[ "$OS_TYPE" == "openwrt" ]]; then
        /etc/init.d/frps stop 2>/dev/null || true
        /etc/init.d/frpc stop 2>/dev/null || true
        rm -f /etc/init.d/frps /etc/init.d/frpc
    else
        sudo systemctl stop frps frpc 2>/dev/null || true
        sudo systemctl disable frps frpc 2>/dev/null || true
        sudo rm -f /etc/systemd/system/frps.service /etc/systemd/system/frpc.service
        sudo systemctl daemon-reload
    fi
    
    # 删除文件和目录
    sudo rm -rf "$INSTALL_DIR" "$CONFIG_DIR"
    sudo rm -f /var/log/frps.log /var/log/frpc.log
    
    # 删除用户
    if [[ "$OS_TYPE" != "openwrt" ]] && id "$FRP_USER" >/dev/null 2>&1; then
        sudo userdel "$FRP_USER" 2>/dev/null || true
    fi
    
    print_success "FRP 卸载完成"
else
    print_info "取消卸载"
fi
```

}

# 检查 root 权限

check_root() {
if [[ $EUID -eq 0 ]]; then
print_warning “检测到以 root 用户运行，建议使用普通用户运行此脚本”
read -p “继续执行? (y/N): “ continue_root
if [[ “$continue_root” != “y” && “$continue_root” != “Y” ]]; then
exit 0
fi
fi
}

# 主函数

main() {
clear
print_info “FRP 一键部署脚本启动…”

```
check_root

# 检查依赖
if ! command -v tar >/dev/null 2>&1; then
    print_error "需要安装 tar 命令"
    exit 1
fi

main_menu
```

}

# 脚本入口

main “$@”
