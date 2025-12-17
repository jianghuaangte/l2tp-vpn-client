# 判断ppp是否建立再kill xl2tpd 并重新连接 myvpn
wait_ppp0() {
  echo "⏳ waiting for ppp0 interface..."

  local retry=0
  local max_retry=10

  while true; do
    if ip link show ppp0 2>/dev/null | grep -q "UP"; then
      echo "✅ ppp0 is UP"
      echo "✅ L2TP Connection successful！"
      return 0
    fi

    retry=$((retry + 1))

    if [ "$retry" -ge "$max_retry" ]; then
      echo "💥 ppp0 not up after ${max_retry}s, restarting xl2tpd..."

      # 1️⃣ kill xl2tpd
      if [ -f /var/run/xl2tpd.pid ]; then
        kill "$(cat /var/run/xl2tpd.pid)" 2>/dev/null
      else
        pkill xl2tpd 2>/dev/null
      fi

      sleep 2

      # 2️⃣ restart xl2tpd
      rm -f /var/run/xl2tpd.pid /var/run/xl2tpd/l2tp-control
      mkdir -p /var/run/xl2tpd
      touch /var/run/xl2tpd/l2tp-control

      xl2tpd \
        -p /var/run/xl2tpd.pid \
        -c /etc/xl2tpd/xl2tpd.conf \
        -C /var/run/xl2tpd/l2tp-control \
        -D &

      sleep 1

      # 3️⃣ reconnect
      echo "c ${VPN_NAME}" > /var/run/xl2tpd/l2tp-control

      retry=0
    fi

    sleep 1
  done
}

wait_ppp0
