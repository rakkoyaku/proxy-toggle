# ProxyToggle

macOS のシステムプロキシ（HTTP / HTTPS）を、メニューバーから **1クリックで切り替え**られる常駐アプリ。
現在の ON / OFF が常にメニューバー上に見えます。

> A tiny macOS menu bar app that toggles the system HTTP/HTTPS proxy with a single click,
> and always shows the current state.

```
● PROXY   ← 有効（緑）
○ PROXY   ← 無効（グレー）
◐ PROXY   ← HTTP と HTTPS が不一致（オレンジ）
◌ PROXY   ← 切り替え中
```

- **左クリック** … 即トグル
- **右クリック** … 現在のネットワークサービス名 / ホスト:ポート、ON・OFF、ネットワーク設定を開く、ログイン時に起動、終了
- 接続中のデフォルト経路からネットワークサービス名を自動判定するので、Wi-Fi 以外（Ethernet 等）や名前を変更した Wi-Fi でもそのまま動きます
- システム設定や CLI からプロキシを変更した場合も、`SCDynamicStore` の通知で即座に表示が追従します

---

## 必要なもの

- macOS 12 以降
- Xcode Command Line Tools（`xcode-select --install`）

## ビルドとインストール

```sh
git clone https://github.com/rakkoyaku/proxy-toggle-mac.git
cd proxy-toggle-mac
./build.sh                 # ~/Applications/ProxyToggle.app を生成
open ~/Applications/ProxyToggle.app
```

インストール先を変えたい場合は `./build.sh /Applications` のように引数で指定します。

初回起動時に **一度だけ管理者認証**（パスワード / Touch ID）を求められます。以降は認証なしで切り替わります。

プロキシのホスト / ポート自体は、システム設定 → ネットワーク → 詳細 → プロキシ で一度設定しておいてください。
OFF にしてもホスト / ポートは保持されるので、このアプリは有効・無効の切り替えだけを行います。

## アンインストール

```sh
./uninstall.sh
```

## 仕組みと、権限まわりの設計

macOS ではシステムのプロキシ設定の変更に root 権限が必要です。これは OS 側の制約で、
どんな作りのアプリでも避けられません（市販のプロキシツールも初回に特権ヘルパーを入れています）。

本アプリは初回起動時に、次の 2 つを設置します。

| パス | 内容 |
| --- | --- |
| `/usr/local/bin/proxyctl` | root 所有 (`root:wheel`, `755`) のシェルヘルパー。実体は [`scripts/proxyctl`](scripts/proxyctl) |
| `/etc/sudoers.d/proxyctl` | `<user> ALL=(root) NOPASSWD: /usr/local/bin/proxyctl` の 1 行のみ |

- パスワード不要で実行できるのは **この 1 本のスクリプトだけ** です。`networksetup` 全体を無制限に許可するより攻撃面が小さくなります。
- ヘルパーが root 所有かつ他ユーザーから書き込み不可であることが安全性の前提です。編集する場合は必ず `sudo` 経由で行ってください。
- 状態の読み取りには権限は不要なので、通常時は一切 `sudo` を経由しません。

`scripts/proxyctl` はヘルパーの唯一の正本で、`build.sh` がビルド時にこれをそのままバイナリへ埋め込みます
（生成物の `Sources/HelperSource.swift` は gitignore 済み）。

### より "正式" なやり方について

Apple 公式の作法は `SMAppService`（macOS 13+）で root の launchd デーモンをアプリバンドルに同梱し、
XPC 経由で `SCPreferences` を書く方式です。ただし Developer ID 署名が必須で、
ヘルパーの `Info.plist` / `launchd.plist` / `SMAuthorizedClients` の突き合わせが必要になります。
個人利用であれば上記の sudoers 方式で実用上は等価なため、こちらを採用しています。

なお `build.sh` はアドホック署名（`codesign -s -`）を行うため、そのままでは配布用途には向きません。

---

## alternatives/

同じ `scripts/proxyctl` を使う、既存のメニューバーツール向けの実装も置いてあります。
アプリをビルドせずに使いたい場合はこちら（先に `scripts/proxyctl` を手動で設置してください）。

```sh
sudo install -o root -g wheel -m 755 scripts/proxyctl /usr/local/bin/proxyctl
echo "$(id -un) ALL=(root) NOPASSWD: /usr/local/bin/proxyctl" | sudo tee /etc/sudoers.d/proxyctl >/dev/null
sudo chmod 440 /etc/sudoers.d/proxyctl
sudo visudo -cf /etc/sudoers.d/proxyctl
```

| ファイル | 用途 |
| --- | --- |
| [`alternatives/swiftbar/proxy.5s.sh`](alternatives/swiftbar/proxy.5s.sh) | [SwiftBar](https://github.com/swiftbar/SwiftBar) / xbar プラグイン。プラグインフォルダに置いて `chmod +x` |
| [`alternatives/hammerspoon/proxy-toggle.lua`](alternatives/hammerspoon/proxy-toggle.lua) | [Hammerspoon](https://www.hammerspoon.org/) 用。`~/.hammerspoon/init.lua` に貼る |

## License

MIT
