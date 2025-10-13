#!/usr/bin/node

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// --- 設定 ---
const outputFilePath = '/home/ubuntu/otc.txt';
// --- 結束設定 ---

// 增加一個標記來確保檔案只被寫入一次
let isCodeSaved = false;

console.log('Starting gh auth login process...');
console.log('--------------------------------------------------');

if (fs.existsSync("/home/ubuntu/.config/gh/config.yml")) {
    process.exit();
}

const ghProcess = spawn('gh', [
    'auth',
    'login',
    '--git-protocol', 'https',
    '--hostname', 'GitHub.com',
    '--web'
]);

// 監聽 gh 指令的標準輸出 (stdout)
ghProcess.stdout.on('data', (data) => {
    const chunk = data.toString();
    
    // 將即時輸出顯示在螢幕上，讓您知道進度
    process.stdout.write(chunk);

    // 檢查輸出中是否包含第一個問題
    if (chunk.includes('Authenticate Git with your GitHub credentials?')) {
        // 使用 setTimeout 稍微延遲一下輸入，模擬更真實的互動
        setTimeout(() => {
            console.log('\n[SCRIPT] Detected credentials prompt. Sending "Y"...');
            ghProcess.stdin.write('Y\n'); // 輸入 Y 並按下 Enter
        }, 100);
    }

    // 檢查輸出中是否包含第二個問題
    if (chunk.includes('Press Enter to open github.com in your browser...')) {
        setTimeout(() => {
            console.log('\n[SCRIPT] Detected browser prompt. Pressing Enter...');
            ghProcess.stdin.write('\n'); // 直接按下 Enter
        }, 100);
    }
});

// 監聽錯誤輸出
ghProcess.stderr.on('data', (data) => {
    const chunk = data.toString();
    console.error(`[STDERR] ${data.toString()}`);

    // --- 即時擷取驗證碼 ---
    // 檢查這一塊數據中是否包含驗證碼，並且我們還沒有儲存過它
    if (!isCodeSaved) {
        const regex = /one-time code:\s*([A-Z0-9]{4}-[A-Z0-9]{4})/;
        const match = chunk.match(regex);

        if (match && match[1]) {
            const oneTimeCode = match[1];
            console.log(`\n\n[SCRIPT] ✅ One-time code found: ${oneTimeCode}`);

            try {
                // 確保目標目錄存在
                const dir = path.dirname(outputFilePath);
                if (!fs.existsSync(dir)) {
                    fs.mkdirSync(dir, { recursive: true });
                }
                // 將驗證碼寫入檔案
                fs.writeFileSync(outputFilePath, "https://github.com/login/device\n" + oneTimeCode);
                console.log(`[SCRIPT] ✅ Code successfully saved to ${outputFilePath}\n`);
                isCodeSaved = true; // 標記為已儲存，防止重複寫入
            } catch (error) {
                console.error(`\n[SCRIPT] ❌ Error writing to file ${outputFilePath}:`, error);
            }
        }
    }
    // --- 結束即時擷取 ---
});

// 當 gh 程序結束時觸發
ghProcess.on('close', (code) => {
    console.log(`\n--------------------------------------------------`);
    console.log(`gh process exited with code ${code}.`);
    if (!isCodeSaved) {
        console.log('❌ Warning: Process finished, but no one-time code was detected or saved.');
    }
});

// 處理在腳本執行時可能發生的錯誤
process.on('uncaughtException', (err) => {
  console.error('An uncaught error occurred!', err);
});