# GitHub Runner Docker 服務

本專案使用 Docker 容器化技術，建立一個自託管 (self-hosted) 的 GitHub Actions Runner 環境，用於自動化執行 CI/CD 工作流程以及 RiceCall 的各項服務。

## ✨ 功能特性

- **環境隔離**：透過 Docker 容器，確保執行環境的純淨與一致性。
- **自動化設定**：初次啟動時，自動從指定的 GitHub Repository 拉取程式碼並安裝相依套件。
- **簡易設定**：僅需透過 `.env` 檔案即可完成所有環境設定。
- **日誌紀錄**：所有服務與腳本的執行紀錄都會被儲存於 `logs/` 目錄下，方便追蹤與除錯。

## 🚀 快速開始

請依照以下步驟進行服務的初始化與設定。

### 1. 首次環境初始化

1.  **設定 Docker Compose**
    - 開啟 [`docker-compose.yml`](docker-compose.yml:1) 檔案。
    - 確認 `container_name` 與 `ports` 符合您的需求。

2.  **準備環境變數檔案**
    - 將專案所需的環境變數填寫至 [`.env.project.init`](.env.project.init:1) 檔案中。此檔案內的變數將會在初始化時被複製到專案目錄中。
    - 複製 [`.env.example`](.env.example:1) 為 [`.env`](.env:1)。

3.  **設定 Runner 參數 (`.env`)**
    - 在 [`.env`](.env:1) 檔案中，將 `MODE` 設定為 `init`。
    - `NODE_VERSION`: 指定專案所需的 Node.js 版本 (例如: `18`)。
    - `GIT_REPO_URL`: 您專案的 GitHub Repository URL。
    - `GIT_BRANCH`: 指定服務要運行的分支。
    - `RUNNER_TOKEN`: 前往您專案的 GitHub > `Settings` > `Actions` > `Runners` 頁面，點擊 `New self-hosted runner`，並將產生的 `token` 貼到此處。
    - `NODE_INIT_COMMAND`: 服務初始化時所需的指令 (例如: `npm install` 或 `yarn install`)。
    - `NODE_START_COMMAND`: 啟動服務的指令 (例如: `npm start` 或 `node index.js`)。

4.  **啟動服務**
    - 執行以下指令來建置並啟動容器：
      ```bash
      docker-compose up
      ```

5.  **註冊 Runner**
    - 服務啟動後，請等待 `service/` 目錄下出現 [`otc.txt`](service/otc.txt:1) 檔案。
    - 開啟該檔案，瀏覽其中的 URL 並輸入對應的 Token，以完成 Runner 的註冊。

6.  **切換至生產模式**
    - 當初始化與註冊完成，且服務正常運作後，請停止容器 (按下 `Ctrl + C`)。
    - 將 [`.env`](.env:1) 檔案中的 `MODE` 修改為 `production`。
    - 重新啟動服務即可：`docker-compose up -d`。

### 2. 重新初始化服務

如果您需要清空並重新設定整個服務：

1.  刪除 `service/` 目錄下的 **所有** 檔案與資料夾。
2.  重複執行 [首次環境初始化](#1-首次環境初始化) 的所有步驟。

### 3. 管理專案的環境變數

初始化完成後，如果需要修改專案的環境變數：

-   請直接編輯 `service/project/.env` 檔案。
