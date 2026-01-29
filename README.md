# AWS Bedrock コスト監視システム

AWS Bedrock（Claude関連）のコストを監視し、月次予算の30%, 50%, 80%, 100%到達時にSlackへ通知するシステムです。

**月次予算**: 200 USD
**通知閾値**: 30%, 50%, 80%, 100%
**ランニングコスト**: 完全無料（AWS無料枠内）

---

## システムアーキテクチャ

```
AWS Budgets (Bedrockのみ監視)
    ↓ (閾値到達時)
SNS Topic
    ↓
Lambda Function
    ↓ (Webhook URL取得)
SSM Parameter Store
    ↓
Slack通知
```

### コンポーネント

1. **AWS Budgets**: Bedrockサービスのみを対象に4段階の閾値を設定
2. **SNS**: Budgets → Lambda へのトリガー
3. **Lambda (Python)**: SNSメッセージを解析し、Slack通知を送信
4. **SSM Parameter Store**: Slack Webhook URL を安全に保管（無料）

---

## 前提条件

- AWS CLI 設定済み
- Terraform 1.0以上インストール済み
- Slack Workspace の管理者権限

---

## セットアップ手順

### 1. Slack Webhook URL取得

1. https://api.slack.com/apps にアクセス
2. "Create New App" → "From scratch"
3. App名: `Bedrock Cost Monitor`
4. "Incoming Webhooks" → ON
5. "Add New Webhook to Workspace"
6. 通知先チャンネルを選択
7. Webhook URLをコピー

### 2. プロジェクトのクローン/ダウンロード

```bash
cd bedrock-cost-monitor
```

### 3. 設定ファイル作成

#### 方法A: 自動セットアップスクリプト使用（推奨）

```bash
# .envファイル作成
cp .env.example .env

# .envファイルを編集してWebhook URLを設定
vim .env
```

**.env の内容:**
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

```bash
# セットアップスクリプト実行（terraform.tfvarsを自動生成）
./setup.sh
```

#### 方法B: 手動設定

```bash
cd terraform

# terraform.tfvarsを作成
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvarsを編集
vim terraform.tfvars
```

**terraform.tfvars の設定例:**

```hcl
aws_region         = "us-east-1"
environment        = "production"
budget_amount      = "200"
slack_webhook_url  = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
budget_start_date  = "2026-02-01_00:00"
```

### 4. Terraform実行

```bash
cd terraform

# 初期化（setup.shを使った場合はスキップ可）
terraform init

# プラン確認
terraform plan

# デプロイ
terraform apply
```

デプロイが完了すると、以下の出力が表示されます:

```
Outputs:

budget_name = "bedrock-monthly-budget"
budget_arn = "arn:aws:budgets::..."
lambda_function_name = "bedrock-cost-notifier"
lambda_log_group = "/aws/lambda/bedrock-cost-notifier"
sns_topic_arn = "arn:aws:sns:us-east-1:..."
ssm_parameter_name = "/bedrock-cost-monitor/slack-webhook-url"
```

---

## 検証方法

### 1. リソース確認

```bash
# Lambda関数が作成されたか確認
aws lambda list-functions --query "Functions[?FunctionName=='bedrock-cost-notifier']"

# AWS Budgets確認
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)

# SNS Topic確認
aws sns list-topics | grep bedrock-budget-alerts
```

### 2. テスト通知送信

```bash
# SNSトピックARNを取得
TOPIC_ARN=$(terraform output -raw sns_topic_arn)

# テストメッセージを送信
aws sns publish \
  --topic-arn $TOPIC_ARN \
  --message '{
    "budgetName": "bedrock-monthly-budget",
    "thresholdPercentage": 30,
    "actualAmount": 60.0,
    "limitAmount": 200.0
  }'
```

### 3. ログ確認

```bash
# Lambda関数のログをリアルタイム表示
aws logs tail /aws/lambda/bedrock-cost-notifier --follow

# エラーログを検索
aws logs filter-log-events \
  --log-group-name /aws/lambda/bedrock-cost-notifier \
  --filter-pattern "ERROR"
```

---

## 通知内容

### 閾値別の通知

| 閾値 | レベル | 色 | アイコン |
|------|--------|-----|---------|
| 30% | 情報 | 青 | 🔵 |
| 50% | 注意 | 黄 | ⚠️ |
| 80% | 警告 | オレンジ | ⚠️ |
| 100% | 緊急 | 赤 | 🚨 |

### Slack通知フォーマット

```
🔵 AWS Bedrock 予算アラート [情報]

閾値: 30%
現在の使用額: $60.00 USD
予算上限: $200 USD
使用率: 30.0%

AWS Bedrock Cost Monitor
```

---

## コスト見積もり

| サービス | 使用量 | 月額コスト |
|---------|--------|-----------|
| AWS Budgets | 1予算、4閾値 | $0（最初の2予算無料） |
| SNS | ~4通知/月 | $0（100万リクエスト無料） |
| Lambda | ~4実行/月 | $0（100万リクエスト無料） |
| SSM Parameter Store | 1パラメータ | $0（標準パラメータ無料） |
| CloudWatch Logs | ~1MB/月 | $0（5GB無料） |
| **合計** | | **$0** |

**完全に無料枠内で運用可能**

---

## トラブルシューティング

### Lambda関数が起動しない

```bash
# Lambda関数の設定確認
aws lambda get-function --function-name bedrock-cost-notifier

# SNSサブスクリプション確認
aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw sns_topic_arn)

# Lambda権限確認
aws lambda get-policy --function-name bedrock-cost-notifier
```

### Slack通知が届かない

```bash
# SSM Parameter Storeの値確認（復号化）
aws ssm get-parameter \
  --name /bedrock-cost-monitor/slack-webhook-url \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text

# Lambda関数のログでエラー確認
aws logs tail /aws/lambda/bedrock-cost-notifier --since 1h
```

### 予算通知が来ない

1. **AWS Budgets設定確認**
   ```bash
   aws budgets describe-budget \
     --account-id $(aws sts get-caller-identity --query Account --output text) \
     --budget-name bedrock-monthly-budget
   ```

2. **Bedrockの使用状況確認**
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=2026-02-01,End=2026-02-28 \
     --granularity MONTHLY \
     --metrics BlendedCost \
     --filter file://filter.json
   ```

   filter.json:
   ```json
   {
     "Dimensions": {
       "Key": "SERVICE",
       "Values": ["Amazon Bedrock"]
     }
   }
   ```

---

## セキュリティ考慮事項

1. **Slack Webhook URL**: SSM Parameter Store (SecureString) で暗号化保管
2. **IAMロール**: 最小権限の原則に従った設計
3. **terraform.tfvars**: `.gitignore` に追加（機密情報を含む）
4. **Terraform State**: S3バックエンド + DynamoDB ロックを推奨（本番環境）

### 本番環境向けState管理

`backend.tf` を編集してS3バックエンドを有効化:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "bedrock-cost-monitor/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## リソース削除

システムが不要になった場合:

```bash
cd terraform
terraform destroy
```

**注意**: 削除前にCloudWatch Logsなどのログを保存してください。

---

## ディレクトリ構造

```
bedrock-cost-monitor/
├── README.md                          # このファイル
├── .gitignore                         # Git除外設定
└── terraform/
    ├── main.tf                        # メインの統合設定
    ├── variables.tf                   # 変数定義
    ├── outputs.tf                     # 出力値
    ├── backend.tf                     # State管理設定
    ├── terraform.tfvars.example       # 設定例
    ├── terraform.tfvars               # 実際の値（Git管理外）
    └── modules/
        ├── ssm/                       # SSM Parameter Store
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── sns/                       # SNS Topic
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── lambda/                    # Lambda Function
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── src/
        │       └── index.py          # Lambda関数コード
        └── budgets/                   # AWS Budgets
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

---

## 今後の拡張案

- 複数Slackチャンネルへの通知
- サービス別の詳細コスト内訳
- 週次/月次レポート機能
- コスト異常検知（Cost Anomaly Detection連携）
- 予測コスト通知（Forecasted alerts）

---

## ライセンス

MIT License

---

## サポート

問題が発生した場合は、以下を確認してください:

1. [トラブルシューティング](#トラブルシューティング) セクション
2. CloudWatch Logsのエラーログ
3. AWS Budgetsの設定状態
4. IAMロールの権限設定

---

## 更新履歴

- **2026-01-25**: 初回リリース
  - AWS Budgets による Bedrock コスト監視
  - 4段階閾値（30%, 50%, 80%, 100%）
  - Slack通知機能
  - 完全無料構成
