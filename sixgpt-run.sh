#!/bin/bash

# 设置容器名称
CONTAINER_NAME="miner-sixgpt3-1"
CONTAINER_ID=$(docker inspect --format='{{.Id}}' "$CONTAINER_NAME")
LOG_FILE="/var/lib/docker/containers/$CONTAINER_ID/$CONTAINER_ID-json.log"
CHECK_STRINGS=(
    "ERROR---- TEE PROOF"
    "May take more than 1 hr based on current TEE workloads"
    "Uploaded https://drive.google.com/uc?id="
)
# 进入无限循环，实时监控容器状态
while true; do
    # 检查容器是否存在
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "$(date): 容器 ${CONTAINER_NAME} 不存在或未运行，正在启动..."
        
        # 尝试启动容器
        cd
        cd miner
        docker compose up -d
        
        # 检查启动是否成功
        if [ $? -eq 0 ]; then
            echo "$(date): 容器 ${CONTAINER_NAME} 已成功启动。"
        else
            echo "$(date): 启动容器 ${CONTAINER_NAME} 失败，请检查日志。"
        fi
    else
        echo "$(date): 容器 ${CONTAINER_NAME} 正在运行。"
    fi
    # 检查日志内容是否包含指定的字符串
    for CHECK_STRING in "${CHECK_STRINGS[@]}"; do
        if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "$CHECK_STRING"; then
            echo "发现日志包含 '$CHECK_STRING'，清除日志并重启容器..."

            # 清除旧日志（通过清空 stdout 和 stderr）
            > "$LOG_FILE"

            # 停止容器
            docker stop "$CONTAINER_NAME"
            
            # 删除容器
            docker rm "$CONTAINER_NAME"

            # 重新启动容器
            docker compose up -d "$CONTAINER_NAME"
            
            echo "日志已清理，容器将重新运行"
            break
        fi
    done
    

    # 每隔 30 秒检查一次容器状态
    sleep 30
done
