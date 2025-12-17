# l2tp-vpn-client

### 特点
- 基于 Alpine:edge
- 内置 Nginx
- 断开自连
- X86/ARM64

### 注意
为了保证连接的稳定性，容器启动后连接时可能需要20-120s，超过可以使用docker logs 容器ID 排查

### 参数
|变量|说明|参考|
|:---|:---|:---|
|VPN_SERVER|服务端地址|123.23.234.69|
|VPN_PSK|PSK 密钥|12345678|
|VPN_USERNAME|用户名|xiaomin|
|VPN_PASSWORD|密码|123456|
|VPN_NAME|VPN名称|myvpn|
|LAN_IP|网段|192.168.0.0/24 or 172.17.0.0/24|
|GW_LAN_IP|网关|192.168.0.1 or 172.17.0.1|
|NET_INTERFACE|网络接口|eth0 or ens33|
|NGINX_ENABLE|Nginx开关|1/0|

---
### Docker
**compose**

```yml
version: '3.8'

networks:
  vpn-network:
    driver: bridge
    ipam:
      config:
        - subnet: "172.20.0.0/24"
          gateway: "172.20.0.1"

services:
  vpn-client:
    image: freedomzzz/l2tp-vpn-client:latest
    container_name: l2tp-vpn-client
    privileged: true
    cap_add:
      - NET_ADMIN
    devices:
      - "/dev/ppp:/dev/ppp"
#    ports:
#      - "1701:1701/udp"
#      - "4500:4500/udp"
#      - "500:500/udp"
    environment:
      - VPN_SERVER=<your server>
      - VPN_PSK=<your psk>
      - VPN_USERNAME=<your vpn username>
      - VPN_PASSWORD=<your vpn passwd>
      - VPN_NAME=myvpn
      - LAN_IP=172.20.0.0/24
      - GW_LAN_IP=172.20.0.1
      - NET_INTERFACE=eth0
      - NGINX_ENABLE=0     # 设为1启用 Nginx

    volumes:
       - "/lib/modules:/lib/modules:ro"
 #      - "./nginx/conf.d:/etc/nginx/conf.d"
    networks:
      vpn-network:
        ipv4_address: 172.20.0.10
    restart: unless-stopped
```
