# ProxyToggle

システムの HTTP / HTTPS プロキシを、**メニューバー / タスクトレイから 1クリックで切り替え**られる常駐アプリ。
現在の ON / OFF が常に見えます。macOS 版と Windows 版があります。

> Menu bar / system tray apps that toggle the system HTTP(S) proxy with a single click,
> and always show the current state. macOS and Windows.

| | [macOS](macos/) | [Windows](windows/) |
| --- | --- | --- |
| 実装 | Swift + AppKit (`NSStatusItem`) | C# + WinForms (`NotifyIcon`) |
| 表示 | `● PROXY` 緑 / `○ PROXY` グレー | 緑の塗りつぶし ● / グレーの輪郭 ○ |
| 左クリック | 即トグル | 即トグル |
| 右クリック | 詳細メニュー | 詳細メニュー |
| 管理者権限 | 初回のみ必要（後述） | **不要** |
| 対象 | 接続中のネットワークサービス（Wi-Fi / Ethernet を自動判定） | WinINET のユーザー設定 |
| ビルド | Xcode Command Line Tools | .NET 8 SDK |

どちらも、外部（システム設定 / CLI）からプロキシが変更された場合も表示が自動で追従します。

## macOS

```sh
git clone https://github.com/rakkoyaku/proxy-toggle.git
cd proxy-toggle/macos
./build.sh
open ~/Applications/ProxyToggle.app
```

macOS はプロキシ設定の変更に root 権限が必要なため、初回起動時に一度だけ管理者認証を求めます。
そこで root 所有のヘルパー 1 本と、それだけを許可する sudoers ルールが入り、以降は認証不要になります。
詳細と代替手段（SwiftBar / Hammerspoon）は [macos/README.md](macos/README.md) を参照してください。

## Windows

[Releases](https://github.com/rakkoyaku/proxy-toggle/releases) から MSI / ZIP をダウンロードしてください。
MSI は per-user インストーラーなので **UAC は出ません**。

ソースからビルドする場合:

```powershell
git clone https://github.com/rakkoyaku/proxy-toggle.git
cd proxy-toggle\windows
.\build.ps1 -Run
```

Windows のプロキシ設定は `HKEY_CURRENT_USER` 配下なので、昇格は一切不要です。
適用範囲の注意（環境変数 `HTTP_PROXY` や WinHTTP には効かないこと）は
[windows/README.md](windows/README.md) を参照してください。

## License

MIT
