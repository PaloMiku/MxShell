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
echo -e "${GREEN} MixSpace 前后端一键安装脚本 版本：v1.0.0${NC}"

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

# 检查是否安装 python3
if command -v python3 &> /dev/null; then
    echo "已检测到 python3，版本: $(python3 --version)"
else
    echo "未检测到 python3，正在安装..."
    if [[ "$OS" == "centos" ]]; then
        yum install -y python3
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y python3
    else
        echo "不支持的发行版: $OS"
        exit 1
    fi
fi

# 检查是否安装 pyyaml
if python3 -c "import yaml" &> /dev/null; then
    echo "已检测到 pyyaml 模块。"
else
    echo "未检测到 pyyaml，正在安装..."
    python3 -m ensurepip --upgrade
    python3 -m pip install pyyaml
fi

# 检查是否安装 wget
if command -v wget &> /dev/null; then
    echo "已检测到 wget，版本: $(wget --version | head -n 1)"
else
    echo "未检测到 wget，正在安装..."
    if [[ "$OS" == "centos" ]]; then
        yum install -y wget
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y wget
    else
        echo "不支持的发行版: $OS"
        exit 1
    fi
fi

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


# 根据网络环境设置Docker镜像源
if [[ "$IS_CN_NETWORK" == true ]]; then
    echo "检测到中国大陆网络环境，正在配置Docker国内镜像源..."

    # 配置Docker国内源
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOL
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://hub.rat.dev"
    ]
}
EOL

    # 重启Docker服务以应用配置
    systemctl daemon-reload
    systemctl restart docker
    echo "Docker国内镜像源配置完成！"
else
    echo "检测到非中国大陆网络环境，无需设置Docker镜像源。"
fi

# 定义一个函数解析 YAML 文件
yaml-parser() {
    python3 -c "
import yaml, sys, json
try:
    with open('$1', 'r') as f:
        config = yaml.safe_load(f)
    def print_config(config, prefix=''):
        for key, value in config.items():
            env_key = (prefix + key).upper()
            if isinstance(value, str):
                print(f'{env_key}=\"{value}\"')
            elif isinstance(value, list):
                print(f'{env_key}=\"{\",\".join([str(x) for x in value])}\"')
            elif isinstance(value, dict):
                print_config(value, prefix=prefix + key + '_')
            elif isinstance(value, bool):
                print(f'{env_key}={str(value).lower()}')
            elif value is None:
                print(f'{env_key}=\"\"')
            elif isinstance(value, (int, float)):
                print(f'{env_key}={value}')
            else:
                print(f'{env_key}=\"{json.dumps(value)}\"')
    print_config(config)
except Exception as e:
    print(f'解析错误: {str(e)}', file=sys.stderr)
    sys.exit(1)
"
}

# 检查 yaml-parser 函数是否可用
if ! declare -f yaml-parser &> /dev/null; then
    echo "yaml-parser 函数未定义，可能缺少依赖，请检查脚本或安装必要的依赖。"
    exit 1
fi

# 检查是否存在 mxconfig.yml 文件
CONFIG_FILE="./mxconfig.yml"
if [ -f "$CONFIG_FILE" ]; then
    echo "检测到配置文件: $CONFIG_FILE，正在加载预配置的环境变量..."
    # 先将解析结果输出到临时文件以便调试
    TEMP_ENV_FILE=$(mktemp)
    yaml-parser "$CONFIG_FILE" > "$TEMP_ENV_FILE"
    
    if [ $? -ne 0 ]; then
        echo "解析配置文件失败，请检查 mxconfig.yml 格式是否正确。"
        cat "$TEMP_ENV_FILE"
        rm -f "$TEMP_ENV_FILE"
        exit 1
    fi
    
    echo "解析的配置内容:"
    cat "$TEMP_ENV_FILE"
    
    # 加载配置到环境变量
    source "$TEMP_ENV_FILE"
    rm -f "$TEMP_ENV_FILE"
    
    echo "成功从配置文件加载以下变量:"
    if [ -n "$JWT_SECRET" ]; then echo "- JWT_SECRET: (已设置，值已隐藏)"; fi
    if [ -n "$ALLOWED_ORIGINS" ]; then echo "- ALLOWED_ORIGINS: $ALLOWED_ORIGINS"; fi
    if [ -n "$TARGET_DIR" ]; then echo "- TARGET_DIR: $TARGET_DIR"; fi
    if [ -n "$FRONTEND_INSTALL" ]; then echo "- FRONTEND_INSTALL: $FRONTEND_INSTALL"; fi
    if [ -n "$FRONTEND_VERSION" ]; then echo "- FRONTEND_VERSION: $FRONTEND_VERSION"; fi
    if [ -n "$FRONTEND_NEXT_PUBLIC_API_URL" ]; then echo "- NEXT_PUBLIC_API_URL: $FRONTEND_NEXT_PUBLIC_API_URL"; fi
    if [ -n "$FRONTEND_NEXT_PUBLIC_GATEWAY_URL" ]; then echo "- NEXT_PUBLIC_GATEWAY_URL: $FRONTEND_NEXT_PUBLIC_GATEWAY_URL"; fi
    if [ -n "$FRONTEND_SHIRO_IMAGE" ]; then echo "- SHIRO_IMAGE: $FRONTEND_SHIRO_IMAGE"; fi
    
    # 检查关键变量是否已加载
    if [ -z "$JWT_SECRET" ] && [ -z "$ALLOWED_ORIGINS" ]; then
        echo "警告: 未能从配置文件加载任何预期的变量，可能配置文件格式不正确。"
        echo "将切换到交互式配置方式。"
    fi
else
    echo "未检测到配置文件: $CONFIG_FILE，将使用交互式配置方式。"
fi

# 用户选择目录
if [ -z "$TARGET_DIR" ]; then
    echo "请输入存储MixSpace容器文件的目录（默认: /opt/mxspace）："
    read -r TARGET_DIR
    TARGET_DIR=${TARGET_DIR:-/opt/mxspace}
else
    echo "使用从配置文件加载的TARGET_DIR: $TARGET_DIR"
fi

# 检查目标目录是否存在
if [ -d "$TARGET_DIR" ]; then
    echo "目标目录已存在: $TARGET_DIR"
    # 如果配置文件已加载，则直接删除并重新创建目录
    if [ -f "$CONFIG_FILE" ]; then
        echo "检测到配置文件已加载，直接删除并重新创建目录..."
        rm -rf "$TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    else
        # 否则交互式询问用户
        echo "是否删除并重新创建？(y/n，默认: n):"
        read -r DELETE_TARGET_DIR
        DELETE_TARGET_DIR=${DELETE_TARGET_DIR:-n}
        if [[ "$DELETE_TARGET_DIR" == "y" || "$DELETE_TARGET_DIR" == "Y" ]]; then
            echo "正在删除目录: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
            echo "正在重新创建目录: $TARGET_DIR"
            mkdir -p "$TARGET_DIR"
        else
            echo "保留现有目录，继续使用: $TARGET_DIR"
        fi
    fi
else
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
COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/core/docker compose.yml"
echo "正在下载 Core 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $CORE_DIR/docker compose.yml"
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

# 提示用户输入环境变量（如果未从配置文件加载）
if [ -z "$JWT_SECRET" ]; then
    echo "从配置中未检测到JWT_SECRET，需要手动输入..."
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
else
    echo "使用从配置文件加载的JWT_SECRET..."
fi

if [ -z "$ALLOWED_ORIGINS" ]; then
    echo "从配置中未检测到ALLOWED_ORIGINS，需要手动输入..."
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
else
    echo "使用从配置文件加载的ALLOWED_ORIGINS: $ALLOWED_ORIGINS"
fi

# 写入环境变量到 .env 文件
cat > "$ENV_FILE" <<EOL
JWT_SECRET=$JWT_SECRET
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOL

echo "环境变量设置完成！"

# 检查容器是否已运行
if docker compose -f "$CORE_DIR/docker-compose.yml" ps | grep -q 'Up'; then
    echo "Core 核心容器已在运行，跳过启动步骤。"
else
    # 启动容器
    echo "正在启动容器..."
    cd "$CORE_DIR"
    docker compose up -d

    # 检查容器状态
    if [ $? -eq 0 ]; then
        echo "Core 核心容器已成功启动！"
    else
        echo "Core 核心容器启动失败，请检查日志。"
        exit 1
    fi
fi

# 询问用户是否安装前端部分
if [ -z "$FRONTEND_INSTALL" ]; then
    echo "是否需要安装前端主题？(y/n，默认: y):"
    read -r INSTALL_FRONTEND
    INSTALL_FRONTEND=${INSTALL_FRONTEND:-y}
else
    echo "使用从配置文件加载的FRONTEND_INSTALL: $FRONTEND_INSTALL"
    # 将布尔值转换为 y/n 格式
    if [[ "$FRONTEND_INSTALL" == "true" || "$FRONTEND_INSTALL" == "True" || "$FRONTEND_INSTALL" == "TRUE" ]]; then
        INSTALL_FRONTEND="y"
    elif [[ "$FRONTEND_INSTALL" == "false" || "$FRONTEND_INSTALL" == "False" || "$FRONTEND_INSTALL" == "FALSE" ]]; then
        INSTALL_FRONTEND="n"
    else
        INSTALL_FRONTEND=$FRONTEND_INSTALL
    fi
fi

if [[ "$INSTALL_FRONTEND" == "y" || "$INSTALL_FRONTEND" == "Y" ]]; then
    if [ -z "$FRONTEND_VERSION" ]; then
        echo "请选择要安装的前端版本:"
        echo "1) Shiro（开源版本)"
        echo "2) Shiroi（闭源版本）"
        read -p "请输入选项 (1/2，默认: 1): " FRONTEND_OPTION
        FRONTEND_OPTION=${FRONTEND_OPTION:-1}
        FRONTEND_VERSION=$(if [ "$FRONTEND_OPTION" -eq 1 ]; then echo "Shiro"; else echo "Shiroi"; fi)
    else
        echo "使用从配置文件加载的FRONTEND_VERSION: $FRONTEND_VERSION"
    fi

    FRONTEND_DIR="$TARGET_DIR/frontend"
    if [ -d "$FRONTEND_DIR" ]; then
        echo "检测到前端目录已存在: $FRONTEND_DIR"
        # 如果配置文件已加载，则直接删除并重新创建目录
        if [ -f "$CONFIG_FILE" ]; then
            echo "检测到配置文件已加载，直接删除并重新创建前端目录..."
            rm -rf "$FRONTEND_DIR"
            mkdir -p "$FRONTEND_DIR"
        else
            echo "是否删除并重新创建？(y/n，默认: n):"
            read -r DELETE_FRONTEND_DIR
            DELETE_FRONTEND_DIR=${DELETE_FRONTEND_DIR:-n}
            if [[ "$DELETE_FRONTEND_DIR" == "y" || "$DELETE_FRONTEND_DIR" == "Y" ]]; then
                echo "正在删除目录: $FRONTEND_DIR"
                rm -rf "$FRONTEND_DIR"
                mkdir -p "$FRONTEND_DIR"
            else
                echo "保留现有目录，继续使用: $FRONTEND_DIR"
            fi
        fi
    else
        echo "前端目录不存在，正在创建: $FRONTEND_DIR"
        mkdir -p "$FRONTEND_DIR"
    fi

    case "$FRONTEND_VERSION" in
        Shiro)
            # 安装Shiro
            if [[ "$IS_CN_NETWORK" == true ]]; then
                GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
            else
                GITHUB_MIRROR="https://raw.githubusercontent.com"
            fi
            COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/shiro/docker compose.yml"
            echo "正在下载 Shiro 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $FRONTEND_DIR/docker compose.yml"
            wget -O "$FRONTEND_DIR/docker compose.yml" "$COMPOSE_FILE_URL"
            if [ $? -ne 0 ]; then
                echo "下载 Shiro 需求的 Docker Compose 文件失败！请检查环境网络连接。"
                exit 1
            fi

            # 设置 Shiro 环境变量
            ENV_FILE="$FRONTEND_DIR/.env"

            # 提示用户输入环境变量
            echo "请输入以下所需要环境变量的值："

            if [ -z "$FRONTEND_NEXT_PUBLIC_API_URL" ]; then
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
            else
                echo "使用从配置文件加载的NEXT_PUBLIC_API_URL: $FRONTEND_NEXT_PUBLIC_API_URL"
                NEXT_PUBLIC_API_URL=$FRONTEND_NEXT_PUBLIC_API_URL
            fi

            if [ -z "$FRONTEND_NEXT_PUBLIC_GATEWAY_URL" ]; then
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
            else
                echo "使用从配置文件加载的NEXT_PUBLIC_GATEWAY_URL: $FRONTEND_NEXT_PUBLIC_GATEWAY_URL"
                NEXT_PUBLIC_GATEWAY_URL=$FRONTEND_NEXT_PUBLIC_GATEWAY_URL
            fi

            cat > "$ENV_FILE" <<EOL
NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
NEXT_PUBLIC_GATEWAY_URL=$NEXT_PUBLIC_GATEWAY_URL
SHIRO_IMAGE=innei/shiro:latest
ENABLE_EXPERIMENTAL_COREPACK=1
EOL

            # 启动Shiro容器
            echo "正在启动 Shiro 容器..."
            cd "$FRONTEND_DIR"
            docker compose up -d

            if [ $? -eq 0 ]; then
                echo "Shiro 前端容器已成功启动！"
            else
                echo "Shiro 前端容器启动失败，请检查日志。"
                exit 1
            fi
            ;;
        Shiroi)
            # 安装Shiroi（闭源版本）
            echo "在安装Shiroi闭源版本之前，请确保你已捐赠并构建Shiroi的闭源镜像，可参考社区部署教程了解如何构建自己的Shiroi镜像。"

            if [[ "$IS_CN_NETWORK" == true ]]; then
                GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
            else
                GITHUB_MIRROR="https://raw.githubusercontent.com"
            fi
            COMPOSE_FILE_URL="$GITHUB_MIRROR/Innei/Shiro/refs/heads/main/docker compose.yml"
            echo "正在下载 Shiro 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $FRONTEND_DIR/docker compose.yml"
            wget -O "$FRONTEND_DIR/docker compose.yml" "$COMPOSE_FILE_URL"
            if [ $? -ne 0 ]; then
                echo "下载 Shiro 需求的 Docker Compose 文件失败！请检查环境网络连接。"
                exit 1
            fi

            # 提示用户输入 SHIRO_IMAGE 环境变量
            if [ -z "$FRONTEND_SHIRO_IMAGE" ]; then
                while true; do
                    read -p "请输入 SHIRO_IMAGE（私有镜像） 的值（例如：your-dockerhub-username/shiroi:tag）: " SHIRO_IMAGE
                    if [[ "$SHIRO_IMAGE" =~ ^[a-z0-9]+([._-]?[a-z0-9]+)*\/[a-z0-9]+([._-]?[a-z0-9]+)*(:[a-zA-Z0-9._-]+)?$ ]]; then
                        break
                    else
                        echo "输入无效，请输入正确的 Docker 镜像格式（例如：your-dockerhub-username/shiroi:tag）。"
                    fi
                done
            else
                echo "使用从配置文件加载的SHIRO_IMAGE: $FRONTEND_SHIRO_IMAGE"
                SHIRO_IMAGE=$FRONTEND_SHIRO_IMAGE
            fi

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
            docker compose up -d

            if [ $? -eq 0 ]; then
                echo "Shiroi 前端容器已成功启动！"
            else
                echo "Shiroi 前端容器启动失败，请检查日志。"
                exit 1
            fi
            ;;

    esac
    # 提示用户安装成功并输出当前时间（基于UTC+8）
    echo "前端安装成功！"
    echo "MixSpace 已经安装在你的服务器上，你可以参考官方文档自行配置反向代理。"
    echo "当前时间（UTC+8）：$(date -u -d '+8 hours' '+%Y-%m-%d %H:%M:%S')"
fi

# 根据网络环境设置Docker镜像源
if [[ "$IS_CN_NETWORK" == true ]]; then
    echo "检测到中国大陆网络环境，正在配置Docker国内镜像源..."

    # 配置Docker国内源
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOL
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://hub.rat.dev"
    ]
}
EOL

    # 重启Docker服务以应用配置
    systemctl daemon-reload
    systemctl restart docker
    echo "Docker国内镜像源配置完成！"
else
    echo "检测到非中国大陆网络环境，无需设置Docker镜像源。"
fi

# 定义一个函数解析 YAML 文件
yaml-parser() {
    python3 -c "
import yaml, sys, json
try:
    with open('$1', 'r') as f:
        config = yaml.safe_load(f)
    def print_config(config, prefix=''):
        for key, value in config.items():
            env_key = (prefix + key).upper()
            if isinstance(value, str):
                print(f'{env_key}=\"{value}\"')
            elif isinstance(value, list):
                print(f'{env_key}=\"{\",\".join([str(x) for x in value])}\"')
            elif isinstance(value, dict):
                print_config(value, prefix=prefix + key + '_')
            elif isinstance(value, bool):
                print(f'{env_key}={str(value).lower()}')
            elif value is None:
                print(f'{env_key}=\"\"')
            elif isinstance(value, (int, float)):
                print(f'{env_key}={value}')
            else:
                print(f'{env_key}=\"{json.dumps(value)}\"')
    print_config(config)
except Exception as e:
    print(f'解析错误: {str(e)}', file=sys.stderr)
    sys.exit(1)
"
}

# 检查 yaml-parser 函数是否可用
if ! declare -f yaml-parser &> /dev/null; then
    echo "yaml-parser 函数未定义，可能缺少依赖，请检查脚本或安装必要的依赖。"
    exit 1
fi

# 检查是否存在 mxconfig.yml 文件
CONFIG_FILE="./mxconfig.yml"
if [ -f "$CONFIG_FILE" ]; then
    echo "检测到配置文件: $CONFIG_FILE，正在加载预配置的环境变量..."
    # 先将解析结果输出到临时文件以便调试
    TEMP_ENV_FILE=$(mktemp)
    yaml-parser "$CONFIG_FILE" > "$TEMP_ENV_FILE"
    
    if [ $? -ne 0 ]; then
        echo "解析配置文件失败，请检查 mxconfig.yml 格式是否正确。"
        cat "$TEMP_ENV_FILE"
        rm -f "$TEMP_ENV_FILE"
        exit 1
    fi
    
    echo "解析的配置内容:"
    cat "$TEMP_ENV_FILE"
    
    # 加载配置到环境变量
    source "$TEMP_ENV_FILE"
    rm -f "$TEMP_ENV_FILE"
    
    echo "成功从配置文件加载以下变量:"
    if [ -n "$JWT_SECRET" ]; then echo "- JWT_SECRET: (已设置，值已隐藏)"; fi
    if [ -n "$ALLOWED_ORIGINS" ]; then echo "- ALLOWED_ORIGINS: $ALLOWED_ORIGINS"; fi
    if [ -n "$TARGET_DIR" ]; then echo "- TARGET_DIR: $TARGET_DIR"; fi
    if [ -n "$FRONTEND_INSTALL" ]; then echo "- FRONTEND_INSTALL: $FRONTEND_INSTALL"; fi
    if [ -n "$FRONTEND_VERSION" ]; then echo "- FRONTEND_VERSION: $FRONTEND_VERSION"; fi
    if [ -n "$FRONTEND_NEXT_PUBLIC_API_URL" ]; then echo "- NEXT_PUBLIC_API_URL: $FRONTEND_NEXT_PUBLIC_API_URL"; fi
    if [ -n "$FRONTEND_NEXT_PUBLIC_GATEWAY_URL" ]; then echo "- NEXT_PUBLIC_GATEWAY_URL: $FRONTEND_NEXT_PUBLIC_GATEWAY_URL"; fi
    if [ -n "$FRONTEND_SHIRO_IMAGE" ]; then echo "- SHIRO_IMAGE: $FRONTEND_SHIRO_IMAGE"; fi
    
    # 检查关键变量是否已加载
    if [ -z "$JWT_SECRET" ] && [ -z "$ALLOWED_ORIGINS" ]; then
        echo "警告: 未能从配置文件加载任何预期的变量，可能配置文件格式不正确。"
        echo "将切换到交互式配置方式。"
    fi
else
    echo "未检测到配置文件: $CONFIG_FILE，将使用交互式配置方式。"
fi

# 用户选择目录
if [ -z "$TARGET_DIR" ]; then
    echo "请输入存储MixSpace容器文件的目录（默认: /opt/mxspace）："
    read -r TARGET_DIR
    TARGET_DIR=${TARGET_DIR:-/opt/mxspace}
else
    echo "使用从配置文件加载的TARGET_DIR: $TARGET_DIR"
fi

# 检查目标目录是否存在
if [ -d "$TARGET_DIR" ]; then
    echo "目标目录已存在: $TARGET_DIR"
    # 如果配置文件已加载，则直接删除并重新创建目录
    if [ -f "$CONFIG_FILE" ]; then
        echo "检测到配置文件已加载，直接删除并重新创建目录..."
        rm -rf "$TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    else
        # 否则交互式询问用户
        echo "是否删除并重新创建？(y/n，默认: n):"
        read -r DELETE_TARGET_DIR
        DELETE_TARGET_DIR=${DELETE_TARGET_DIR:-n}
        if [[ "$DELETE_TARGET_DIR" == "y" || "$DELETE_TARGET_DIR" == "Y" ]]; then
            echo "正在删除目录: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
            echo "正在重新创建目录: $TARGET_DIR"
            mkdir -p "$TARGET_DIR"
        else
            echo "保留现有目录，继续使用: $TARGET_DIR"
        fi
    fi
else
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
COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/core/docker compose.yml"
echo "正在下载 Core 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $CORE_DIR/docker compose.yml"
wget -O "$CORE_DIR/docker compose.yml" "$COMPOSE_FILE_URL"

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

# 提示用户输入环境变量（如果未从配置文件加载）
if [ -z "$JWT_SECRET" ]; then
    echo "从配置中未检测到JWT_SECRET，需要手动输入..."
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
else
    echo "使用从配置文件加载的JWT_SECRET..."
fi

if [ -z "$ALLOWED_ORIGINS" ]; then
    echo "从配置中未检测到ALLOWED_ORIGINS，需要手动输入..."
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
else
    echo "使用从配置文件加载的ALLOWED_ORIGINS: $ALLOWED_ORIGINS"
fi

# 写入环境变量到 .env 文件
cat > "$ENV_FILE" <<EOL
JWT_SECRET=$JWT_SECRET
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOL

echo "环境变量设置完成！"

# 检查容器是否已运行
if docker compose -f "$CORE_DIR/docker-compose.yml" ps | grep -q 'Up'; then
    echo "Core 核心容器已在运行，跳过启动步骤。"
else
    # 启动容器
    echo "正在启动容器..."
    cd "$CORE_DIR"
    docker compose up -d

    # 检查容器状态
    if [ $? -eq 0 ]; then
        echo "Core 核心容器已成功启动！"
    else
        echo "Core 核心容器启动失败，请检查日志。"
        exit 1
    fi
fi

# 询问用户是否安装前端部分
if [ -z "$FRONTEND_INSTALL" ]; then
    echo "是否需要安装前端主题？(y/n，默认: y):"
    read -r INSTALL_FRONTEND
    INSTALL_FRONTEND=${INSTALL_FRONTEND:-y}
else
    echo "使用从配置文件加载的FRONTEND_INSTALL: $FRONTEND_INSTALL"
    # 将布尔值转换为 y/n 格式
    if [[ "$FRONTEND_INSTALL" == "true" || "$FRONTEND_INSTALL" == "True" || "$FRONTEND_INSTALL" == "TRUE" ]]; then
        INSTALL_FRONTEND="y"
    elif [[ "$FRONTEND_INSTALL" == "false" || "$FRONTEND_INSTALL" == "False" || "$FRONTEND_INSTALL" == "FALSE" ]]; then
        INSTALL_FRONTEND="n"
    else
        INSTALL_FRONTEND=$FRONTEND_INSTALL
    fi
fi

if [[ "$INSTALL_FRONTEND" == "y" || "$INSTALL_FRONTEND" == "Y" ]]; then
    if [ -z "$FRONTEND_VERSION" ]; then
        echo "请选择要安装的前端版本:"
        echo "1) Shiro（开源版本)"
        echo "2) Shiroi（闭源版本）"
        read -p "请输入选项 (1/2，默认: 1): " FRONTEND_OPTION
        FRONTEND_OPTION=${FRONTEND_OPTION:-1}
        FRONTEND_VERSION=$(if [ "$FRONTEND_OPTION" -eq 1 ]; then echo "Shiro"; else echo "Shiroi"; fi)
    else
        echo "使用从配置文件加载的FRONTEND_VERSION: $FRONTEND_VERSION"
    fi

    FRONTEND_DIR="$TARGET_DIR/frontend"
    if [ -d "$FRONTEND_DIR" ]; then
        echo "检测到前端目录已存在: $FRONTEND_DIR"
        # 如果配置文件已加载，则直接删除并重新创建目录
        if [ -f "$CONFIG_FILE" ]; then
            echo "检测到配置文件已加载，直接删除并重新创建前端目录..."
            rm -rf "$FRONTEND_DIR"
            mkdir -p "$FRONTEND_DIR"
        else
            echo "是否删除并重新创建？(y/n，默认: n):"
            read -r DELETE_FRONTEND_DIR
            DELETE_FRONTEND_DIR=${DELETE_FRONTEND_DIR:-n}
            if [[ "$DELETE_FRONTEND_DIR" == "y" || "$DELETE_FRONTEND_DIR" == "Y" ]]; then
                echo "正在删除目录: $FRONTEND_DIR"
                rm -rf "$FRONTEND_DIR"
                mkdir -p "$FRONTEND_DIR"
            else
                echo "保留现有目录，继续使用: $FRONTEND_DIR"
            fi
        fi
    else
        echo "前端目录不存在，正在创建: $FRONTEND_DIR"
        mkdir -p "$FRONTEND_DIR"
    fi

    case "$FRONTEND_VERSION" in
        Shiro)
            # 安装Shiro
            if [[ "$IS_CN_NETWORK" == true ]]; then
                GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
            else
                GITHUB_MIRROR="https://raw.githubusercontent.com"
            fi
            COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/shiro/docker compose.yml"
            echo "正在下载 Shiro 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $FRONTEND_DIR/docker compose.yml"
            wget -O "$FRONTEND_DIR/docker compose.yml" "$COMPOSE_FILE_URL"
            if [ $? -ne 0 ]; then
                echo "下载 Shiro 需求的 Docker Compose 文件失败！请检查环境网络连接。"
                exit 1
            fi

            # 设置 Shiro 环境变量
            ENV_FILE="$FRONTEND_DIR/.env"

            # 提示用户输入环境变量
            echo "请输入以下所需要环境变量的值："

            if [ -z "$FRONTEND_NEXT_PUBLIC_API_URL" ]; then
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
            else
                echo "使用从配置文件加载的NEXT_PUBLIC_API_URL: $FRONTEND_NEXT_PUBLIC_API_URL"
                NEXT_PUBLIC_API_URL=$FRONTEND_NEXT_PUBLIC_API_URL
            fi

            if [ -z "$FRONTEND_NEXT_PUBLIC_GATEWAY_URL" ]; then
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
            else
                echo "使用从配置文件加载的NEXT_PUBLIC_GATEWAY_URL: $FRONTEND_NEXT_PUBLIC_GATEWAY_URL"
                NEXT_PUBLIC_GATEWAY_URL=$FRONTEND_NEXT_PUBLIC_GATEWAY_URL
            fi

            cat > "$ENV_FILE" <<EOL
NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
NEXT_PUBLIC_GATEWAY_URL=$NEXT_PUBLIC_GATEWAY_URL
SHIRO_IMAGE=innei/shiro:latest
ENABLE_EXPERIMENTAL_COREPACK=1
EOL

            # 启动Shiro容器
            echo "正在启动 Shiro 容器..."
            cd "$FRONTEND_DIR"
            docker compose up -d

            if [ $? -eq 0 ]; then
                echo "Shiro 前端容器已成功启动！"
            else
                echo "Shiro 前端容器启动失败，请检查日志。"
                exit 1
            fi
            ;;
        Shiroi)
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
            if [ -z "$FRONTEND_SHIRO_IMAGE" ]; then
                while true; do
                    read -p "请输入 SHIRO_IMAGE（私有镜像） 的值（例如：your-dockerhub-username/shiroi:tag）: " SHIRO_IMAGE
                    if [[ "$SHIRO_IMAGE" =~ ^[a-z0-9]+([._-]?[a-z0-9]+)*\/[a-z0-9]+([._-]?[a-z0-9]+)*(:[a-zA-Z0-9._-]+)?$ ]]; then
                        break
                    else
                        echo "输入无效，请输入正确的 Docker 镜像格式（例如：your-dockerhub-username/shiroi:tag）。"
                    fi
                done
            else
                echo "使用从配置文件加载的SHIRO_IMAGE: $FRONTEND_SHIRO_IMAGE"
                SHIRO_IMAGE=$FRONTEND_SHIRO_IMAGE
            fi

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
             up -d

            if [ $? -eq 0 ]; then
                echo "Shiroi 前端容器已成功启动！"
            else
                echo "Shiroi 前端容器启动失败，请检查日志。"
                exit 1
            fi
            ;;

    esac
    # 提示用户安装成功并输出当前时间（基于UTC+8）
    echo "前端安装成功！"
    echo "MixSpace 已经安装在你的服务器上，你可以参考官方文档自行配置反向代理。"
    echo "当前时间（UTC+8）：$(date -u -d '+8 hours' '+%Y-%m-%d %H:%M:%S')"
fi
