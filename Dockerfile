FROM alpine:edge

# 设置环境变量
ENV VPN_SERVER=""
ENV VPN_PSK=""
ENV VPN_USERNAME=""
ENV VPN_PASSWORD=""
ENV VPN_NAME=""
ENV LAN_IP=""
ENV GW_LAN_IP=""
ENV NET_INTERFACE=""
ENV AUTO_RECONNECT="true"
ENV CHECK_INTERVAL="15"
ENV MAX_RETRIES="3"

# 安装必要的软件包
RUN apk update && apk add --no-cache \
    strongswan \
    xl2tpd \
    ppp \
    net-tools \
    nginx \
    nginx-mod-stream \
    curl \
    neovim \
    && rm -rf /var/cache/apk/*

# 创建必要的目录
RUN mkdir -p /var/run/xl2tpd /etc/xl2tpd /etc/ppp

# 复制配置文件模板
COPY ipsec/ipsec.conf /etc/ipsec.conf
COPY ipsec/ipsec.secrets /etc/ipsec.secrets
COPY xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
COPY ppp/options.xl2tpd.client /etc/ppp/options.xl2tpd.client
# 复制脚本
COPY scripts/check-ipsec.sh /usr/local/bin/check-ipsec.sh
COPY scripts/check-connect.sh /usr/local/bin/check-connect.sh

# 复制路由脚本
COPY ppp/ip-up /etc/ppp/ip-up
COPY ppp/ip-down /etc/ppp/ip-down

# 复制入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/check-ipsec.sh \
    /usr/local/bin/check-connect.sh\
    /etc/ppp/ip-up \
    /etc/ppp/ip-down

# 设置入口点
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
