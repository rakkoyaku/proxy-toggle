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

## インストール

[Releases](https://github.com/rakkoyaku/proxy-toggle/releases) から選んでください。

| 配布物 | 中身 | .NET ランタイム |
| --- | --- | --- |
| `ProxyToggle-x.y.z-win-x64.msi` | インストーラー。スタートメニューに登録され「アプリと機能」からアンインストールできる | 必要 |
| `ProxyToggle-x.y.z-win-x64-portable.zip` | exe 1 個。展開して実行するだけ | 必要 |
| `ProxyToggle-x.y.z-win-x64-selfcontained.zip` | ランタイム同梱版（約 65 MB） | 不要 |

MSI は **per-user インストーラー**なので UAC は出ません。`%LOCALAPPDATA%\Programs\ProxyToggle`
に入り、標準ユーザーのままインストール／アンインストールできます。サイレントインストールも可能です。

```powershell
msiexec /i ProxyToggle-1.0.1-win-x64.msi /qn
msiexec /x ProxyToggle-1.0.1-win-x64.msi /qn
```

`.NET ランタイム: 必要` の配布物には [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0) が要ります。

`SHA256SUMS.txt` で検証する場合:

```powershell
(Get-FileHash .\ProxyToggle-1.0.1-win-x64.msi -Algorithm SHA256).Hash.ToLower()
```

> 署名証明書を持っていないため、実行ファイルと MSI は**コード署名されていません**。
> ダウンロード時に SmartScreen の警告が出ます（「詳細情報」→「実行」で進めます）。
> 気になる場合はソースからビルドしてください。

## 必要なもの（ビルドする場合）

- Windows 10 / 11
- .NET 8 SDK
- MSI を作る場合のみ WiX 5: `dotnet tool install --global wix`

## ソースからビルド

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

### リリース用パッケージを作る

```powershell
.\pack.ps1
```

`dist\` に MSI・portable zip・selfcontained zip・`SHA256SUMS.txt` が出力されます。
バージョンは `ProxyToggle.csproj` の `<Version>` が使われます（`-Version` で上書き可）。
MSI の定義は [`installer/ProxyToggle.wxs`](installer/ProxyToggle.wxs) です。

### ログイン時の自動起動

トレイアイコンの右クリックメニュー →「ログイン時に起動」で切り替えられます
（`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` に登録。昇格は不要です）。

インストール時に有効化しておくこともできます。

```powershell
msiexec /i ProxyToggle-1.0.1-win-x64.msi STARTUP=1 /qn
```

- 自動起動の設定は**アプリ側の設定**として扱われるため、MSI のアップグレードでリセットされません
- アンインストール時には削除されるので、消えた exe を指す迷子のエントリは残りません
- アプリを別の場所に移動した場合、起動時に登録先パスを現在の場所へ貼り直します

> **Windows 11 の注意**: 新しいトレイアイコンは既定でオーバーフロー（`^` の中）に隠れます。
> 常時表示するには 設定 → 個人用設定 → タスクバー → 「タスク バー コーナーのオーバーフロー」で
> ProxyToggle をオンにするか、アイコンをタスクバーへドラッグしてください。

## CLI モード

同じ実行ファイルがスクリプトからも使えます。

```powershell
ProxyToggle.exe --status        # off<TAB>127.0.0.1:8080<TAB><local>
ProxyToggle.exe --on
ProxyToggle.exe --off
ProxyToggle.exe --toggle
ProxyToggle.exe --startup       # on / off
ProxyToggle.exe --startup on
ProxyToggle.exe --startup off
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
