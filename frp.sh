#!/bin/bash
# FRP管理脚本 v1.0
# 支持Linux/OpenWrt/MacOS
# 支持服务端/客户端管理
# 按f键快速打开管理面板

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 配置文件路径
FRP_PATH="/usr/local/frp"
SERVER_CONFIG="${FRP_PATH}/frps.ini"
CLIENT_CONFIG="${FRP_PATH}/frpc.ini"
LOG_FILE="/var/log/frp.log"

# 检测系统类型
check_sys() {
  if [ -f /etc/redhat-release ]; then
    release="centos"
  elif grep -Eqi "debian" /etc/issue; then
    release="debian"
  elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"
  elif grep -Eqi "openwrt" /etc/openwrt_release; then
    release="openwrt"
  elif [ "$(uname)" == "Darwin" ]; then
    release="macos"
  else
    echo -e "${RED}不支持的系统!${PLAIN}" && exit 1
  fi
}

# 安装FRP
install_frp() {
  echo -e "${BLUE}开始安装FRP...${PLAIN}"
  
  # 下载最新版本
  local latest_ver=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -o '"tag_name": ".*"' | cut -d'"' -f4)
  local download_url="https://github.com/fatedier/frp/releases/download/${latest_ver}/frp_${latest_ver:1}_linux_amd64.tar.gz"
  
  if [ "$release" = "macos" ]; then
    download_url="https://github.com/fatedier/frp/releases/download/${latest_ver}/frp_${latest_ver:1}_darwin_amd64.tar.gz"
  fi

  wget -O frp.tar.gz ${download_url}
  tar -xf frp.tar.gz
  
  # 创建目录
  mkdir -p ${FRP_PATH}
  
  # 复制文件
  cp frp*/frps ${FRP_PATH}/
  cp frp*/frpc ${FRP_PATH}/
  cp frp*/frps.ini ${FRP_PATH}/
  cp frp*/frpc.ini ${FRP_PATH}/
  
  # 创建服务
  create_service
  
  echo -e "${GREEN}FRP安装完成!${PLAIN}"
}

# 创建服务
create_service() {
  if [ "$release" = "openwrt" ]; then
    # OpenWrt服务
    cat > /etc/init.d/frp << EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
  procd_open_instance
  procd_set_param command ${FRP_PATH}/frps -c ${SERVER_CONFIG}
  procd_set_param file ${SERVER_CONFIG}
  procd_set_param respawn
  procd_close_instance
}
EOF
    chmod +x /etc/init.d/frp
    
  elif [ "$release" = "macos" ]; then
    # MacOS服务
    cat > /Library/LaunchDaemons/com.frp.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.frp</string>
  <key>ProgramArguments</key>
  <array>
    <string>${FRP_PATH}/frps</string>
    <string>-c</string>
    <string>${SERVER_CONFIG}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
    launchctl load -w /Library/LaunchDaemons/com.frp.plist
    
  else
    # Linux服务
    cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
ExecStart=${FRP_PATH}/frps -c ${SERVER_CONFIG}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable frps
  fi
}

# 配置服务端
config_server() {
  echo -e "${BLUE}配置FRP服务端...${PLAIN}"
  read -p "绑定端口[7000]: " bind_port
  read -p "面板端口[7500]: " dashboard_port
  read -p "面板用户名[admin]: " dashboard_user  
  read -p "面板密码[admin]: " dashboard_pwd
  
  [ -z "$bind_port" ] && bind_port="7000"
  [ -z "$dashboard_port" ] && dashboard_port="7500"
  [ -z "$dashboard_user" ] && dashboard_user="admin"
  [ -z "$dashboard_pwd" ] && dashboard_pwd="admin"
  
  cat > ${SERVER_CONFIG} << EOF
[common]
bind_port = ${bind_port}
dashboard_port = ${dashboard_port}
dashboard_user = ${dashboard_user}
dashboard_pwd = ${dashboard_pwd}
EOF

  restart_frp
  echo -e "${GREEN}服务端配置完成!${PLAIN}"
}

# 配置客户端
config_client() {
  echo -e "${BLUE}配置FRP客户端...${PLAIN}"
  read -p "服务器地址: " server_addr
  read -p "服务器端口[7000]: " server_port
  read -p "代理名称: " proxy_name
  read -p "本地端口: " local_port
  read -p "远程端口: " remote_port
  
  [ -z "$server_port" ] && server_port="7000"
  
  cat > ${CLIENT_CONFIG} << EOF
[common]
server_addr = ${server_addr}
server_port = ${server_port}

[${proxy_name}]
type = tcp
local_ip = 127.0.0.1
local_port = ${local_port}
remote_port = ${remote_port}
EOF

  restart_frp
  echo -e "${GREEN}客户端配置完成!${PLAIN}"
}

# 重启FRP
restart_frp() {
  echo -e "${BLUE}重启FRP服务...${PLAIN}"
  
  if [ "$release" = "openwrt" ]; then
    /etc/init.d/frp restart
  elif [ "$release" = "macos" ]; then
    launchctl unload /Library/LaunchDaemons/com.frp.plist
    launchctl load -w /Library/LaunchDaemons/com.frp.plist
  else
    systemctl restart frps
  fi
  
  echo -e "${GREEN}服务已重启!${PLAIN}"
}

# 查看日志
view_log() {
  if [ -f "$LOG_FILE" ]; then
    tail -f $LOG_FILE
  else
    echo -e "${RED}日志文件不存在!${PLAIN}"
  fi
}

# 查看连接状态
view_status() {
  echo -e "${BLUE}FRP连接状态:${PLAIN}"
  echo -e "------------------------"
  
  # 获取面板信息
  local dashboard_addr="http://localhost:7500"
  local dashboard_info=$(curl -s -u admin:admin ${dashboard_addr}/api/status)
  
  # 解析并显示客户端连接
  echo "$dashboard_info" | while read line; do
    if [[ $line =~ "proxy_name" ]]; then
      local name=$(echo $line | cut -d'"' -f4)
      local ip=$(echo $line | cut -d'"' -f8)
      echo -e "代理: ${GREEN}${name}${PLAIN}"
      echo -e "客户端IP: ${YELLOW}${ip}${PLAIN}"
    fi
  done
  
  echo -e "------------------------"
}

# 卸载FRP
uninstall_frp() {
  echo -e "${YELLOW}确定要卸载FRP吗? (y/n)${PLAIN}"
  read -p "" confirm
  
  if [ "$confirm" != "y" ]; then
    return
  fi
  
  if [ "$release" = "openwrt" ]; then
    /etc/init.d/frp stop
    rm -f /etc/init.d/frp
  elif [ "$release" = "macos" ]; then
    launchctl unload /Library/LaunchDaemons/com.frp.plist
    rm -f /Library/LaunchDaemons/com.frp.plist
  else
    systemctl stop frps
    systemctl disable frps
    rm -f /etc/systemd/system/frps.service
  fi
  
  rm -rf ${FRP_PATH}
  rm -f $LOG_FILE
  
  echo -e "${GREEN}FRP已卸载!${PLAIN}"
}

# 主菜单
show_menu() {
  echo -e "
  ${GREEN}FRP 管理脚本${PLAIN} ${RED}[v1.0]${PLAIN}
  ――――――――――――――――――――――――
  ${GREEN}1.${PLAIN} 安装 FRP
  ${GREEN}2.${PLAIN} 配置服务端
  ${GREEN}3.${PLAIN} 配置客户端  
  ${GREEN}4.${PLAIN} 重启服务
  ${GREEN}5.${PLAIN} 查看日志
  ${GREEN}6.${PLAIN} 查看状态
  ${GREEN}7.${PLAIN} 卸载 FRP
  ${GREEN}0.${PLAIN} 退出脚本
  ――――――――――――――――――――――――
  "
  echo && read -p "请输入选择 [0-7]: " num
  
  case "$num" in
    1) install_frp ;;
    2) config_server ;;
    3) config_client ;;
    4) restart_frp ;;
    5) view_log ;;
    6) view_status ;;
    7) uninstall_frp ;;
    0) exit 0 ;;
    *) echo -e "${RED}请输入正确数字 [0-7]${PLAIN}" ;;
  esac
}

# 检查按键
check_input() {
  if read -t 0.1 -n 1 key; then
    if [[ $key = "f" ]] || [[ $key = "F" ]]; then
      view_status
    fi
  fi
}

# 主程序
main() {
  check_sys
  
  while true; do
    show_menu
    check_input
  done
}

main
