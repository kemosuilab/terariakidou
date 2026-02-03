cd ~

cat << 'EOF' > terakidou.sh
#!/bin/bash

# --- 設定エリア ---
BASE_DIR="/home/gorugojj/teraria"
WORLD_PATH="$HOME/.local/share/Terraria/Worlds/自分で作ったワールドの名前.wld"
PORT=7777
# ------------------

echo "--- Terraria Auto Launcher (Clean Install Mode) ---"
date

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# 1. Wikiから最新情報を取得
WIKI_URL="https://terraria.wiki.gg/wiki/Server"
LATEST_INFO=""
MAX_RETRIES=3
COUNT=0

while [ $COUNT -lt $MAX_RETRIES ]; do
    LATEST_INFO=$(curl -sL --max-time 10 "$WIKI_URL" | \
      grep -oE '<a[^>]+href="([^"]+\.zip)"[^>]*>Terraria Server ([0-9\.]+)<' | \
      sed -E 's/.*href="([^"]+)".*>Terraria Server ([0-9\.]+)<.*/\2 \1/' | \
      sort -V | tail -n 1)
    if [ -n "$LATEST_INFO" ]; then break; fi
    COUNT=$((COUNT+1))
    sleep 1
done

# 2. アップデート判定とクリーン処理
EXE_PATH=$(find . -name "TerrariaServer.exe" | grep "Linux" | head -n 1)

if [ -n "$LATEST_INFO" ]; then
    LATEST_VER=$(echo "$LATEST_INFO" | cut -d ' ' -f 1)
    LATEST_URL=$(echo "$LATEST_INFO" | cut -d ' ' -f 2)
    VERSION_FILE="installed_version.txt"
    
    NEED_INSTALL=0
    if [ -z "$EXE_PATH" ]; then
        NEED_INSTALL=1
    elif [ ! -f "$VERSION_FILE" ] || [ "$(cat $VERSION_FILE)" != "$LATEST_VER" ]; then
        echo "新バージョン ($LATEST_VER) を検出しました。"
        NEED_INSTALL=1
    fi

    if [ $NEED_INSTALL -eq 1 ]; then
        echo "フォルダを空にして再構築を開始します..."
        pkill -f TerrariaServer.exe
        sleep 2
        
        # --- ここで中身を一旦削除 (自分自身以外のファイルを全削除) ---
        # フォルダ内の全ファイルを消すが、設定ファイル等は念のため残さない（完全クリーン）
        find . -mindepth 1 -delete
        
        echo "ダウンロード中..."
        wget -O server.zip "$LATEST_URL"
        if [ $? -eq 0 ]; then
            unzip -o -q server.zip
            rm server.zip
            echo "$LATEST_VER" > "$VERSION_FILE"
        else
            echo "ダウンロード失敗。"
        fi
    fi
fi

# 3. 起動前のDLLクリーニング (ARMエラー対策)
EXE_PATH=$(find . -name "TerrariaServer.exe" | grep "Linux" | head -n 1)
if [ -n "$EXE_PATH" ]; then
    SERVER_ROOT=$(dirname "$EXE_PATH")
    pushd "$SERVER_ROOT" > /dev/null
    # ラズパイ環境で衝突するDLLを確実に排除
    rm -f System.*.dll Mono.*.dll mscorlib.dll WindowsBase.dll Microsoft.*.dll System.dll
    popd > /dev/null
fi

# 4. サーバー起動
if [ -z "$EXE_PATH" ]; then
    echo "エラー: 起動ファイルが見つかりません。"
    exit 1
fi

if pgrep -f "TerrariaServer.exe" > /dev/null; then
    echo "サーバーは既に稼働中です。"
else
    echo "起動中: junikki (v$(cat installed_version.txt 2>/dev/null))"
    mono --server --gc=sgen -O=all "$EXE_PATH" -server -world "$WORLD_PATH" -port "$PORT" -autocreate 2
fi
EOF

chmod +x terakidou.sh