#!/bin/bash
set -e

echo "=== AWS Bedrock Cost Monitor セットアップ ==="
echo ""

# .envファイルの確認
if [ ! -f .env ]; then
    echo "エラー: .envファイルが見つかりません"
    echo ".env.exampleをコピーして.envを作成し、Webhook URLを設定してください:"
    echo "  cp .env.example .env"
    echo "  vim .env"
    exit 1
fi

# .envから環境変数を読み込む
export $(grep -v '^#' .env | xargs)

# Webhook URLの確認
if [ -z "$SLACK_WEBHOOK_URL" ] || [ "$SLACK_WEBHOOK_URL" = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" ]; then
    echo "エラー: .envファイルにSlack Webhook URLが設定されていません"
    exit 1
fi

echo "✓ Slack Webhook URL: 設定済み"
echo ""

# terraform.tfvarsを更新
cd terraform

# terraform.tfvarsにWebhook URLを設定
if [ -f terraform.tfvars ]; then
    # 既存のファイルを更新
    sed -i.bak "s|slack_webhook_url = \".*\"|slack_webhook_url = \"$SLACK_WEBHOOK_URL\"|" terraform.tfvars
    rm -f terraform.tfvars.bak
    echo "✓ terraform.tfvars を更新しました"
else
    # 新規作成
    cp terraform.tfvars.example terraform.tfvars
    sed -i.bak "s|slack_webhook_url = \".*\"|slack_webhook_url = \"$SLACK_WEBHOOK_URL\"|" terraform.tfvars
    rm -f terraform.tfvars.bak
    echo "✓ terraform.tfvars を作成しました"
fi

echo ""
echo "=== Terraform初期化 ==="
terraform init

echo ""
echo "=== デプロイ準備完了 ==="
echo "次のコマンドでデプロイを実行してください:"
echo "  cd terraform"
echo "  terraform plan"
echo "  terraform apply"
