#!/usr/bin/env bash
#===============================================================================
#
#          FILE: chatgpt-proxy.sh
#
#         USAGE: ./chatgpt-proxy.sh
#
#   DESCRIPTION: 使用AccessToken访问ChatGPT，绕过CF验证;支持CentOS与Ubuntu
#
#  ORGANIZATION: DingQz dqzboy.com
#===============================================================================
SETCOLOR_SKYBLUE="echo -en \\E[1;36m"
SETCOLOR_SUCCESS="echo -en \\E[0;32m"
SETCOLOR_NORMAL="echo  -en \\E[0;39m"
SETCOLOR_RED="echo  -en \\E[0;31m"
SETCOLOR_YELLOW="echo -en \\E[1;33m"

echo
cat << EOF

         ██████╗██╗  ██╗ █████╗ ████████╗ ██████╗ ██████╗ ████████╗    ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗
        ██╔════╝██║  ██║██╔══██╗╚══██╔══╝██╔════╝ ██╔══██╗╚══██╔══╝    ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
        ██║     ███████║███████║   ██║   ██║  ███╗██████╔╝   ██║       ██████╔╝██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝ 
        ██║     ██╔══██║██╔══██║   ██║   ██║   ██║██╔═══╝    ██║       ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝  
        ╚██████╗██║  ██║██║  ██║   ██║   ╚██████╔╝██║        ██║       ██║     ██║  ██║╚██████╔╝██╔╝ ██╗   ██║   
         ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝        ╚═╝       ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   
                                                                                                         
EOF

SUCCESS() {
  ${SETCOLOR_SUCCESS} && echo "------------------------------------< $1 >-------------------------------------"  && ${SETCOLOR_NORMAL}
}

SUCCESS1() {
  ${SETCOLOR_SUCCESS} && echo " $1 "  && ${SETCOLOR_NORMAL}
}

ERROR() {
  ${SETCOLOR_RED} && echo " $1 "  && ${SETCOLOR_NORMAL}
}

INFO() {
  ${SETCOLOR_SKYBLUE} && echo "------------------------------------ $1 -------------------------------------"  && ${SETCOLOR_NORMAL}
}

WARN() {
  ${SETCOLOR_YELLOW} && echo " $1 "  && ${SETCOLOR_NORMAL}
}

function CHECK_CPU() {
# 判断当前操作系统是否为ARM架构
if [[ "$(uname -m)" == "arm"* ]]; then
    WARN "This script is not supported on ARM architecture. Exiting..."
    exit 1
fi

# 如果不是ARM架构则会执行到这里
WARN "This script is supported on this system. Continuing with other commands..."
}

text="检测服务器是否能够访问chat.openai.com"
width=75
padding=$((($width - ${#text}) / 2))


function CHECK_OPENAI() {
SUCCESS "提示"
printf "%*s\033[31m%s\033[0m%*s\n" $padding "" "$text" $padding ""
SUCCESS "END"

url="https://chat.openai.com"

# 检测是否能够访问chat.openai.com
echo "Testing connection to ${url}..."
if curl --output /dev/null --silent --head --fail "${url}"; then
  echo "Connection successful!"
  URL="OK"
else
  echo "Could not connect to ${url}."
  INFO "强制安装"
  read -e -p "Do you want to force install dependencies? (y/n)：" force_install
fi
}


function CHECK_OS() {
if [ -f /etc/redhat-release ]; then
    SUCCESS "系统环境检测中，请稍等..."
    INFO "《This is CentOS.》"
    OS="centos"
elif [ -f /etc/lsb-release ]; then
    if grep -q "DISTRIB_ID=Ubuntu" /etc/lsb-release; then
        SUCCESS "系统环境检测中，请稍等..."
        INFO "《This is Ubuntu.》"
        OS="ubuntu"
        systemctl restart systemd-resolved
    else
        ERROR "Unknown Linux distribution."
        exit 1
    fi
else
    ERROR "Unknown Linux distribution."
    exit 2
fi
}

function INSTALL_DOCKER() {
if [ "$OS" == "centos" ]; then
    if ! command -v docker &> /dev/null;then
      ERROR "docker 未安装，正在进行安装..."
      yum -y install yum-utils | grep -E "ERROR|ELIFECYCLE|WARN"
      yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo | grep -E "ERROR|ELIFECYCLE|WARN"
      yum -y install docker-ce | grep -E "ERROR|ELIFECYCLE|WARN"
      SUCCESS1 "docker --version"
      systemctl restart docker | grep -E "ERROR|ELIFECYCLE|WARN"
      systemctl enable docker &>/dev/null
    else 
      echo "docker 已安装..."
      SUCCESS1 "docker --version"
      systemctl restart docker | grep -E "ERROR|ELIFECYCLE|WARN"
    fi
elif [ "$OS" == "ubuntu" ]; then
    if ! command -v docker &> /dev/null;then
      ERROR "docker 未安装，正在进行安装..."
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" <<< $'\n' | grep -E "ERROR|ELIFECYCLE|WARN"
      apt-get -y install docker-ce docker-ce-cli containerd.io | grep -E "ERROR|ELIFECYCLE|WARN"
      SUCCESS1 "docker --version"
      systemctl restart docker | grep -E "ERROR|ELIFECYCLE|WARN"
      systemctl enable docker &>/dev/null
    else
      echo "docker 已安装..."  
      SUCCESS1 "docker --version"
      systemctl restart docker | grep -E "ERROR|ELIFECYCLE|WARN"
    fi
else
    ERROR "Unsupported operating system."
    exit 1
fi
}

function INSTALL_COMPOSE() {
# 根据系统类型执行不同的命令
if [ "$OS" == "centos" ]; then
   if ! command -v docker-compose &> /dev/null;then
      ERROR "docker-compose 未安装，正在进行安装..."
      curl -sL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-`uname -s`-`uname -m` -o /usr/bin/docker-compose | grep -E "ERROR|ELIFECYCLE|WARN"
      chmod +x /usr/bin/docker-compose
      SUCCESS1 "docker-compose --version"
    else
      echo "docker-compose 已安装..."  
      SUCCESS1 "docker-compose --version"
    fi
elif [ "$OS" == "ubuntu" ]; then
    if ! command -v docker-compose &> /dev/null;then
       ERROR "docker-compose 未安装，正在进行安装..."
       curl -sL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-`uname -s`-`uname -m` -o /usr/bin/docker-compose | grep -E "ERROR|ELIFECYCLE|WARN"
       chmod +x /usr/bin/docker-compose
       SUCCESS1 "docker-compose --version"
    else
      echo "docker-compose 已安装..."  
      SUCCESS1 "docker-compose --version" 
    fi
else
    ERROR "Unsupported operating system."
    exit 1
fi
}

function CONFIG() {
DOCKER_DIR="/data/go-chatgpt-api"
mkdir -p ${DOCKER_DIR}
read -e -p "请输入使用的模式（api/warp）：" mode

if [ "$mode" == "api" ]; then
cat > ${DOCKER_DIR}/docker-compose.yml <<\EOF
version: "3"
services:
  go-chatgpt-api:
    container_name: go-chatgpt-api
    image: linweiyuan/go-chatgpt-api
    ports:
      - 8080:8080  # 容器端口映射到宿主机8080端口；宿主机监听端口可按需改为其它端口
    environment:
      - GIN_MODE=release
      - CHATGPT_PROXY_SERVER=http://chatgpt-proxy-server:9515
      #- NETWORK_PROXY_SERVER=http://host:port     # NETWORK_PROXY_SERVER：科学上网代理地址，例如：http://10.0.5.10:7890
      #- NETWORK_PROXY_SERVER=socks5://host:port   # NETWORK_PROXY_SERVER：科学上网代理地址
    depends_on:
      - chatgpt-proxy-server
    restart: unless-stopped

  chatgpt-proxy-server:
    container_name: chatgpt-proxy-server
    image: linweiyuan/chatgpt-proxy-server
    restart: unless-stopped
EOF
elif [ "$mode" == "warp" ]; then
cat > ${DOCKER_DIR}/docker-compose.yml <<\EOF
version: "3"
services:
  go-chatgpt-api:
    container_name: go-chatgpt-api
    image: linweiyuan/go-chatgpt-api
    ports:
      - 8080:8080    # 容器端口映射到宿主机8080端口；宿主机监听端口可按需改为其它端口
    environment:
      - GIN_MODE=release
      - CHATGPT_PROXY_SERVER=http://chatgpt-proxy-server:9515
      - NETWORK_PROXY_SERVER=socks5://chatgpt-proxy-server-warp:65535
      #国内机器NETWORK_PROXY_SERVER 填 http://代理地址:prot 或者socks5://代理地址:prot（换掉 warp 配置）
    depends_on:
      - chatgpt-proxy-server
      - chatgpt-proxy-server-warp
    restart: unless-stopped

  chatgpt-proxy-server:
    container_name: chatgpt-proxy-server
    image: linweiyuan/chatgpt-proxy-server
    environment:
      - LOG_LEVEL=INFO
    restart: unless-stopped

  chatgpt-proxy-server-warp:
    container_name: chatgpt-proxy-server-warp
    image: linweiyuan/chatgpt-proxy-server-warp
    environment:
      - LOG_LEVEL=INFO
    restart: unless-stopped
EOF
else
  ERROR "Invalid or missing parameter"
  exit 1
fi

# 提示用户是否需要修改配置
read -e -p "Do you want to add a proxy address? (y/n)：" modify_config
case $modify_config in
  [Yy]* )
    # 获取用户输入的URL及其类型
    read -e -p "Enter the URL (e.g. host:port): " url
    while true; do
      read -e -p "Is this a http or socks5 proxy? (http/socks5)：" type
      case $type in
          [Hh][Tt]* ) url_type="http"; break;;
          [Ss][Oo]* ) url_type="socks5"; break;;
          * ) echo "Please answer http or socks5.";;
      esac
    done
    
    # 根据类型更新docker-compose.yml文件
    if [ "$mode" == "api" ]; then
       if [ "$url_type" == "http" ]; then
          sed -i "s|#- NETWORK_PROXY_SERVER=http://host:port|- NETWORK_PROXY_SERVER=http://${url}|g" ${DOCKER_DIR}/docker-compose.yml
       elif [ "$url_type" == "socks5" ]; then
          sed -i "s|#- NETWORK_PROXY_SERVER=socks5://host:port|- NETWORK_PROXY_SERVER=socks5://${url}|g" ${DOCKER_DIR}/docker-compose.yml
       fi
    elif [ "$mode" == "warp" ]; then
       if [ "$url_type" == "http" ]; then
          sed -i "s|- NETWORK_PROXY_SERVER=socks5://chatgpt-proxy-server-warp:65535|- NETWORK_PROXY_SERVER=http://${url}|g" ${DOCKER_DIR}/docker-compose.yml
       elif [ "$url_type" == "socks5" ]; then
          sed -i "s|- NETWORK_PROXY_SERVER=socks5://chatgpt-proxy-server-warp:65535|- NETWORK_PROXY_SERVER=socks5://${url}|g" ${DOCKER_DIR}/docker-compose.yml
       fi
    else
       echo "Do not modify！"
    fi
    echo "Updated docker-compose.yml with ${url_type} proxy server at ${url}."
    ;;
  [Nn]* )
    WARN "Skipping configuration modification."
    ;;
  * )
    ERROR "Invalid input. Skipping configuration modification."
    ;;
esac

}

function INSTALL_PROXY() {
# 确认是否强制安装
if [[ "$force_install" = "y" ]]; then
    # 强制安装代码
    echo "开始强制安装..."
    INSTALL_DOCKER
    INSTALL_COMPOSE
    CONFIG
    cd ${DOCKER_DIR} && docker-compose up -d && docker ps -a --filter "name=chatgpt" | grep -v "^CONTAINER"
elif [[ "$URL" = "OK" ]];then
    # 强制安装代码
    echo "开始安装..."
    INSTALL_DOCKER
    INSTALL_COMPOSE
    CONFIG
    cd ${DOCKER_DIR} && docker-compose up -d && docker ps -a --filter "name=chatgpt" | grep -v "^CONTAINER" 
else
    ERROR "已取消安装."
    exit 0
fi
}

main() {
  CHECK_CPU
  CHECK_OPENAI
  CHECK_OS
  INSTALL_PROXY
}
main
