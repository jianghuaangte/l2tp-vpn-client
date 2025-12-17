# ipsec --help
# 检测 ipsec up L2TP-PSK 是否连接成功

# 函数
# 判断 ipsec 第一阶段是否连接成功
wait_ipsec_forever() {
  echo "⏳ waiting for IPsec (self-healing)..."
  local tries=0

  while true; do
    if ipsec status L2TP-PSK | grep -q "INSTALLED"; then
      echo "✅ IPsec ready"
      return 0
    fi

    tries=$((tries + 1))

    if [ $((tries % 6)) -eq 0 ]; then
      ipsec restart
      sleep 3
      ipsec up L2TP-PSK
    fi

    sleep 1
  done
}

# 启动检查
ipsec update
sleep 1
wait_ipsec_forever
