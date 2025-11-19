#!/bin/bash
# 讓腳本在任何指令失敗時立即退出
set -e

# --- 日誌設定 ---
# 假設執行此腳本的使用者對 /var/log/ 有寫入權限
LOG_DIR="/var/log"
# 建立包含日期與時間的時間戳
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/entrypoint-${TIMESTAMP}.log"

# 建立日誌目錄和檔案 (如果不存在)
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# 將所有後續的標準輸出 (stdout) 和標準錯誤 (stderr)
# 都重導向到控制台，並同時附加到日誌檔案
# 這讓你可以同時使用 `docker logs` 查看並在容器內保留日誌
exec &> >(tee -a "$LOG_FILE")

# --- 環境變數與模式選擇 ---
echo "============================================================"
echo "啟動 Entrypoint 腳本..."
echo "當前使用者: $(whoami)"
echo "執行模式 (MODE): ${MODE:=production}" # 如果 MODE 未設定，預設為 production
echo "============================================================"

# 檢查必要的環境變數
if [ "$MODE" = "init" ]; then
    if [ -z "$GIT_REPO_URL" ] || [ -z "$GIT_BRANCH" ] || [ -z "$NODE_INIT_COMMAND" ]; then
        echo "錯誤: 在 'init' 模式下，GIT_REPO_URL, GIT_BRANCH, 和 NODE_INIT_COMMAND 環境變數為必需。"
        exit 1
    fi
elif [ "$MODE" = "production" ]; then
    if [ -z "$STARTUP_COMMAND" ]; then
        echo "錯誤: 在 'production' 模式下，STARTUP_COMMAND 環境變數為必需。"
        exit 1
    fi
fi


# 根據 MODE 變數執行不同的任務
case "$MODE" in
    init)
        echo "--- 執行 Init 模式 ---"

        echo "===== 步驟 1/9: 安裝 nvm (Node Version Manager) ====="
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash


        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ~/.bashrc

        echo "===== 步驟 2/9: 重新載入環境，讓 nvm 指令可用 ====="
        export NVM_DIR="$HOME/.nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            source "$NVM_DIR/nvm.sh"  # 載入 nvm function
        else
            echo "錯誤: 找不到 nvm.sh，安裝可能失敗了。"
            exit 1
        fi

        # 檢查是否有提供 NODE_VERSION，如果有的話就使用
        if [ -n "$NODE_VERSION" ]; then
          echo "===== 步驟 3/9: 正在安裝並使用 Node.js 版本: $NODE_VERSION ====="
          nvm install "$NODE_VERSION"
          nvm use "$NODE_VERSION"
          echo "===== 步驟 4/9: 設定 nvm 的預設 Node.js 版本為 $NODE_VERSION ====="
          nvm alias default "$NODE_VERSION"
        else
          echo "===== 步驟 3/9 & 4/9: 未指定 NODE_VERSION，跳過 Node.js 安裝與設定 ====="
        fi


        echo "步驟 5/9: 執行 gh_init.js (GitHub 認證)..."
        node /usr/lib/gh_init.js
        echo "gh_init.js 執行完畢。"

        # 設定 gh cli 使用 git 協議
        gh auth setup-git

        echo "步驟 6/9: 從 $GIT_REPO_URL Clone 專案..."
        git clone "$GIT_REPO_URL" project
        echo "Clone 完成。"

        # 進入專案目錄
        cd project

        echo "步驟 7/9: 切換到分支 $GIT_BRANCH..."
        git checkout "$GIT_BRANCH"
        echo "分支切換完畢。"

        echo "步驟 8/9: 載入初始.env"
        if [ -f "/usr/share/project/.env.project.init" ]; then
            cp /usr/share/project/.env.project.init .env
            echo "已從 /usr/share/project/.env.project.init 載入初始 .env 檔案。"
        else
            echo "警告: 找不到 /usr/share/project/.env.project.init，跳過載入初始 .env 檔案。"
        fi

        echo "步驟 9/9: 執行 Node 初始化指令..."
        echo "執行的指令: $NODE_INIT_COMMAND"
        bash -c "$NODE_INIT_COMMAND"
        echo "Node 初始化指令執行完畢。"

        # --- 設定 GitHub Actions Runner ---
        if [ -n "$RUNNER_TOKEN" ] && [ -n "$GIT_REPO_URL" ]; then
            echo "步驟 10/10: 偵測到 RUNNER_TOKEN，開始設定 GitHub Actions Runner..."

            RUNNER_DIR="/home/ubuntu/actions-runner"
            mkdir -p "$RUNNER_DIR"
            cd "$RUNNER_DIR"

            # 下載並解壓縮 runner
            LATEST_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')
            RUNNER_FILENAME="actions-runner-linux-x64-${LATEST_VERSION}.tar.gz"
            echo "正在下載 Runner v${LATEST_VERSION}..."
            curl -o "${RUNNER_FILENAME}" -L "https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/${RUNNER_FILENAME}"
            tar xzf "./${RUNNER_FILENAME}"

            # 設定 Runner
            echo "正在設定 Runner..."
            ./config.sh --url "$GIT_REPO_URL" --token "$RUNNER_TOKEN" --name "docker-runner-$(hostname)" --labels "docker,linux,x64" --unattended --replace

            echo "GitHub Actions Runner 設定完成！"
        else
            echo "步驟 10/10: 未提供 RUNNER_TOKEN，跳過 GitHub Actions Runner 設定。"
        fi

        echo "--- Init 模式全部完成！ ---"
        ;;

    init-skip)
        echo "===== 步驟 2/9: 重新載入環境，讓 nvm 指令可用 ====="
        export NVM_DIR="$HOME/.nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            source "$NVM_DIR/nvm.sh"  # 載入 nvm function
        else
            echo "錯誤: 找不到 nvm.sh，安裝可能失敗了。"
            exit 1
        fi

        # 檢查是否有提供 NODE_VERSION，如果有的話就使用
        if [ -n "$NODE_VERSION" ]; then
          echo "===== 步驟 3/9: 正在安裝並使用 Node.js 版本: $NODE_VERSION ====="
          nvm install "$NODE_VERSION"
          nvm use "$NODE_VERSION"
          echo "===== 步驟 4/9: 設定 nvm 的預設 Node.js 版本為 $NODE_VERSION ====="
          nvm alias default "$NODE_VERSION"
        else
          echo "===== 步驟 3/9 & 4/9: 未指定 NODE_VERSION，跳過 Node.js 安裝與設定 ====="
        fi

        # 進入專案目錄
        cd project

        echo "步驟 7/9: 切換到分支 $GIT_BRANCH..."
        git checkout "$GIT_BRANCH"
        echo "分支切換完畢。"

        echo "步驟 8/9: 載入初始.env"
        if [ -f "/usr/share/project/.env.project.init" ]; then
            cp /usr/share/project/.env.project.init .env
            echo "已從 /usr/share/project/.env.project.init 載入初始 .env 檔案。"
        else
            echo "警告: 找不到 /usr/share/project/.env.project.init，跳過載入初始 .env 檔案。"
        fi

        echo "步驟 9/9: 執行 Node 初始化指令..."
        echo "執行的指令: $NODE_INIT_COMMAND"
        bash -c "$NODE_INIT_COMMAND"
        echo "Node 初始化指令執行完畢。"

        # --- 設定 GitHub Actions Runner ---
        if [ -n "$RUNNER_TOKEN" ] && [ -n "$GIT_REPO_URL" ]; then
            echo "步驟 10/10: 偵測到 RUNNER_TOKEN，開始設定 GitHub Actions Runner..."

            RUNNER_DIR="/home/ubuntu/actions-runner"
            mkdir -p "$RUNNER_DIR"
            cd "$RUNNER_DIR"

            # 下載並解壓縮 runner
            LATEST_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')
            RUNNER_FILENAME="actions-runner-linux-x64-${LATEST_VERSION}.tar.gz"
            echo "正在下載 Runner v${LATEST_VERSION}..."
            curl -o "${RUNNER_FILENAME}" -L "https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/${RUNNER_FILENAME}"
            tar xzf "./${RUNNER_FILENAME}"

            # 設定 Runner
            echo "正在設定 Runner..."
            ./config.sh --url "$GIT_REPO_URL" --token "$RUNNER_TOKEN" --name "docker-runner-$(hostname)" --labels "docker,linux,x64" --unattended --replace

            echo "GitHub Actions Runner 設定完成！"
        else
            echo "步驟 10/10: 未提供 RUNNER_TOKEN，跳過 GitHub Actions Runner 設定。"
        fi

        echo "--- Init 模式全部完成！ ---"
        ;;

    production)
        echo "--- 執行 Production 模式 (使用 Supervisor) ---"
        echo "當前使用者: $(whoami)"

        PROJECT_DIR="/home/ubuntu/project"
        RUNNER_DIR="/home/ubuntu/actions-runner"
        LOGS_DIR="/var/log"
        SUPERVISOR_CONF="/home/ubuntu/supervisord.conf"
        # 建立包含日期與時間的時間戳，用於 supervisor 的日誌檔案
        TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

        rm -rf "/home/ubuntu/project/$ENV_FILENAME"
        cp /usr/share/.env "/home/ubuntu/project/$ENV_FILENAME"

        rm -rf "$SUPERVISOR_CONF"
        rm -rf /home/ubuntu/supervisor.sock
        rm -rf /home/ubuntu/supervisord.pid
        rm -rf /home/ubuntu/supervisor.log
        rm -rf /home/ubuntu/.bash_history

        if [ ! -d "$PROJECT_DIR" ]; then
            echo "錯誤: 專案目錄 $PROJECT_DIR 不存在。請先執行 'init' 模式。"
            exit 1
        fi

        # --- 動態產生 Supervisor 設定檔 ---
        echo "正在產生 Supervisor 設定檔: $SUPERVISOR_CONF"

        cat > "$SUPERVISOR_CONF" <<-EOF
[supervisord]
nodaemon=true
user=$(whoami)

[unix_http_server]
file=/home/ubuntu/supervisor.sock
chmod=0700

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///home/ubuntu/supervisor.sock

[program:main-app]
directory=$PROJECT_DIR
command=/usr/bin/app-start.sh
autostart=true
autorestart=true
# stopasgroup=true: 確保 supervisor 停止時，會將信號發送到整個程序組 (包括子程序)
stopasgroup=true
# killasgroup=true: 確保 supervisor 強制終止時，也會終止整個程序組
killasgroup=true
stdout_logfile=$LOGS_DIR/app-$TIMESTAMP.log
stderr_logfile=$LOGS_DIR/app-err-$TIMESTAMP.log
user=$(whoami)

EOF

        if [ -f "$RUNNER_DIR/run.sh" ]; then
            echo "發現已設定的 Runner，將其加入 Supervisor 設定。"
            cat >> "$SUPERVISOR_CONF" <<-EOF

[program:github-runner]
command=bash -c "cd $RUNNER_DIR && ./run.sh"
autostart=true
autorestart=true
stdout_logfile=$LOGS_DIR/runner-$TIMESTAMP.log
stderr_logfile=$LOGS_DIR/runner-err-$TIMESTAMP.log
user=$(whoami)
EOF
        else
            echo "未發現已設定的 Runner，跳過 Supervisor 設定。"
        fi

        echo "--- Supervisor 設定完成 ---"
        cat "$SUPERVISOR_CONF"
        echo "-----------------------------"

        exec /usr/bin/supervisord -c "$SUPERVISOR_CONF"
        ;;

    *)
        echo "錯誤: 未知的 MODE '$MODE'。請使用 'init' 或 'production' 或 'init-skip'。"
        exit 1
        ;;
esac
