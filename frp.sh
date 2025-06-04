#!/bin/bash
set -e

FRP_VERSION=“0.52.3”

log() {
echo “[$1] $2”
}

get_arch() {
case $(uname -m) in
x86_64) echo “amd64” ;;
aarch64) echo “arm64” ;;
armv7l) echo “arm” ;;
*) echo “amd64” ;;
esac
}

get_os() {
if [ -f /etc/openwrt_release ]; then
echo “openwrt”
elif [ “$(uname)” = “Darwin” ]; then
echo “darwin”
else
echo “linux”
fi
}

install() {
OS=$(get_os)
ARCH=$(get_arch)

```
log "INFO" "下载 FRP $FRP_VERSION for $OS-$ARCH"

cd /tmp
wget -q "https://github.com/fatedier/frp/releases/download/v$FRP_VERSION/frp_${FRP_VERSION}_${OS}_${ARCH}.tar.gz"
tar -xzf "frp_${FRP_VERSION}_${OS}_${ARCH}.tar.gz"

mkdir -p /opt/frp /etc/frp
cp "frp_${FRP_VERSION}_${OS}_${ARCH}"/frp* /opt/frp/
chmod +x /opt/frp/frp*

rm -rf "frp_${FRP_VERSION}_${OS}_${ARCH}"*
log "SUCCESS" "安装完成"
```

}

server() {
printf “端口[7000]: “; read port; port=${port:-7000}
printf “面板端口[7500]: “; read dash; dash=${dash:-7500}
printf “用户[admin]: “; read user; user=${user:-admin}
printf “密码: “; read pwd
printf “Token: “; read token

```
cat > /etc/frp/frps.ini << EOF
```

[common]
bind_port = $port
dashboard_port = $dash
dashboard_user = $user
dashboard_pwd = $pwd
token = $token
log_file = /var/log/frps.log
EOF

```
touch /var/log/frps.log

if [ "$(get_os)" = "openwrt" ]; then
    cat > /etc/init.d/frps << 'EOF'
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
EOF
chmod +x /etc/init.d/frps
/etc/init.d/frps enable
/etc/init.d/frps start
else
cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=frps
After=network.target

[Service]
Type=simple
ExecStart=/opt/frp/frps -c /etc/frp/frps.ini
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable frps
systemctl start frps
fi

```
log "SUCCESS" "服务端配置完成"
```

}

client() {
printf “服务器: “; read srv
printf “端口[7000]: “; read port; port=${port:-7000}
printf “Token: “; read token
printf “本地端口: “; read lport
printf “远程端口: “; read rport

```
cat > /etc/frp/frpc.ini << EOF
```

[common]
server_addr = $srv
server_port = $port
token = $token
log_file = /var/log/frpc.log

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = $lport
remote_port = $rport
EOF

```
touch /var/log/frpc.log

if [ "$(get_os)" = "openwrt" ]; then
    cat > /etc/init.d/frpc << 'EOF'
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
EOF
chmod +x /etc/init.d/frpc
/etc/init.d/frpc enable
/etc/init.d/frpc start
else
cat > /etc/systemd/system/frpc.service << EOF
[Unit]
Description=frpc
After=network.target

[Service]
Type=simple
ExecStart=/opt/frp/frpc -c /etc/frp/frpc.ini
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc
fi

```
log "SUCCESS" "客户端配置完成"
```

}

panel() {
if [ ! -f /etc/frp/frps.ini ]; then
log “ERROR” “未找到服务端配置”
return
fi

```
port=$(grep dashboard_port /etc/frp/frps.ini | cut -d= -f2 | tr -d ' ')
user=$(grep dashboard_user /etc/frp/frps.ini | cut -d= -f2 | tr -d ' ')
pwd=$(grep dashboard_pwd /etc/frp/frps.ini | cut -d= -f2 | tr -d ' ')
ip=$(curl -s ifconfig.me || echo "YOUR_IP")

clear
echo "===================="
echo "FRP 管理面板"
echo "===================="
echo "地址: http://$ip:$port"
echo "用户: $user"
echo "密码: $pwd"
echo "===================="

if [ -f /var/log/frps.log ]; then
    echo "最近连接:"
    tail -10 /var/log/frps.log | grep "login from" | while read line; do
        echo "  $(echo $line | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')"
    done
fi

printf "按回车..."
read
```

}

status() {
echo “=== 服务状态 ===”
for svc in frps frpc; do
if [ -f “/etc/frp/$svc.ini” ]; then
printf “$svc: “
if [ “$(get_os)” = “openwrt” ]; then
if pgrep $svc >/dev/null; then echo “运行中”; else echo “未运行”; fi
else
systemctl is-active $svc || echo “未运行”
fi
fi
done

```
if [ -f /var/log/frps.log ]; then
    echo ""
    echo "连接统计:"
    today=$(date +%Y/%m/%d)
    count=$(grep "$today" /var/log/frps.log | grep -c "login from" || echo "0")
    echo "  今日: $count 次"
fi
```

}

restart() {
for svc in frps frpc; do
if [ -f “/etc/frp/$svc.ini” ]; then
if [ “$(get_os)” = “openwrt” ]; then
/etc/init.d/$svc restart
else
systemctl restart $svc
fi
log “SUCCESS” “$svc 重启完成”
fi
done
}

logs() {
echo “1.frps 2.frpc”
printf “选择: “; read choice
case $choice in
1) tail -f /var/log/frps.log ;;
2) tail -f /var/log/frpc.log ;;
esac
}

uninstall() {
printf “确定卸载?(yes/no): “; read confirm
if [ “$confirm” = “yes” ]; then
for svc in frps frpc; do
if [ “$(get_os)” = “openwrt” ]; then
/etc/init.d/$svc stop 2>/dev/null || true
rm -f /etc/init.d/$svc
else
systemctl stop $svc 2>/dev/null || true
systemctl disable $svc 2>/dev/null || true
rm -f /etc/systemd/system/$svc.service
fi
done
rm -rf /opt/frp /etc/frp /var/log/frp*.log
[ “$(get_os)” != “openwrt” ] && systemctl daemon-reload
log “SUCCESS” “卸载完成”
fi
}

while true; do
clear
echo “=================”
echo “  FRP 管理脚本”
echo “=================”
echo “1. 安装服务端”
echo “2. 安装客户端”
echo “3. 查看状态”
echo “4. 重启服务”
echo “5. 查看日志”
echo “6. 卸载”
echo “f. 管理面板”
echo “0. 退出”
echo “=================”
printf “选择: “; read choice

```
case $choice in
    1) install; server; printf "按回车..."; read ;;
    2) install; client; printf "按回车..."; read ;;
    3) status; printf "按回车..."; read ;;
    4) restart; printf "按回车..."; read ;;
    5) logs ;;
    6) uninstall; printf "按回车..."; read ;;
    f|F) panel ;;
    0) exit 0 ;;
    *) echo "无效选择"; sleep 1 ;;
esac
```

done
