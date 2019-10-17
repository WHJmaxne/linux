#!/bin/bash

install_docker(){

	yum remove -y docker docker-client docker-client-latest docker-common docker-latest  docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine		
	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	yum makecache fast
	yum -y install docker-ce
	systemctl start docker
	systemctl enable docker

}

install_dockercompose(){
	
	curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose

}


install_nginx(){
	mkdir -p /opt/nginx/{logs,conf.d,certificate}
	cd /opt/nginx
	cat > docker-compose.yml <<-EOF
version: '3.4'

services:
  nginx:
    restart: always
    image: nginx:1.17
    ports:
     - 80:80
     - 443:443
    volumes:
     - ./conf.d:/etc/nginx/conf.d
     - ./logs:/var/log/nginx
     - ./certificate:/opt/certificate
EOF
	
	docker-compose up -d
}

install_ssr(){
	mkdir -p /opt/shadowsocksr
	cd /opt/shadowsocksr
	cat > config.json <<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":9000,
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"password",
    "timeout":120,
    "method":"aes-256-cfb",
    "protocol":"origin",
    "protocol_param":"",
    "obfs":"plain",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":true,
    "workers":1
}
EOF
	
	read -p "请输入端口号：" myport
	read -p "请输入密码：" mypassword
	
	sed -i "s/9000/$myport/" config.json
	sed -i "s/password/$mypassword/" config.json
	
	
	cat > Dockerfile <<-EOF
FROM python:3.6-alpine

LABEL maintainer="whjmaxne"

RUN runDeps="\
                tar \
                wget \
                libsodium-dev \
                openssl \
        "; \
        set -ex \
        && apk add --no-cache --virtual .build-deps ${runDeps} \
        && wget -O /tmp/shadowsocksr-3.2.2.tar.gz https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.2.tar.gz \
        && tar zxf /tmp/shadowsocksr-3.2.2.tar.gz -C /tmp \
        && mv /tmp/shadowsocksr-3.2.2/shadowsocks /usr/local/ \
        && rm -fr /tmp/shadowsocksr-3.2.2 \
        && rm -f /tmp/shadowsocksr-3.2.2.tar.gz

VOLUME /etc/shadowsocks-r

USER nobody

CMD [ "/usr/local/shadowsocks/server.py", "-c", "/etc/shadowsocks-r/config.json" ]
EOF
	
	cat > docker-compose.yml <<-EOF
version: '3.4'

services:
  shadowsocks:
    build:
        context: .
        dockerfile: Dockerfile
    ports:
      - "$myport:$myport/tcp"
      - "$myport:$myport/udp"
    volumes:
      - /opt/shadowsocksr:/etc/shadowsocks-r
    restart: always
EOF
	
	docker-compose up -d
	
}
