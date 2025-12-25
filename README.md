# l2tp-vpn-client

### 文档
- [Wiki](https://github.com/jianghuaangte/l2tp-vpn-client/wiki)

### 特点
- 基于 Alpine:edge
- 内置 Nginx、Socat
- 断开自连
- X86/ARM64

### 注意
- 为了保证连接的稳定性，容器启动后连接时可能需要20-120s，超过可以使用docker logs 容器ID 排查
- 不推荐使用 host 网络模式，除非你想让全局流量都走 VPN，Bridge 模式可以让宿主机走本地网络，容器走全局 VPN 流量

### 参数
|变量|说明|参考|查看命令|
|:---|:---|:---|:---|
|VPN_SERVER|服务端地址|123.23.234.69||
|VPN_PSK|PSK 密钥|12345678||
|VPN_USERNAME|用户名|xiaomin||
|VPN_PASSWORD|密码|123456||
|VPN_NAME|VPN名称|myvpn||
|LAN_IP|网段|192.168.0.0/24(host) or 172.17.0.0/24|ifconfig 或 由 docker 中指定子网|
|GW_LAN_IP|网关|192.168.0.1(host) or 172.17.0.1|ifconfig 或 由 docker 中指定子网|
|NET_INTERFACE|网络接口|eth0 or ens33||
|NGINX_ENABLE|Nginx开关|1/0||
|SOCAT_ENABLE|Socat开关|1/0||

### Socat
socat-cmd.sh 内容格式：
```shell
socat TCP-LISTEN:20170,fork,reuseaddr TCP:172.21.0.30:20170 &
```

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
      - SOCAT_ENABLE=0     # 设为1启用 Socat
    volumes:
       - "/lib/modules:/lib/modules:ro"
       - "/path/to/socat-cmd.sh:/usr/local/bin/socat-cmd.sh"
 #      - "./nginx/conf.d:/etc/nginx/conf.d"
    networks:
      vpn-network:
        ipv4_address: 172.20.0.10
    restart: unless-stopped
```

**CLi**
1. 创建网关、子网
```shell
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/24 \
  --gateway 172.20.0.1 \
  vpn-network
```
2. 运行
```shell
docker run -d \
  --name l2tp-vpn-client \
  --privileged \
  --cap-add NET_ADMIN \
  --device /dev/ppp:/dev/ppp \
  --network vpn-network \
  --ip 172.20.0.10 \
  --restart unless-stopped \
  -e VPN_SERVER=<your server> \
  -e VPN_PSK=<your psk> \
  -e VPN_USERNAME=<your vpn username> \
  -e VPN_PASSWORD=<your vpn passwd> \
  -e VPN_NAME=myvpn \
  -e LAN_IP=172.20.0.0/24 \
  -e GW_LAN_IP=172.20.0.1 \
  -e NET_INTERFACE=eth0 \
  -e NGINX_ENABLE=0 \
  -e SOCAT_ENABLE=0 \
  -v /lib/modules:/lib/modules:ro \
  freedomzzz/l2tp-vpn-client:latest
```
