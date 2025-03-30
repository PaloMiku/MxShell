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
    USER_IP=$(curl -s --max-time 2 https://ipinfo.io/ip)
    if [[ -n "$USER_IP" ]]; then
        USER_REGION=$(curl -s --max-time 2 https://ipapi.co/$USER_IP/country_name)
        if echo "$USER_REGION" | grep -q "China"; then
            export IS_CN_NETWORK=true
        else
            export IS_CN_NETWORK=false
        fi
    else
        echo "无法检测用户IP，默认设置为非中国大陆网络环境。"
        export IS_CN_NETWORK=false
    fi
}

function Configure_Docker() {
    if command -v docker &> /dev/null; then
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

    echo -e "${GREEN}=============================="
    echo -e "MixSpace 后端一键安装脚本"
    echo -e "版本：v2.0.0"
    echo -e "==============================${NC}"

    # 输出当前系统版本
    echo -e "${GREEN}当前系统版本:${NC}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "  $PRETTY_NAME"
    else
        echo -e "  无法检测系统版本"
    fi

    # 输出用户地区
    echo -e "${GREEN}当前用户地区:${NC}"
    if [[ -n "$USER_REGION" ]]; then
        echo -e "  $USER_REGION"
    else
        echo -e "  未检测到用户地区"
    fi

    # 输出当前系统架构
    echo -e "${GREEN}当前系统架构:${NC}"
    Detect_Architecture
    if [[ -z "$architecture" ]]; then
        echo -e "  错误: 未能检测到系统架构，请检查系统环境。"
        exit 1
    fi
    echo -e "  $architecture"

    # 输出已安装的 Docker 版本
    echo -e "${GREEN}系统 Docker 版本:${NC}"
    if command -v docker &> /dev/null; then
        echo -e "  $(docker --version)"
    else
        echo -e "  Docker 未安装"
    fi

    echo -e "${GREEN}==============================${NC}"
}

function Load_Env_File() {
    ENV_FILE="$(dirname "$0")/mxshell.env"
    if [[ -f "$ENV_FILE" ]]; then
        echo "当前为无人值守（自动化）模式，加载环境变量文件: $ENV_FILE"
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    else
        echo "检测到环境变量文件 $ENV_FILE 不存在，切换到交互模式。"
        export AUTO_INSTALL=false
    fi
}

function Select_Target_Directory() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        # 自动化模式下从环境变量加载 TARGET_DIR
        if [ -z "$TARGET_DIR" ] || [[ "$TARGET_DIR" != /* ]] || ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
            echo "当前为无人值守（自动化）模式，但未设置 TARGET_DIR 环境变量或目录无效。"
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

    # 检查目标目录是否为关键系统目录
    if [[ "$TARGET_DIR" == "/" || "$TARGET_DIR" == "/root" || "$TARGET_DIR" == "/home" ]]; then
        echo "错误: 目标目录为关键系统目录 ($TARGET_DIR)，无法使用。"
        exit 1
    fi

    # 检查目标目录是否存在
    if [ -d "$TARGET_DIR" ]; then
        echo "目标目录已存在: $TARGET_DIR"
        if [[ "$AUTO_INSTALL" == "true" ]]; then
            echo "当前为无人值守（自动化）模式，直接删除并重新创建目录..."
            rm -rf "$TARGET_DIR"
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
            fi
        fi
    else
        echo "目标目录不存在，正在创建: $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    fi

    # 检查目录创建是否成功
    if [ ! -d "$TARGET_DIR" ]; then
        echo "错误: 无法创建目录 $TARGET_DIR，请检查权限。"
        exit 1
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
    if [ -f "$ENV_FILE" ];then
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
        while true; do
            read -p "ALLOWED_ORIGINS：需要填写被允许访问的域名（不包含 http:// 或 https://），通常是前端的域名，如果允许多个域名访问，用英文逗号分隔域名: " ALLOWED_ORIGINS
            ALLOWED_ORIGINS=$(echo "$ALLOWED_ORIGINS" | sed 's/^ *//;s/ *$//')
            IFS=',' read -ra DOMAINS <<< "$ALLOWED_ORIGINS"
            valid=true
            for domain in "${DOMAINS[@]}"; do
                domain=$(echo "$domain" | sed 's/^ *//;s/ *$//')
                if [[ "$domain" =~ ^https?:// ]]; then
                    valid=false
                    echo "输入无效，请不要包含 http 协议头，请重新输入。"
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
        echo "使用从配置文件加载的 ALLOWED_ORIGINS: $ALLOWED_ORIGINS"
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

function main() {
    # 检查是否为 Root 用户
    Check_Root

    # 检测系统架构
    Detect_Architecture

    # 检测网络环境
    Check_China_Network

    # 显示版本信息
    Display_Version

    # 配置 Docker
    Configure_Docker

    # 加载环境变量文件
    Load_Env_File

    # 选择目标目录
    Select_Target_Directory

    # 下载并配置核心组件
    Download_And_Configure_Core
}

# 调用主函数
main "$@"