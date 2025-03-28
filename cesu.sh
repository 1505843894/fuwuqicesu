#!/bin/bash

# 设置 pushplus token
PUSH_PLUS_TOKEN="66481a4cd4e14b66bca5d38b7012d254"

# 检查并安装必要的依赖
check_and_install_deps() {
    local missing_deps=()
    
    # 检查 bc 命令
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi
    
    # 检查 curl 命令
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    # 检查 speedtest-cli
    if ! command -v speedtest-cli &> /dev/null; then
        echo "正在安装 speedtest-cli..."
        if command -v apt &> /dev/null; then
            apt update
            apt install -y python3-pip
            pip3 install speedtest-cli
        elif command -v yum &> /dev/null; then
            yum install -y python3-pip
            pip3 install speedtest-cli
        fi
    fi
    
    # 如果有缺失的依赖，尝试安装
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "正在安装必要的依赖: ${missing_deps[*]}"
        if command -v apt &> /dev/null; then
            apt update
            apt install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y "${missing_deps[@]}"
        else
            echo "无法自动安装依赖，请手动安装: ${missing_deps[*]}"
            exit 1
        fi
    fi
}

# 执行依赖检查和安装
check_and_install_deps

# 获取当前时间
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# 运行 speedtest 并获取结果
echo "开始测速..."

# 使用 speedtest-cli 测速
SPEEDTEST_RESULT=$(speedtest-cli --simple 2>/dev/null)
if [ $? -eq 0 ]; then
    DOWNLOAD_SPEED=$(echo "$SPEEDTEST_RESULT" | grep "Download" | awk '{print $2}')
    UPLOAD_SPEED=$(echo "$SPEEDTEST_RESULT" | grep "Upload" | awk '{print $2}')
    PING=$(echo "$SPEEDTEST_RESULT" | grep "Ping" | awk '{print $2}')
else
    echo "Speedtest 失败，使用备用方法..."
    # 使用 ping 测试延迟
    PING_RESULT=$(ping -c 3 8.8.8.8 2>/dev/null)
    if [ $? -eq 0 ]; then
        PING=$(echo "$PING_RESULT" | tail -1 | awk -F '/' '{print $5}')
    else
        PING="N/A"
    fi

    # 使用 curl 测试下载速度
    TEST_FILE="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
    SPEED_TEST=$(curl -s -w "%{speed_download}" -o /dev/null "$TEST_FILE")
    DOWNLOAD_SPEED=$(echo "scale=2; $SPEED_TEST / 131072" | bc)
    UPLOAD_SPEED="N/A"
fi

# 获取服务器信息
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ip.sb || echo "无法获取IP")
HOSTNAME=$(hostname)

# 构建消息内容
TITLE="$SERVER_IP"
CONTENT="测试时间: $CURRENT_TIME
服务器: $HOSTNAME ($SERVER_IP)
Ping: $PING ms
下载速度: $DOWNLOAD_SPEED Mbit/s
上传速度: $UPLOAD_SPEED Mbit/s"

# 使用 pushplus 发送通知
echo "发送测速结果到 pushplus..."
curl -s "http://www.pushplus.plus/send" \
    -d "token=$PUSH_PLUS_TOKEN" \
    -d "title=$TITLE" \
    -d "content=$CONTENT" \
    -d "template=txt"

echo "测速完成并已推送结果" 
