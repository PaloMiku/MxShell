#!/bin/bash
echo "<-. (\`-')    _       (\`-')      (\`-').->  _  (\`-')  (\`-')  _              (\`-')  _"
echo "   \(OO )_  (_)      (OO )_.->  ( OO)_    \-.(OO )  (OO ).-/   _          ( OO).-/"
echo ",--./  ,-.) ,-(\`-')  (_| \_)--.(_)--\_)   _.'    \  / ,---.    \-,-----. (,------."
echo "|   \`.'   | | ( OO)  \  \`.'  / /    _ /  (_...--''  | \ /\`.\    |  .--./  |  .---'"
echo "|  |'.'|  | |  |  )   \    .') \_..\`--.  |  |_.' |  '-'|_.' |  /_) (\`-') (|  '--."
echo "|  |   |  |(|  |_/    .'    \  .-._)   \ |  .___.' (|  .-.  |  ||  |OO )  |  .--'"
echo "|  |   |  | |  |'->  /  .'.  \ \       / |  |       |  | |  | (_'  '--'\  |  \`---."
echo "\`--'   \`--' \`--'    \`--'   '--' \`-----'  \`--'       \`--' \`--'    \`-----'  \`------'"

# 检查是否具有root权限
if [ "$EUID" -ne 0 ]; then
  echo "请在服务器root环境运行此脚本。"
  exit 1
fi

GREEN='\033[0;32m'
NC='\033[0m'
echo -e "${GREEN} MixSpace 一键安装脚本 版本：v1.0.0${NC}"

# 检测是否为中国大陆网络环境
USER_IP=$(curl -s --max-time 2 https://ipinfo.io/ip)
if [[ -n "$USER_IP" ]]; then
    USER_REGION=$(curl -s --max-time 2 https://ipapi.co/$USER_IP/country_name)
    echo "检测到用户地区: $USER_REGION"
    if echo "$USER_REGION" | grep -q "China"; then
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
    echo "检测到Docker已安装，已安装版本: $(docker --version)"
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
    echo "检测到Docker Compose已安装，已安装版本: $(docker-compose --version)"
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
echo "请输入存储MixSpace容器文件的目录（默认: /opt/mxspace）："
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
    echo "下载Core 需求的 Docker Compose 文件失败！请检查环境网络连接。"
    exit 1
fi

# 设置环境变量
ENV_FILE="$CORE_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  echo "已检测到容器环境变量文件: $ENV_FILE"
else
  echo "未检测到容器环境变量文件，正在创建: $ENV_FILE"
  touch "$ENV_FILE"
fi

# 提示用户输入环境变量
echo "请输入以下所需要环境变量的值："

while true; do
    read -p "JWT_SECRET：需要填写长度不小于 16 个字符，不大于 32 个字符的字符串，用于加密用户的 JWT，务必保存好自己的密钥，不要泄露给他人。按回车键随机生成一个16位的字符串: " JWT_SECRET
    if [[ -z "$JWT_SECRET" ]]; then
        JWT_SECRET=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
        echo "已为您随机生成 JWT_SECRET: $JWT_SECRET"
    fi
    if [[ -n "$JWT_SECRET" && ${#JWT_SECRET} -ge 16 && ${#JWT_SECRET} -le 32 ]]; then
        if [[ "$JWT_SECRET" =~ ^[a-zA-Z0-9].*[a-zA-Z0-9]$ ]]; then
            break
        else
            echo "输入无效，头尾不能包含特殊符号，请重新输入。"
        fi
    else
        echo "输入无效，请输入长度为 16 到 32 个字符的字符串。"
    fi
done

while true; do
    read -p "ALLOWED_ORIGINS：需要填写被允许访问的域名，通常是前端的域名，如果允许多个域名访问，用英文逗号分隔域名: " ALLOWED_ORIGINS
    # 去除首尾空格
    ALLOWED_ORIGINS=$(echo "$ALLOWED_ORIGINS" | sed 's/^ *//;s/ *$//')
    # 拆分域名
    IFS=',' read -ra DOMAINS <<< "$ALLOWED_ORIGINS"
    valid=true
    for domain in "${DOMAINS[@]}"; do
        # 去除域名前后空格
        domain=$(echo "$domain" | sed 's/^ *//;s/ *$//')
        # 检查是否包含http协议头
        if [[ "$domain" =~ ^https?:// ]]; then
            valid=false
            echo "输入无效，请不要包含http协议头，请重新输入。"
            break
        fi
        if [[ -z "$domain" ||! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
            valid=false
            echo "输入无效，请输入至少一个有效的域名，多个域名请用英文逗号分隔。"
            break
        fi
    done
    if $valid; then
        break
    fi
done

# 写入环境变量到 .env 文件
cat > "$ENV_FILE" <<EOL
JWT_SECRET=$JWT_SECRET
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOL

echo "环境变量设置完成！"

# 检查容器是否已运行
if docker-compose -f "$CORE_DIR/docker-compose.yml" ps | grep -q 'Up'; then
    echo "Core 核心容器已在运行，跳过启动步骤。"
else
    # 启动容器
    echo "正在启动容器..."
    cd "$CORE_DIR"
    docker-compose up -d

    # 检查容器状态
    if [ $? -eq 0 ]; then
        echo "Core 核心容器已成功启动！"
    else
        echo "Core 核心容器启动失败，请检查日志。"
        exit 1
    fi
fi

# 询问用户是否安装前端部分
echo "是否需要安装前端主题？(y/n，默认: y):"
read -r INSTALL_FRONTEND
INSTALL_FRONTEND=${INSTALL_FRONTEND:-y}

if [[ "$INSTALL_FRONTEND" == "y" || "$INSTALL_FRONTEND" == "Y" ]]; then
    echo "请选择要安装的前端版本:"
    echo "1) Shiro（开源版本)"
    echo "2) Shiroi（闭源版本）"
    read -p "请输入选项 (1/2，默认: 1): " FRONTEND_OPTION
    FRONTEND_OPTION=${FRONTEND_OPTION:-1}

    FRONTEND_DIR="$TARGET_DIR/frontend"
    if [ -d "$FRONTEND_DIR" ]; then
        echo "检测到前端目录已存在: $FRONTEND_DIR"
        echo "是否删除并重新创建？(y/n，默认: n):"
        read -r DELETE_FRONTEND_DIR
        DELETE_FRONTEND_DIR=${DELETE_FRONTEND_DIR:-n}
        if [[ "$DELETE_FRONTEND_DIR" == "y" || "$DELETE_FRONTEND_DIR" == "Y" ]]; then
            echo "正在删除目录: $FRONTEND_DIR"
            rm -rf "$FRONTEND_DIR"
        else
            echo "保留现有目录，继续使用: $FRONTEND_DIR"
        fi
    fi
    mkdir -p "$FRONTEND_DIR"

    case "$FRONTEND_OPTION" in
        1)
            # 安装Shiro
            if [[ "$IS_CN_NETWORK" == true ]]; then
                GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
            else
                GITHUB_MIRROR="https://raw.githubusercontent.com"
            fi
            COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/shiro/docker-compose.yml"
            echo "正在下载 Shiro 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $FRONTEND_DIR/docker-compose.yml"
            wget -O "$FRONTEND_DIR/docker-compose.yml" "$COMPOSE_FILE_URL"
            if [ $? -ne 0 ]; then
                echo "下载 Shiro 需求的 Docker Compose 文件失败！请检查环境网络连接。"
                exit 1
            fi

            # 设置 Shiro 环境变量
            ENV_FILE="$FRONTEND_DIR/.env"

            # 提示用户输入环境变量
            echo "请输入以下所需要环境变量的值："

            while true; do
                read -p "NEXT_PUBLIC_API_URL：请输入有效的 API URL: " NEXT_PUBLIC_API_URL
                NEXT_PUBLIC_API_URL=$(echo "$NEXT_PUBLIC_API_URL" | sed 's/^ *//;s/ *$//')
                if [[ "$NEXT_PUBLIC_API_URL" =~ ^https?:// ]]; then
                    if [[ -n "$NEXT_PUBLIC_API_URL" && "$NEXT_PUBLIC_API_URL" =~ ^https?://([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,} ]]; then
                        break
                    else
                        echo "输入无效，请输入有效的 API URL。"
                    fi
                else
                    echo "输入无效，请包含http或https协议头。"
                fi
            done

            while true; do
                read -p "NEXT_PUBLIC_GATEWAY_URL：请输入有效的 Gateway URL: " NEXT_PUBLIC_GATEWAY_URL
                NEXT_PUBLIC_GATEWAY_URL=$(echo "$NEXT_PUBLIC_GATEWAY_URL" | sed 's/^ *//;s/ *$//')
                if [[ "$NEXT_PUBLIC_GATEWAY_URL" =~ ^https?:// ]]; then
                    if [[ -n "$NEXT_PUBLIC_GATEWAY_URL" && "$NEXT_PUBLIC_GATEWAY_URL" =~ ^https?://([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,} ]]; then
                        break
                    else
                        echo "输入无效，请输入有效的 Gateway URL。"
                    fi
                else
                    echo "输入无效，请包含http或https协议头。"
                fi
            done

            cat > "$ENV_FILE" <<EOL
NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
NEXT_PUBLIC_GATEWAY_URL=$NEXT_PUBLIC_GATEWAY_URL
SHIRO_IMAGE=innei/shiro:latest
ENABLE_EXPERIMENTAL_COREPACK=1
EOL

            # 启动Shiro容器
            echo "正在启动 Shiro 容器..."
            cd "$FRONTEND_DIR"
            docker-compose up -d

            if [ $? -eq 0 ]; then
                echo "Shiro 前端容器已成功启动！"
            else
                echo "Shiro 前端容器启动失败，请检查日志。"
                exit 1
            fi
            ;;
        2)
            # 安装Shiroi（闭源版本）
            echo "在安装Shiroi闭源版本之前，请确保你已捐赠并构建Shiroi的闭源镜像，可参考社区部署教程了解如何构建自己的Shiroi镜像。"

            if [[ "$IS_CN_NETWORK" == true ]]; then
                GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
            else
                GITHUB_MIRROR="https://raw.githubusercontent.com"
            fi
            COMPOSE_FILE_URL="$GITHUB_MIRROR/Innei/Shiro/refs/heads/main/docker-compose.yml"
            echo "正在下载 Shiro 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $FRONTEND_DIR/docker-compose.yml"
            wget -O "$FRONTEND_DIR/docker-compose.yml" "$COMPOSE_FILE_URL"
            if [ $? -ne 0 ]; then
                echo "下载 Shiro 需求的 Docker Compose 文件失败！请检查环境网络连接。"
                exit 1
            fi

            # 提示用户输入 SHIRO_IMAGE 环境变量
            while true; do
                read -p "请输入 SHIRO_IMAGE（私有镜像） 的值（例如：your-dockerhub-username/shiroi:tag）: " SHIRO_IMAGE
                if [[ "$SHIRO_IMAGE" =~ ^[a-z0-9]+([._-]?[a-z0-9]+)*\/[a-z0-9]+([._-]?[a-z0-9]+)*(:[a-zA-Z0-9._-]+)?$ ]]; then
                    break
                else
                    echo "输入无效，请输入正确的 Docker 镜像格式（例如：your-dockerhub-username/shiroi:tag）。"
                fi
            done

            # 写入环境变量到 .env 文件
            ENV_FILE="$FRONTEND_DIR/.env"
            echo "SHIRO_IMAGE=$SHIRO_IMAGE" >> "$ENV_FILE"
            echo "SHIRO_IMAGE 环境变量已设置为: $SHIRO_IMAGE"

            # 询问用户是否需要登录 Docker 私有仓库
            echo "是否需要登录 Docker 私有仓库？(y/n，默认: n):"
            read -r LOGIN_PRIVATE_REGISTRY
            LOGIN_PRIVATE_REGISTRY=${LOGIN_PRIVATE_REGISTRY:-n}

            if [[ "$LOGIN_PRIVATE_REGISTRY" == "y" || "$LOGIN_PRIVATE_REGISTRY" == "Y" ]]; then
                echo "请输入 Docker 私有仓库地址（默认: ghcr.io）:"
                read -r PRIVATE_REGISTRY
                PRIVATE_REGISTRY=${PRIVATE_REGISTRY:-ghcr.io}

                echo "请输入 Docker 私有仓库的用户名:"
                read -r REGISTRY_USERNAME

                echo "请输入 Docker 私有仓库的密码:"
                read -sr REGISTRY_PASSWORD

                echo "正在登录 Docker 私有仓库: $PRIVATE_REGISTRY"
                echo "$REGISTRY_PASSWORD" | docker login "$PRIVATE_REGISTRY" -u "$REGISTRY_USERNAME" --password-stdin

                if [ $? -eq 0 ]; then
                    echo "成功登录 Docker 私有仓库: $PRIVATE_REGISTRY"
                else
                    echo "登录 Docker 私有仓库失败，请检查用户名和密码。"
                    exit 1
                fi
            fi

            # 启动 Shiroi 容器
            echo "正在启动 Shiroi 容器..."
            cd "$FRONTEND_DIR"
            docker-compose up -d

            if [ $? -eq 0 ]; then
                echo "Shiroi 前端容器已成功启动！"
            else
                echo "Shiroi 前端容器启动失败，请检查日志。"
                exit 1
            fi
            ;;
    esac
fi
