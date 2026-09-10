# docs/ 使用說明

> `media/` 資料夾裡已經放了兩支實機錄影（`IMG_8434.mov`、`IMG_8435.mov`），
> GitHub 網頁上點檔名可直接線上播放。`IMG_8431.MOV`（168MB）超過 GitHub 單檔
> 100MB 的硬性上限，沒有放進來——如果想放這支，請先剪短或壓縮到 100MB 以下。
> `IMG_8438.HEIC` 是 iPhone 照片格式，大部分瀏覽器（含 GitHub 網頁預覽）都無法
> 直接顯示，建議之後用 iPhone「共享」或 Windows「小畫家」另存成 `.jpg` 再換上。

這個資料夾用來放**視覺門面素材**——教授瀏覽 GitHub 時第一眼看到的東西，建議放：

- `gameplay.png`：從手機錄的 `IMG_8434.mov` / `IMG_8435.mov` 截一張畫面清楚的遊戲截圖
  （Windows：播放影片時按 `Win + Shift + S` 框選截圖即可）
- `demo.gif`：把影片剪成 5–8 秒的動圖，放在 README 最上方最吸睛。免安裝軟體的作法：
  上傳到 [ezgif.com/video-to-gif](https://ezgif.com/video-to-gif)，裁切到遊戲最精彩的片段，
  下載後存成 `docs/demo.gif`
- `board_photo.jpg`：（選填）DE10-Standard 板子接上 VGA 螢幕運行時的實體照片

檔案放好之後，回到根目錄的 `README.md`，把 Gameplay 段落裡註解掉的這行取消註解：

```md
![Gameplay Demo](docs/demo.gif)
```

即可自動顯示在專案首頁。
