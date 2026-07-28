# ProxyToggle (Windows)

タスクトレイからシステムプロキシを **1クリックで切り替え**られる常駐アプリ。
現在の ON / OFF がトレイアイコンの色で常に見えます。

```
● 緑の塗りつぶし … プロキシ有効
○ グレーの輪郭   … プロキシ無効
```

- **左クリック** … 即トグル
- **右クリック** … 状態 / サーバー表示、ON・OFF、プロキシ設定を開く、ログイン時に起動、終了
- **管理者権限は不要**（設定はすべて `HKEY_CURRENT_USER` 配下）
- 設定アプリや他ツールから変更された場合も 1.5 秒以内に表示が追従します

## 必要なもの

- Windows 10 / 11
- [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0)（`-SelfContained` でビルドすれば不要）
- ビルドする場合のみ .NET 8 SDK

## ビルドとインストール

```powershell
git clone https://github.com/rakkoyaku/proxy-toggle.git
cd proxy-toggle\windows
.\build.ps1 -Run
```

`%LOCALAPPDATA%\Programs\ProxyToggle\ProxyToggle.exe` に配置されます。

| オプション | 効果 |
| --- | --- |
| `-Dest <path>` | インストール先を変更 |
| `-SelfContained` | .NET ランタイムを同梱（サイズは大きくなるがランタイム不要） |
| `-Run` | ビルド後に起動 |

ログイン時の自動起動は、トレイアイコンの右クリックメニューから切り替えられます
（`HKCU\...\CurrentVersion\Run` に登録されます）。

> **Windows 11 の注意**: 新しいトレイアイコンは既定でオーバーフロー（`^` の中）に隠れます。
> 常時表示するには 設定 → 個人用設定 → タスクバー → 「タスク バー コーナーのオーバーフロー」で
> ProxyToggle をオンにするか、アイコンをタスクバーへドラッグしてください。

## CLI モード

同じ実行ファイルがスクリプトからも使えます。

```powershell
ProxyToggle.exe --status    # off<TAB>127.0.0.1:8080<TAB><local>
ProxyToggle.exe --on
ProxyToggle.exe --off
ProxyToggle.exe --toggle
```

GUI サブシステムの実行ファイルなので、PowerShell から `&` で呼ぶと **完了を待たずに次へ進みます**。
出力や終了コードが必要な場合は次のどちらかを使ってください。

```powershell
cmd /c "$exe --status"
Start-Process $exe -ArgumentList '--toggle' -Wait -NoNewWindow
```

## 仕組み

`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` の WinINET 設定
（＝設定アプリの「ネットワークとインターネット → プロキシ → 手動プロキシ セットアップ」）を操作します。

1. `ProxyEnable` (DWORD) を 0 / 1 に設定
2. `Connections` 配下のバイナリ値（`DefaultConnectionSettings`, `SavedLegacySettings` 等）の
   オフセット 8 にあるフラグ DWORD の bit 1（手動プロキシ）を反転し、オフセット 4 のリビジョンカウンタを +1
3. `InternetSetOption` で `INTERNET_OPTION_SETTINGS_CHANGED` / `INTERNET_OPTION_REFRESH` を通知

2 が必要なのは、`ProxyEnable` だけを書き換えても WinINET がバイナリ値の方を正としてしまい、
反映されない場合があるためです。3 により、起動済みのアプリも再起動なしで新しい設定を拾います。

## 適用範囲について

WinINET のプロキシ設定を使うもの（Edge / Chrome / IE / .NET の `WebRequest` / 多くの Windows アプリ）に効きます。
一方、次のものには **効きません**。macOS 版と違い、Windows のプロキシ設定は一枚岩ではないためです。

- `HTTP_PROXY` / `HTTPS_PROXY` 環境変数を見るもの（curl、git、Node.js、Python requests など）
- WinHTTP のシステム既定プロキシを見るサービス（`netsh winhttp show proxy` の方）
- 独自にプロキシ設定を持つアプリ（Firefox の既定設定など）

また Windows の `ProxyEnable` は HTTP / HTTPS 共通の 1 つのスイッチです
（macOS のように個別には切り替えられません）。プロトコルごとに別のプロキシを使いたい場合は、
`ProxyServer` に `http=host:port;https=host:port` の形式で設定してください。

## ソース構成

| ファイル | 役割 |
| --- | --- |
| `Program.cs` | エントリポイント、単一インスタンス制御、CLI モード |
| `TrayApp.cs` | トレイアイコンとコンテキストメニュー |
| `ProxySettings.cs` | レジストリの読み書きと WinINET への通知 |
| `TrayIcons.cs` | アイコンを実行時に GDI+ で描画（.ico を同梱しない） |
| `StartupEntry.cs` | ログイン時の自動起動 |
| `NativeMethods.cs` | P/Invoke 宣言 |
