#!/bin/bash

function Detect_Architecture() {
    osCheck=$(uname -a)
    if [[ $osCheck =~ 'x86_64' ]]; then
        architecture="amd64"
    elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]]; then
        architecture="arm64"
    else
        echo "当前系统架构不受支持。请参考官方文档以选择受支持的系统。"
        exit 1
    fi
}

function Check_Root() {
    if [[ $EUID -ne 0 ]]; then
        echo "请在 Root 环境下运行此脚本"
        exit 1
    fi
}

function Check_China_Network() {
    echo "正在检测网络环境..."
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
}

function Configure_Docker() {
    echo "网络环境检查完成。"
    if [[ "$IS_CN_NETWORK" == "true" ]]; then
        echo "当前为中国大陆网络环境，使用国内源配置 Docker..."
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh) \
          --source mirrors.aliyun.com/docker-ce \
          --source-registry dockerproxy.net \
          --protocol http \
          --use-intranet-source false \
          --install-latest true \
          --close-firewall true
    else
        echo "当前为非中国大陆网络环境，使用非官方源配置 Docker..."
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh) \
          --source download.docker.com \
          --source-registry registry.hub.docker.com \
          --protocol http \
          --use-intranet-source false \
          --install-latest true \
          --close-firewall true
    fi
    
}

echo "<-. (\`-')    _       (\`-')      (\`-').->  _  (\`-')  (\`-')  _              (\`-')  _"
echo "   \(OO )_  (_)      (OO )_.->  ( OO)_    \-.(OO )  (OO ).-/   _          ( OO).-/"
echo ",--./  ,-.) ,-(\`-')  (_| \_)--.(_)--\_)   _.'    \  / ,---.    \-,-----. (,------."
echo "|   \`.'   | | ( OO)  \  \`.'  / /    _ /  (_...--''  | \ /\`.\    |  .--./  |  .---'"
echo "|  |'.'|  | |  |  )   \    .') \_..\`--.  |  |_.' |  '-'|_.' |  /_) (\`-') (|  '--."
echo "|  |   |  |(|  |_/    .'    \  .-._)   \ |  .___.' (|  .-.  |  ||  |OO )  |  .--'"
echo "|  |   |  | |  |'->  /  .'.  \ \       / |  |       |  | |  | (_'  '--'\  |  \`---."
echo "\`--'   \`--' \`--'    \`--'   '--' \`-----'  \`--'       \`--' \`--'    \`-----'  \`------'"



function Display_Version() {
    GREEN='\033[0;32m'
    NC='\033[0m'
    echo -e "${GREEN} MixSpace 后端一键安装脚本 版本：v2.0.0${NC}"
    
    # 输出当前系统版本
    echo -e "${NC}当前系统版本:${NC}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "${NC}$PRETTY_NAME${NC}"
    else
        echo -e "${NC}无法检测系统版本${NC}"
    fi

    # 输出当前系统架构
    Detect_Architecture
    echo -e "${NC}当前系统架构: $architecture${NC}"

    # 输出已安装的 Docker 版本
    echo -e "${NC}已安装的 Docker 版本:${NC}"
    if command -v docker &> /dev/null; then
        docker --version
    else
        echo -e "${NC}Docker 未安装${NC}"
    fi
}

function Auto_Install_Check() {
    # 检查是否传入 --auto_install 参数
    if [[ " $* " == *" --auto_install "* ]]; then
        export AUTO_INSTALL=true
    else
        export AUTO_INSTALL=false
    fi
}

function Load_Env_File() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        ENV_FILE="$(dirname "$0")/mxshell.env"
        if [[ -f "$ENV_FILE" ]]; then
            echo "当前为无人值守（自动化）模式，加载环境变量文件: $ENV_FILE"
            export $(grep -v '^#' "$ENV_FILE" | xargs)
        else
            echo "检测到环境变量文件 $ENV_FILE 不存在，无法加载。"
            exit 1
        fi
    else
        echo "当前为交互式安装模式，忽略加载环境变量文件。"
    fi
}

function Select_Target_Directory() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        # 自动化模式下从环境变量加载 TARGET_DIR
        if [ -z "$TARGET_DIR" ]; then
            echo "当前为无人值守（自动化）模式，但未设置 TARGET_DIR 环境变量。"
            exit 1
        else
            echo "（自动化）使用从环境变量加载的 TARGET_DIR: $TARGET_DIR"
        fi
    else
        # 交互式模式下提示用户输入目录
        echo "请输入存储 MixSpace 容器文件的目录（默认: /opt/mxspace）："
        read -r TARGET_DIR
        TARGET_DIR=${TARGET_DIR:-/opt/mxspace}
    fi

    # 检查目标目录是否存在
    if [ -d "$TARGET_DIR" ]; then
        echo "目标目录已存在: $TARGET_DIR"
        if [[ "$AUTO_INSTALL" == "true" ]]; then
            # 自动化模式下直接删除并重新创建目录
            echo "当前为无人值守（自动化）模式，直接删除并重新创建目录..."
            rm -rf "$TARGET_DIR"
            mkdir -p "$TARGET_DIR"
        else
            # 交互式模式下询问用户是否删除
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
}

function Download_And_Configure_Core() {
    CORE_DIR="$TARGET_DIR/core"
    mkdir -p "$CORE_DIR"
    if [[ "$IS_CN_NETWORK" == true ]]; then
        GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
    else
        GITHUB_MIRROR="https://raw.githubusercontent.com"
    fi
    COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/core/docker-compose.yml"
    echo "正在下载 Core 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $CORE_DIR/docker-compose.yml"
    wget -O "$CORE_DIR/docker-compose.yml" "$COMPOSE_FILE_URL"

    if [ $? -ne 0 ]; then
        echo "下载Core 需求的 Docker Compose 文件失败！请检查环境网络连接。"
        exit 1
    fi

    ENV_FILE="$CORE_DIR/.env"
    if [ -f "$ENV_FILE" ]; then
        echo "已检测到容器环境变量文件: $ENV_FILE"
    else
        echo "未检测到容器环境变量文件，正在创建: $ENV_FILE"
        touch "$ENV_FILE"
    fi

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
            ALLOWED_ORIGINS=$(echo "$ALLOWED_ORIGINS" | sed 's/^ *//;s/ *$//')
            IFS=',' read -ra DOMAINS <<< "$ALLOWED_ORIGINS"
            valid=true
            for domain in "${DOMAINS[@]}"; do
                domain=$(echo "$domain" | sed 's/^ *//;s/ *$//')
                if [[ "$domain" =~ ^https?:// ]]; then
                    valid=false
                    echo "输入无效，请不要包含http协议头，请重新输入。"
                    break
                fi
                if [[ -z "$domain" || ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
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

}