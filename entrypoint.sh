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


# 生成配置文件
generate_configs() {
    echo "📝 生成配置文件..."
    
    # 生成 ipsec.conf
    sed -i "s/__VPN_SERVER__/${VPN_SERVER}/g" /etc/ipsec.conf
    # 生成 ipsec.secrets
    sed -i "s/__VPN_PSK__/${VPN_PSK}/g" /etc/ipsec.secrets
    # 生成 xl2tpd.conf
    sed -i "s/__VPN_NAME__/${VPN_NAME}/g" /etc/xl2tpd/xl2tpd.conf
    sed -i "s/__VPN_SERVER__/${VPN_SERVER}/g" /etc/xl2tpd/xl2tpd.conf
    # 生成 options.l2tpd.client
    sed -i "s/__VPN_USERNAME__/${VPN_USERNAME}/g" /etc/ppp/options.l2tpd.client
    sed -i "s/__VPN_PASSWORD__/${VPN_PASSWORD}/g" /etc/ppp/options.l2tpd.client
    
    chmod 600 /etc/ppp/options.l2tpd.client
    
}

# 启动服务
start_services() {
    # 创建必要目录
    mkdir -p /var/run/xl2tpd
    touch /var/run/xl2tpd/l2tp-control
    chmod 755 /var/run/xl2tpd
    xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control -D &
    sleep 7
}

# 建立 VPN 连接
connect_vpn() {
    # 尝试建立 IPsec 连接
    source check-ipsec.sh
    source check-ppp.sh
    # 尝试建立 L2TP 连接
    echo "c ${VPN_NAME}" > /var/run/xl2tpd/l2tp-control
    sleep 2
}

# 路由表
ip_routes() {
    ip route add $VPN_SERVER via $GW_LAN_IP dev $NET_INTERFACE metric 100
    ip route add $LAN_IP via $GW_LAN_IP dev eth0 metric 70
    ip route add default dev ppp0 metric 50
    ip route del default via $GW_LAN_IP dev $NET_INTERFACE
}


# 主函数
main() {
    
    # 生成配置
    generate_configs
    
    # 启动服务
    start_services
    
    # 建立连接
    connect_vpn

    # 路由
    ip_routes
    
    # 保持容器运行
    tail -f /dev/null
}

# 运行主函数
main
