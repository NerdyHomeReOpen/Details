# 使用官方 Ubuntu 24.04 作為基礎映像
FROM ubuntu:24.04

# 設定環境變數，避免安裝過程中的互動式提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新套件列表並安裝所有必要工具
# - git, gh: 版本控制與 GitHub CLI
# - curl, tar, jq: 下載和處理檔案的工具
# - nodejs, npm: Node.js 執行環境
# - sudo: 允許使用者提權 (如果需要)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    gh \
    ca-certificates \
    nodejs \
    npm \
    sudo \
    tar \
    supervisor \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 使用 npm 安Stan yarn
RUN npm install -g yarn

# 允許 'ubuntu' 使用者無密碼執行 sudo
# 這在初始化或需要更高權限的腳本中很有用
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 建立日誌目錄，並將擁有者設為 ubuntu 使用者
# 這樣 ubuntu 使用者才能寫入日誌檔案
RUN mkdir -p /var/log/app && chown ubuntu:ubuntu /var/log/app

# 複製應用程式檔案到容器中
COPY entrypoint.sh /usr/bin
COPY gh_init.js /usr/lib
COPY app-start.sh /usr/bin

# 賦予 entrypoint.sh 執行權限
RUN chmod +x /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/app-start.sh

# 複製初始 .env 檔案到指定位置
RUN mkdir -p /usr/share/project

RUN usermod -d /home/ubuntu -m -s /bin/bash ubuntu

# 設定 'ubuntu' 使用者
USER ubuntu

# 設定工作目錄為 ubuntu 的家目錄
WORKDIR /home/ubuntu

# 設定容器的進入點
ENTRYPOINT ["/usr/bin/entrypoint.sh"]

# 設定預設執行的命令，如果 docker-compose 沒有提供 command，則會執行這個
CMD ["production"]
