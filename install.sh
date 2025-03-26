#!/bin/bash

# 问题出在代码里使用了 `[[` 这样的操作符，它是 Bash 特有的，在 `/bin/sh` 中不被支持。
# 同时，你用 `sh install.sh` 运行脚本，`sh` 可能指向 `/bin/dash` 之类的非 Bash 解释器。
# 下面是修改后的代码，将运行方式改为用 `bash` 执行，避免使用 `[[` 操作符。
# 检测是否为中国大陆网络环境
USER_IP=$(curl -s --max-time 2 https://ipinfo.io/ip)
if [ -n "$USER_IP" ]; then
    echo "检测到用户IP: $USER_IP"
    COUNTRY=$(curl -s --max-time 2 https://ipapi.co/$USER_IP/country)
    if echo "$COUNTRY" | grep -q "CN"; then
        echo "检测到中国大陆网络环境。"
        export IS_CN_NETWORK=true
    else
        echo "检测到非中国大陆网络环境。"
        export IS_CN_NETWORK=false
    fi
else
    echo "无法检测用户IP，默认设置为非中国大陆网络环境。"
    export IS_CN_NETWORK=false
fi
# 检测系统架构
ARCH=$(uname -m)
echo "检测到系统架构: $ARCH"

# 检测系统发行版
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  VERSION=$VERSION_ID
else
  echo "无法检测系统发行版。"
  exit 1
fi
echo "检测到系统发行版: $OS $VERSION"

# 检查是否已安装Docker
if command -v docker &> /dev/null; then
    echo "检测到Docker已安装，版本: $(docker --version)"
else
    # 根据架构和发行版安装对应的Docker版本
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "aarch64" ]]; then
      if [[ "$OS" == "centos" ]]; then
        echo "安装适用于CentOS的Docker..."
        if [[ "$IS_CN_NETWORK" == true ]]; then
          echo "检测到中国大陆网络环境，使用阿里云源安装Docker..."
          curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
          yum install -y docker-ce docker-ce-cli containerd.io
        else
          curl -fsSL https://get.docker.com | bash
        fi
      elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        echo "安装适用于Ubuntu/Debian的Docker..."
        if [[ "$IS_CN_NETWORK" == true ]]; then
          echo "检测到中国大陆网络环境，使用阿里云源安装Docker..."
          curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$OS/gpg | apt-key add -
          add-apt-repository "deb [arch=$ARCH] https://mirrors.aliyun.com/docker-ce/linux/$OS $(lsb_release -cs) stable"
          apt-get update
          apt-get install -y docker-ce docker-ce-cli containerd.io
        else
          curl -fsSL https://get.docker.com | bash
        fi
      else
        echo "不支持的发行版: $OS"
        exit 1
      fi
    else
      echo "不支持的架构: $ARCH"
      exit 1
    fi

    # 启动并启用Docker服务
    echo "启动并启用Docker服务..."
    systemctl start docker
    systemctl enable docker
    echo "Docker安装完成！"
fi

# 检查是否已安装Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "检测到Docker Compose已安装，版本: $(docker-compose --version)"
else
    echo "开始安装Docker Compose..."
    if [[ "$IS_CN_NETWORK" == true ]]; then
      echo "检测到中国大陆网络环境，使用阿里云源安装Docker Compose..."
      curl -L "https://mirrors.aliyun.com/docker-toolbox/linux/compose/$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    else
      curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    fi

    # 设置执行权限
    chmod +x /usr/local/bin/docker-compose

    # 验证安装
    if docker-compose --version &>/dev/null; then
      echo "Docker Compose安装完成！版本: $(docker-compose --version)"
    else
      echo "Docker Compose安装失败，请检查网络或权限设置。"
      exit 1
    fi
fi

# 询问用户是否需要设置Docker国内源
echo "是否需要设置Docker镜像源？(y/n，默认: y):"
read -r SET_DOCKER_MIRROR
SET_DOCKER_MIRROR=${SET_DOCKER_MIRROR:-y}

if [[ "$SET_DOCKER_MIRROR" == "y" || "$SET_DOCKER_MIRROR" == "Y" ]]; then
    echo "请选择一个镜像源:"
    echo "1) https://docker.1ms.run （毫秒镜像）"
    echo "2) https://hub.rat.dev/ （耗子镜像）"
    read -p "请输入选项 (1/2，默认: 1): " MIRROR_OPTION
    MIRROR_OPTION=${MIRROR_OPTION:-1}

    if [[ "$MIRROR_OPTION" == "1" ]]; then
        MIRROR_URL="https://docker.1ms.run"
    elif [[ "$MIRROR_OPTION" == "2" ]]; then
        MIRROR_URL="https://hub.rat.dev"
    else
        echo "无效选项，使用Docker官方源。"
        MIRROR_URL="https://registry-1.docker.io"
    fi

    # 配置Docker国内源
    echo "正在配置Docker镜像源: $MIRROR_URL"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOL
{
    "registry-mirrors": ["$MIRROR_URL"]
}
EOL

    # 重启Docker服务以应用配置
    systemctl daemon-reload
    systemctl restart docker
    echo "Docker国内源配置完成！"
fi

# 用户选择目录
echo "请输入MixSpace存储文件的目录（默认: /opt/mxspace）："
read -r TARGET_DIR
TARGET_DIR=${TARGET_DIR:-/opt/mxspace}

# 创建目标目录（如果不存在）
if [ ! -d "$TARGET_DIR" ]; then
  echo "目标目录不存在，正在创建: $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
fi

# 下载指定的Docker Compose文件到指定目录的/core文件夹
CORE_DIR="$TARGET_DIR/core"
mkdir -p "$CORE_DIR"
if [[ "$IS_CN_NETWORK" == true ]]; then
    GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
else
    GITHUB_MIRROR="https://raw.githubusercontent.com"
fi
COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/core/docker-compose.yml" # 替换为实际文件路径
echo "正在下载 Core 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $CORE_DIR/docker-compose.yml"
wget -O "$CORE_DIR/docker-compose.yml" "$COMPOSE_FILE_URL"

# 检查下载是否成功
if [ $? -ne 0 ]; then
    echo "下载Docker Compose文件失败，请检查文件地址或网络连接。"
    exit 1
fi

# 设置环境变量
ENV_FILE="$CORE_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  echo "检测到环境变量文件: $ENV_FILE"
else
  echo "未检测到环境变量文件，正在创建: $ENV_FILE"
  touch "$ENV_FILE"
fi

# 提示用户输入环境变量
echo "请输入以下所需要环境变量的值："

while true; do
    read -p "JWT_SECRET 需要填写长度不小于 16 个字符，不大于 32 个字符的字符串，用于加密用户的 JWT，务必保存好自己的密钥，不要泄露给他人: " JWT_SECRET
    if [[ -n "$JWT_SECRET" && ${#JWT_SECRET} -ge 16 && ${#JWT_SECRET} -le 32 ]]; then
        break
    else
        echo "输入无效，请输入长度为 16 到 32 个字符的字符串。"
    fi
done

while true; do
    read -p "ALLOWED_ORIGINS 需要填写被允许访问的域名，通常是前端的域名，如果允许多个域名访问，用英文逗号分隔域名: " ALLOWED_ORIGINS
    if [[ -n "$ALLOWED_ORIGINS" ]]; then
        break
    else
        echo "输入无效，请输入至少一个域名。"
    fi
done

# 写入环境变量到 .env 文件
cat > "$ENV_FILE" <<EOL
JWT_SECRET=$JWT_SECRET
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOL

echo "环境变量设置完成！"

# 启动容器
echo "正在启动容器..."
cd "$CORE_DIR"
docker-compose up -d

# 检查容器状态
if [ $? -eq 0 ]; then
    echo "容器已成功启动！"
else
    echo "容器启动失败，请检查日志。"
    exit 1
fi
