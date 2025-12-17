# 判断ppp是否建立再操作路由表
wait_ppp0() {
  echo "⏳ waiting for ppp0 interface..."

  while true; do
    if ip link show ppp0 | grep -q "ppp0" >/dev/null 2>&1; then
      echo "✅ ppp0 is up"
      return 0
    fi
    sleep 1
  done
}

wait_ppp0
