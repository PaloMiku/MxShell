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
    if command -v docker &> /dev/null; then
        echo "Docker 已安装，跳过 Docker 配置步骤。"
        return
    fi

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
    echo -e "${GREEN}MixSpace 后端一键安装脚本 版本：v2.0.0${NC}"
    
    # 输出当前系统版本
    echo -e "当前系统版本:${NC}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "${GREEN}$PRETTY_NAME${NC}"
    else
        echo -e "${GREEN}无法检测系统版本${NC}"
    fi

    # 输出当前系统架构
    Detect_Architecture
    if [[ -z "$architecture" ]]; then
        echo "错误: 未能检测到系统架构，请检查系统环境。"
        exit 1
    fi
    echo -e "${GREEN}当前系统架构: $architecture${NC}"

    # 输出已安装的 Docker 版本
    echo -e "${GREEN}已安装的 Docker 版本:${NC}"
    if command -v docker &> /dev/null; then
        docker --version
    else
        echo -e "${GREEN}Docker 未安装${NC}"
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
    ENV_FILE="$(dirname "$0")/mxshell.env"
    if [[ -f "$ENV_FILE" ]]; then
        echo "当前为无人值守（自动化）模式，加载环境变量文件: $ENV_FILE"
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    else
        echo "检测到环境变量文件 $ENV_FILE 不存在，无法加载。"
        exit 1
    fi
}

function Select_Target_Directory() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        # 自动化模式下从环境变量加载 TARGET_DIR
        if [ -z "$TARGET_DIR" ] || [[ "$TARGET_DIR" != /* ]] || ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
            echo "当前为无人值守（自动化）模式，但未设置 TARGET_DIR 环境变量。"
            exit 1
        else
            echo "（自动化）使用从环境变量加载的 TARGET_DIR: $TARGET_DIR"
        fi
    else
        # 交互式模式下提示用户输入目录
        echo "请输入存储 MixSpace 容器文件的目录（按 Enter 使用默认值: /opt/mxspace）："
        read -r TARGET_DIR
        TARGET_DIR=${TARGET_DIR:-/opt/mxspace}
    fi

    # 检查目标目录是否存在
    TARGET_DIR_EXISTS=false
    if [ -d "$TARGET_DIR" ]; then
        TARGET_DIR_EXISTS=true
        echo "目标目录已存在: $TARGET_DIR"
    fi
            # 警告: 在自动化模式下，脚本会自动删除并重新创建目标目录。
            # 请确保 TARGET_DIR 未设置为关键系统目录，例如 "/", "/root" 或 "/home"。
            if [[ "$TARGET_DIR" == "/" || "$TARGET_DIR" == "/root" || "$TARGET_DIR" == "/home" ]]; then
    if [[ "$TARGET_DIR_EXISTS" == true ]]; then
        if [[ "$AUTO_INSTALL" == "true" ]]; then
            echo "当前为无人值守（自动化）模式，直接删除并重新创建目录..."
            if [[ "$TARGET_DIR" == "/" || "$TARGET_DIR" == "/root" || "$TARGET_DIR" == "/home" ]]; then
                echo "错误: 目标目录为关键系统目录 ($TARGET_DIR)，无法删除。"
                exit 1
            fi
            echo "是否删除并重新创建？(y/N，按 Enter 默认保留):"
            mkdir -p "$TARGET_DIR"
        else
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
                if ! mkdir -p "$TARGET_DIR"; then
                    echo "错误: 无法创建目录 $TARGET_DIR，请检查权限。"
                    exit 1
                fi
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
    if [[ "$IS_CN_NETWORK" == "true" ]]; then
        GITHUB_MIRROR="https://github.moeyy.xyz/https://raw.githubusercontent.com"
    else
        GITHUB_MIRROR="https://raw.githubusercontent.com"
    fi
    COMPOSE_FILE_URL="$GITHUB_MIRROR/PaloMiku/MxShell/refs/heads/main/core/docker-compose.yml"
    echo "正在下载 Core 所需要的 Docker Compose 文件: 从 $COMPOSE_FILE_URL 下载到 $CORE_DIR/docker-compose.yml"
    MAX_RETRIES=3
    RETRY_DELAY=5
    for ((i=1; i<=MAX_RETRIES; i++)); do
        wget -O "$CORE_DIR/docker-compose.yml" "$COMPOSE_FILE_URL" && break
        echo "下载失败，重试 ($i/$MAX_RETRIES) 次后继续..."
        sleep $RETRY_DELAY
    done

    if [ ! -f "$CORE_DIR/docker-compose.yml" ]; then
        echo "下载Core 需求的 Docker Compose 文件失败！请检查环境网络连接。"
        exit 1
    fi

    if [ $? -ne 0 ]; then
        echo "下载Core 需求的 Docker Compose 文件失败！请检查环境网络连接。"
        exit 1
    fi

    ENV_FILE="$CORE_DIR/.env"
    if [ -f "$ENV_FILE" ]; then
                JWT_SECRET=$(openssl rand -base64 16 | tr -d '\n' | cut -c1-32)
    else
        echo "未检测到容器环境变量文件，正在创建: $ENV_FILE"
        touch "$ENV_FILE"
    fi

    if [ -z "$JWT_SECRET" ]; then
        echo "未检测到 JWT_SECRET，请输入一个 16 至 32 字符的密钥（留空将随机生成）:"
        while true; do
            read -p "JWT_SECRET: " JWT_SECRET
            if [[ -z "$JWT_SECRET" ]]; then
                JWT_SECRET=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
                echo "已随机生成 JWT_SECRET: $JWT_SECRET"
            fi
            if [[ ${#JWT_SECRET} -ge 16 && ${#JWT_SECRET} -le 32 ]]; then
                break
            else
                echo "无效输入，请输入 16 至 32 字符的密钥。"
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
            read -p "ALLOWED_ORIGINS：需要填写被允许访问的域名（不包含 http:// 或 https://），通常是前端的域名，如果允许多个域名访问，用英文逗号分隔域名: " ALLOWED_ORIGINS
                domain=$(echo "$domain" | sed 's/^ *//;s/ *$//')
                if [[ "$domain" =~ ^https?:// ]]; then
                    valid=false
                    echo "输入无效，请不要包含http协议头，请重新输入。"
                    break
                fi
                if [[ -z "$domain" || ! "$domain" =~ ^([a-zA-Z0-9\u00A1-\uFFFF]([a-zA-Z0-9\u00A1-\uFFFF-]{0,61}[a-zA-Z0-9\u00A1-\uFFFF])?\.)+[a-zA-Z\u00A1-\uFFFF]{2,}$ ]]; then
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

echo "JWT_SECRET=$JWT_SECRET" > "$ENV_FILE"
echo "ALLOWED_ORIGINS=$ALLOWED_ORIGINS" >> "$ENV_FILE"

echo "环境变量设置完成！"

# 检查容器是否已运行
if docker inspect -f '{{.State.Running}}' $(docker compose -f "$CORE_DIR/docker-compose.yml" ps -q) 2>/dev/null | grep -q 'true'; then
    echo "Core 核心容器已在运行，跳过启动步骤。"
else
    # 启动容器
    echo "正在启动容器..."
    cd "$CORE_DIR" || { echo "无法切换到目录 $CORE_DIR，请检查目录是否存在。"; exit 1; }
    if docker compose up -d; then
        echo "Core 核心容器已成功启动！"
    else
        echo "Core 核心容器启动失败，请检查日志。"
        echo "尝试使用以下命令查看日志: docker compose logs"
        exit 1
    fi
fi

}