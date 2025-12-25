#!/bin/sh
set -e

# 默认值
VPN_SERVER="${VPN_SERVER:-$1}"
VPN_PSK="${VPN_PSK:-$2}"
VPN_USERNAME="${VPN_USERNAME:-$3}"
VPN_PASSWORD="${VPN_PASSWORD:-$4}"
VPN_NAME="${VPN_NAME:-${5:-myVPN}}"
LAN_IP="${LAN_IP:-$6}"
GW_LAN_IP="${GW_LAN_IP:-$7}"
NET_INTERFACE="${NET_INTERFACE:-$8}"
NGINX_ENABLE="${NGINX_ENABLE:-0}"
SOCAT_ENABLE="${SOCAT_ENABLE:-0}"


# 生成配置文件
generate_configs() {
    # 生成 ipsec.conf
    sed -i "s/__VPN_SERVER__/${VPN_SERVER}/g" /etc/ipsec.conf
    # 生成 ipsec.secrets
    sed -i "s/__VPN_PSK__/${VPN_PSK}/g" /etc/ipsec.secrets
    # 生成 xl2tpd.conf
    sed -i "s/__VPN_NAME__/${VPN_NAME}/g" /etc/xl2tpd/xl2tpd.conf
    sed -i "s/__VPN_SERVER__/${VPN_SERVER}/g" /etc/xl2tpd/xl2tpd.conf
    # 生成 options.xl2tpd.client
    sed -i "s/__VPN_USERNAME__/${VPN_USERNAME}/g" /etc/ppp/options.xl2tpd.client
    sed -i "s/__VPN_PASSWORD__/${VPN_PASSWORD}/g" /etc/ppp/options.xl2tpd.client
    sed -i "s/__VPN_SERVER__/${VPN_SERVER}/g" /etc/ppp/options.xl2tpd.client
    sed -i "s/__GW_LAN_IP__/${GW_LAN_IP}/g" /etc/ppp/options.xl2tpd.client
    sed -i "s/__NET_INTERFACE__/${NET_INTERFACE}/g" /etc/ppp/options.xl2tpd.client
    
    chmod 600 /etc/ppp/options.xl2tpd.client
    
}

# 启动服务
start_services() {
    # 创建必要目录
    mkdir -p /var/run/xl2tpd
    touch /var/run/xl2tpd/l2tp-control
    chmod 755 /var/run/xl2tpd
    xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control -D &
    sleep 3
}

# 建立 VPN 连接
connect_vpn() {
    # 尝试建立 IPsec 连接
    source check-ipsec.sh
    # 建立连接
    echo "c ${VPN_NAME}" > /var/run/xl2tpd/l2tp-control &
    source check-connect.sh
}

# Nginx
start_nginx_if_enabled() {
  if [ "$NGINX_ENABLE" = "1" ]; then
    nginx
  fi
}

# Socat
start_nginx_if_enabled() {
  if [ "$SOCAT_ENABLE" = "1" ]; then
    chmod +x /usr/local/bin/socat-cmd.sh
    source /usr/local/bin/socat-cmd.sh
  fi
}

# 主函数
main() {
    
    # 生成配置
    generate_configs
    
    # 启动服务
    start_services
    
    # 建立连接
    connect_vpn

    # Nginx
    start_nginx_if_enabled
    # 保持容器运行
    tail -f /dev/null
}

# 运行主函数
main
