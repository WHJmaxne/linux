#!/bin/bash

install_docker(){

	yum remove -y docker docker-client docker-client-latest docker-common docker-latest  docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine		
	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	yum makecache fast
	yum -y install docker-ce
	systemctl start docker
	systemctl enable docker
	echo "安装成功"
	start_menu
}

install_dockercompose(){
	
	curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	echo "安装成功"
	start_menu
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
	
	cat > conf.d/default.conf <<-EOF
server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
}
EOF
	
	docker-compose up -d
	echo "安装成功"
	start_menu
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
    "password":"password1",
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
	sed -i "s/password1/$mypassword/" config.json
	
	
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
	echo "安装成功"
	start_menu
}

install_ngrok(){
  mkdir -p /opt/ngrok/bin
  cd /opt/ngrok
  read -p "请输入域名：" domain
  cat > build.sh <<-EOF
export NGROK_DOMAIN="$domain"
cd /ngrok/
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$NGROK_DOMAIN" -days 5000 -out rootCA.pem
openssl genrsa -out device.key 2048
openssl req -new -key device.key -subj "/CN=$NGROK_DOMAIN" -out device.csr
openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days 5000
cp rootCA.pem assets/client/tls/ngrokroot.crt
cp device.crt assets/server/tls/snakeoil.crt
cp device.key assets/server/tls/snakeoil.key

make release-server
GOOS=linux GOARCH=386 make release-client
GOOS=linux GOARCH=amd64 make release-client
GOOS=windows GOARCH=386 make release-client
GOOS=windows GOARCH=amd64 make release-client
GOOS=darwin GOARCH=386 make release-client
GOOS=darwin GOARCH=amd64 make release-client
GOOS=linux GOARCH=arm make release-client

mkdir -p /var/ngrok
cp -r /ngrok/bin/* /var/ngrok
EOF
  cat > Dockerfile <<-EOF
FROM golang:1.7.1-alpine
ADD build.sh /
RUN apk add --no-cache git make openssl
RUN git clone https://github.com/inconshreveable/ngrok.git --depth=1 /ngrok
RUN sh /build.sh
EXPOSE 8081
VOLUME [ "/ngrok" ]
CMD [ "/ngrok/bin/ngrokd"]
EOF
  cat > docker-compose.yml <<-EOF
version: '3'

services:
    ngrok:
      networks: 
        - app
      restart: always
      build:
        context: .
        dockerfile: Dockerfile
      ports:
        - 8081:8081
        - 4443:4443
      command:
        - /ngrok/bin/ngrokd
        - -domain=ngrok.maxne.club
        - -httpAddr=:8081
      volumes:
        - ./bin:/var/ngrok

networks:
   app:
     driver: bridge
EOF
  docker-compose up -d
  echo "安装成功"
	start_menu
}

remove_ngrok)(){
  cd /opt/ngrok
  docker-compose down --rmi all
	rm -rf /opt/ngrok/*
	echo "卸载成功"
	start_menu
}

remove_nginx(){
	cd /opt/nginx
	docker-compose down --rmi all
	rm -rf /opt/nginx/*
	echo "卸载成功"
	start_menu
}

remove_ssr(){
	cd /opt/shadowsocksr
	docker-compose down --rmi all
	rm -rf /opt/shadowsocksr/*
	echo "卸载成功"
	start_menu
}

start_menu(){
    echo "========================="
    echo " 介绍：适用于CentOS7"
    echo " 作者：whjmaxne"
    echo " 邮箱：whjmaxne@outlook.com"
    echo "========================="
    echo "1. 安装docker"
    echo "2. 安装docker-compose"
    echo "3. 安装nginx"
    echo "4. 卸载nginx"
    echo "5. 安装ssr"
    echo "6. 卸载ssr"
    echo "7. 安装ngrok"
    echo "8. 卸载ngrok"
    echo "999. 退出"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
		install_docker
		;;
		2)
		install_dockercompose
		;;
		3)
		install_nginx
		;;
		4)
		remove_nginx
		;;
		5)
		install_ssr
		;;
		6)
		remove_ssr
		;;
    7)
		install_ngrok
		;;
		8)
		remove_ngrok
		;;
		999)
		exit 1
		;;
		*)
		echo "请输入正确数字"
		sleep 5s
		start_menu
		;;
    esac
}
clear
start_menu
