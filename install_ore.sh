#!/bin/bash

# 定义你的输入参数
URL="http://ghproxy.net/https://github.com/caotan1/ore/raw/main/ore-miner"
TARGET_DIR="/home/$(whoami)/ore"
LOCAL_ARCHIVE="ore-miner"
REQUIRED_TOOLS=("curl" "wget")
START_FILE="start_ore"
WATCH_FILE="watch_ore"
SERVICE_FILE="ore.service"


# 检查所需工具是否安装，如果没有安装，则进行安装
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool is not installed. Installing..."
        sudo apt update && sudo apt install -y "$tool"
        if [ $? -ne 0 ]; then
            echo "Failed to install $tool."
            exit 1
        fi
    fi
done

# 检查文件是否存在
if [ -f "$LOCAL_ARCHIVE" ]; then
    # 文件存在，询问用户是否覆盖下载
    read -p "File $LOCAL_ARCHIVE already exists. Do you want to download and overwrite it? [y/N]: " OVERRIDE
    OVERRIDE=${OVERRIDE:-n}  # 默认值为 n (no)

    if [[ "$OVERRIDE" == "y" || "$OVERRIDE" == "Y" ]]; then
        echo "Overwriting $LOCAL_ARCHIVE..."
        if curl -L -o "$LOCAL_ARCHIVE" "$URL"; then
            echo "Download completed."
        else
            # 如果curl失败，尝试使用wget下载文件
            echo "Failed to download using curl, trying wget..."
            if wget -O "$LOCAL_ARCHIVE" "$URL"; then
                echo "Download completed."
            else
                echo "Failed to download the archive using wget."
            fi
        fi
    else
        echo "Skipping download."
    fi
else
    # 文件不存在，直接下载
    echo "Downloading $LOCAL_ARCHIVE..."
    if curl -L -o "$LOCAL_ARCHIVE" "$URL"; then
        echo "Download completed."
    else
        # 如果curl失败，尝试使用wget下载文件
        echo "Failed to download using curl, trying wget..."
        if wget -O "$LOCAL_ARCHIVE" "$URL"; then
            echo "Download completed."
        else
            echo "Failed to download the archive using wget."
        fi
    fi
fi

# 继续执行后续命令
echo "Continuing with subsequent commands..."


# 创建目标目录（如果不存在）
mkdir -p "$TARGET_DIR"

#复制文件到对应目录
mv ore-miner $TARGET_DIR

#赋予权限
chmod +x $TARGET_DIR/ore-miner

#创建start_ore文件
touch $TARGET_DIR/$START_FILE
echo 'nohup ./ore-miner  mine --address BPKstudKLncb2oWyWWFsD1httKbHmifS8kNyHeL1Jqfp --threads 0 --invcode 2QKLTH >>ore.log 2>&1 &' > $TARGET_DIR/$START_FILE 
chmod +x "$TARGET_DIR/$START_FILE"

# 检查脚本文件是否创建成功
if [ -f "$TARGET_DIR/$START_FILE" ]; then
    echo "Script file $START_FILE created successfully."
else
    echo "Failed to create script file $START_FILE"
    exit 1
fi


#创建watch_ore文件
touch $TARGET_DIR/$WATCH_FILE

echo '#!/bin/bash
while true; do  
    # 检查aleo是否正在运行  
    if ! pgrep -x "ore-miner" > /dev/null; then  
        echo "ore is not running, starting it..."
        # 调用之前创建的脚本来启动脚本  
        cd /home/$(whoami)/ore
        taskset -c CPU_LIST ./start_ore
    else
        echo "$(date): ore running..."
    fi  
    # 等待一段时间再次检查（例如，每5秒）  
    sleep 5  
done' > $TARGET_DIR/$WATCH_FILE

chmod +x $TARGET_DIR/$WATCH_FILE


# 检查脚本文件是否创建成功
if [ -f "$TARGET_DIR/$WATCH_FILE" ]; then
    echo "Script file $WATCH_FILE created successfully."
else
    echo "Failed to create script file $WATCH_FILE."
    exit 1
fi

#创建ore.service文件
touch $TARGET_DIR/$SERVICE_FILE

echo '[Unit]  
Description=Monitor and Restart ore if not running  
  
[Service]  
Type=simple  
ExecStart=/home/$(whoami)/ore/watch_ore
Restart=on-failure  
RestartSec=10s 
  
[Install]  
WantedBy=multi-user.target
' > $TARGET_DIR/$SERVICE_FILE

chmod +x $TARGET_DIR/$SERVICE_FILE

#取消开机启动
touch $TARGET_DIR/disable_ore
echo 'sudo systemctl disable ore.service' > $TARGET_DIR/disable_ore
chmod +x $TARGET_DIR/disable_ore
# 检查脚本文件是否创建成功
if [ -f "$TARGET_DIR/disable_ore" ]; then
    echo "Script file disable_ore created successfully."
else
    echo "Failed to create script file disable_ore."
    exit 1
fi


#删除ore.service服务文件
touch $TARGET_DIR/uninstall_ore.sh
echo '
sudo pkill -9 ore-miner
sudo systemctl disable ore.service
sudo rm -r /etc/systemd/system/ore.service
sudo systemctl daemon-reload
sudo rm -r /home/$(whoami)/ore
' > $TARGET_DIR/uninstall_ore.sh
chmod +x $TARGET_DIR/uninstall_ore.sh

# 检查脚本文件是否创建成功
if [ -f "$TARGET_DIR/uninstall_ore.sh" ]; then
    echo "Script file uninstall_ore.sh created successfully."
else
    echo "Failed to create script file uninstall_ore.sh."
    exit 1
fi

# 检查脚本文件是否创建成功
if [ -f "$TARGET_DIR/$SERVICE_FILE" ]; then
    echo "Script file $SERVICE_FILE created successfully."
else
    echo "Script file $SERVICE_FILE created Failed."
    exit 1
fi

sudo mv $TARGET_DIR/$SERVICE_FILE /etc/systemd/system/

# 获取逻辑 CPU 的数量
LOGICAL_CPUS=$(nproc)

# 计算实际的核心号并减2
ACTUAL_CORE_COUNT=$((LOGICAL_CPUS - 2))

# 确保不会小于0
if [ $ACTUAL_CORE_COUNT -lt 0 ]; then
    ACTUAL_CORE_COUNT=0
fi

# 构建 CPU 核心列表
CPU_LIST=""
for (( i=0; i<$ACTUAL_CORE_COUNT; i++ )); do
    CPU_LIST+="$i,"
done

# 移除最后一个逗号
CPU_LIST=${CPU_LIST%,}

# 输出结果
echo "CPU List: $CPU_LIST"

TEMPLATE_FILE="$TARGET_DIR/$WATCH_FILE"
# 读取模板文件内容
TEMPLATE_CONTENT=$(<"$TEMPLATE_FILE")

# 替换模板中的 CPU_NUM 变量
MODIFIED_CONTENT=$(echo "$TEMPLATE_CONTENT" | sed "s/CPU_LIST/$CPU_LIST/g")

# 创建新的脚本文件并写入修改后的内容
echo -e "$MODIFIED_CONTENT" > $TARGET_DIR/$WATCH_FILE

chmod +x "$TARGET_DIR/$WATCH_FILE"

#关闭原有进程
sudo pkill -9 ore-miner
sudo systemctl daemon-reload
sudo systemctl enable ore.service
sudo systemctl restart ore.service

# 清理临时文件和目录
#rm -rf "$LOCAL_ARCHIVE"

exit 0
