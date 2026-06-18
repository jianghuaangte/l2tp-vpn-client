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
AUTO_RECONNECT="${AUTO_RECONNECT:-true}"
CHECK_INTERVAL="${CHECK_INTERVAL:-15}"
MAX_RETRIES="${MAX_RETRIES:-3}"


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
start_socat_if_enabled() {
  if [ "$SOCAT_ENABLE" = "1" ]; then
    chmod +x /usr/local/bin/socat-cmd.sh
    source /usr/local/bin/socat-cmd.sh
  fi
}

# 重启 xl2tpd 并重新拨号
restart_xl2tpd() {
  if [ -f /var/run/xl2tpd.pid ]; then
    kill "$(cat /var/run/xl2tpd.pid)" 2>/dev/null || true
  else
    pkill xl2tpd 2>/dev/null || true
  fi
  sleep 2
  rm -f /var/run/xl2tpd.pid /var/run/xl2tpd/l2tp-control
  mkdir -p /var/run/xl2tpd
  touch /var/run/xl2tpd/l2tp-control
  xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control -D &
  sleep 2
  echo "c ${VPN_NAME}" > /var/run/xl2tpd/l2tp-control
}

# 持续监控 ppp0，掉线则自动重连（看门狗）
monitor_connection() {
  if [ "$AUTO_RECONNECT" != "true" ]; then
    tail -f /dev/null
    return
  fi

  echo "🐶connection watchdog started (interval=${CHECK_INTERVAL}s, max_retries=${MAX_RETRIES})"

  while true; do
    sleep "$CHECK_INTERVAL"

    # 链路正常则继续
    if ip link show ppp0 2>/dev/null | grep -q "UP"; then
      continue
    fi

    echo "⚠️ppp0 is down, attempting to recover..."

    # 先确保 IPsec 第一阶段健康
    if ! ipsec status L2TP-PSK | grep -q "INSTALLED"; then
      echo "🔁IPsec SA missing, restarting IPsec..."
      ipsec restart || true
      sleep 3
      ipsec up L2TP-PSK || true
    fi

    retry=0
    while [ "$retry" -lt "$MAX_RETRIES" ]; do
      retry=$((retry + 1))
      echo "🔁reconnect attempt ${retry}/${MAX_RETRIES}..."
      restart_xl2tpd

      waited=0
      while [ "$waited" -lt 15 ]; do
        if ip link show ppp0 2>/dev/null | grep -q "UP"; then
          break
        fi
        sleep 1
        waited=$((waited + 1))
      done

      if ip link show ppp0 2>/dev/null | grep -q "UP"; then
        echo "✅ppp0 recovered"
        break
      fi
    done

    if ! ip link show ppp0 2>/dev/null | grep -q "UP"; then
      echo "💥failed to recover ppp0 after ${MAX_RETRIES} attempts, will retry next cycle"
    fi
  done
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
    # Socat
    start_socat_if_enabled
    
    # 连接看门狗：持续监控 ppp0，掉线自动重连
    monitor_connection
}

# 运行主函数
main
