cd ~

cat << 'EOF' > kankyou.sh
#!/bin/bash

echo "--- Terraria Server Environment Setup Script ---"
date

# 1. システム更新と必須ツールのインストール
echo "[1/6] 必須ツールの確認..."
PACKAGES="curl wget unzip screen mono-complete"
NEEDS_UPDATE=0

for pkg in $PACKAGES; do
    if ! dpkg -l | grep -q " $pkg "; then
        echo "  -> $pkg をインストールします..."
        NEEDS_UPDATE=1
    else
        echo "  -> $pkg はインストール済みです (Skip)"
    fi
done

if [ $NEEDS_UPDATE -eq 1 ]; then
    sudo apt update
    sudo apt install -y $PACKAGES
fi


# 2. .NET 6.0 (SDK) のインストール
echo "[2/6] .NET 6.0 の確認..."
if command -v dotnet >/dev/null 2>&1; then
    echo "  -> .NET はインストール済みです (Skip)"
else
    echo "  -> .NET 6.0 をインストールします..."
    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
    chmod +x dotnet-install.sh
    ./dotnet-install.sh --channel 6.0
    rm dotnet-install.sh
fi

# パス設定 (.bashrc) の確認
echo "[3/6] 環境変数(PATH)の確認..."
if grep -q "DOTNET_ROOT" ~/.bashrc; then
    echo "  -> .bashrc にパス設定済みです (Skip)"
else
    echo "  -> .bashrc にパスを追記します..."
    echo '' >> ~/.bashrc
    echo '# .NET Setup' >> ~/.bashrc
    echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
    echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' >> ~/.bashrc
    
    # 現在のシェルにも適用
    export DOTNET_ROOT=$HOME/.dotnet
    export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools
fi


# 3. サーバーディレクトリの作成
echo "[4/6] ディレクトリの確認..."
if [ -d "$HOME/teraria" ]; then
    echo "  -> ~/teraria は存在します (Skip)"
else
    echo "  -> ~/teraria を作成します..."
    mkdir -p "$HOME/teraria"
fi


# 4. Systemd (自動起動) の設定 【選択式】
echo ""
echo "[5/6] 自動起動設定(Systemd)のセットアップ"
echo "  説明: ラズパイの電源を入れた時、自動的にテラリアサーバーを起動するようにします。"
echo "  ※ これを設定しないと、毎回手動で起動する必要があります。"
echo -n "  -> 自動起動を有効にしますか？ (y/n): "
read -r ANSWER_SYSTEMD

if [[ "$ANSWER_SYSTEMD" =~ ^[Yy]$ ]]; then
    SERVICE_FILE="/etc/systemd/system/terraria.service"
    if [ -f "$SERVICE_FILE" ]; then
        echo "  -> 既に設定ファイルが存在するためスキップします。"
    else
        echo "  -> 設定ファイルを作成しています..."
        sudo bash -c "cat << EOL > $SERVICE_FILE
[Unit]
Description=Terraria Official Server Auto Launcher
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
ExecStart=/bin/bash $HOME/terakidou.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL"
        echo "  -> サービスを有効化しました。"
        sudo systemctl daemon-reload
        sudo systemctl enable terraria.service
    fi
else
    echo "  -> スキップしました。"
fi


# 5. Cron (朝5時の強制再起動) の設定 【選択式】
echo ""
echo "[6/6] 定期再起動(Cron)のセットアップ"
echo "  説明: 毎朝5時にサーバーを強制停止します。"
echo "  自動起動(Step 5)と組み合わせることで、「停止→自動再起動→アップデート確認」の流れを作ります。"
echo "  ※ これを設定しないと、手動で再起動するまで最新版への更新が行われません。"
echo -n "  -> 毎朝5時の再起動タスクを追加しますか？ (y/n): "
read -r ANSWER_CRON

if [[ "$ANSWER_CRON" =~ ^[Yy]$ ]]; then
    CRON_CMD="0 5 * * * pkill -f TerrariaServer.exe"
    EXISTING_CRON=$(crontab -l 2>/dev/null)

    if echo "$EXISTING_CRON" | grep -Fq "pkill -f TerrariaServer.exe"; then
        echo "  -> 既に設定済みのためスキップします。"
    else
        echo "  -> Cronにタスクを追加しました。"
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    fi
else
    echo "  -> スキップしました。"
fi

echo ""
echo "--- Setup Completed! ---"
echo "設定を反映するため、一度再起動するか 'source ~/.bashrc' を実行してください。"
EOF

chmod +x kankyou.sh