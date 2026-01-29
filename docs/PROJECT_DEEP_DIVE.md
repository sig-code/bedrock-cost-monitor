# 🏗️ プロジェクト構成の詳細解説

このドキュメントでは、Bedrock Cost Monitorプロジェクトの各ファイルを1行1行詳しく解説します。

---

## 📁 プロジェクト構成

```
bedrock-cost-monitor/
├── README.md                    # プロジェクト説明書
├── setup.sh                     # 自動セットアップスクリプト
├── docs/                        # ドキュメント
│   ├── TERRAFORM_BEGINNER_GUIDE.md
│   └── PROJECT_DEEP_DIVE.md (このファイル)
│
└── terraform/                   # Terraform設定ファイル群
    ├── main.tf                  # メイン設定
    ├── variables.tf             # 変数定義
    ├── outputs.tf               # 出力定義
    ├── backend.tf               # 状態管理設定
    ├── terraform.tfvars         # 変数の値（要設定）
    ├── terraform.tfvars.example # 設定例
    │
    └── modules/                 # 再利用モジュール
        ├── budgets/             # 予算監視
        ├── lambda/              # 通知処理
        ├── sns/                 # メッセージキュー
        └── ssm/                 # 秘密情報保存
```

---

## 📄 terraform/main.tf - メイン設定ファイル

### 全体の役割

main.tfは**オーケストラの指揮者**のような役割です。各モジュールを呼び出し、データの受け渡しを制御します。

### コード解説

```hcl
# ═══════════════════════════════════════════════════════════════════════
# セクション1: Terraformの設定
# ═══════════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.0"
  # ↑ Terraformのバージョンが1.0以上であることを要求
  #   古いバージョンでは動かない機能を使っている場合に重要

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # ↑ AWSプロバイダーの設定
    #   source: どこからプラグインを取得するか
    #   version: "~> 5.0" は「5.x系の最新」を意味（5.0, 5.1, 5.99はOK、6.0はNG）

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    # ↑ Lambda用のZIPファイル作成に使用
  }
}

# ═══════════════════════════════════════════════════════════════════════
# セクション2: AWSプロバイダーの設定
# ═══════════════════════════════════════════════════════════════════════

provider "aws" {
  region = var.aws_region
  # ↑ var.aws_region = variables.tfで定義された変数を参照
  #   terraform.tfvarsで「us-east-1」と設定されていればそれを使用

  default_tags {
    tags = merge(
      {
        Project     = "bedrock-cost-monitor"
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
  }
  # ↑ 全てのリソースに自動的にタグを付ける
  #   merge()関数で複数のタグを結合
  #   これにより、どのプロジェクトのリソースか一目瞭然に
}

# ═══════════════════════════════════════════════════════════════════════
# セクション3: ローカル変数
# ═══════════════════════════════════════════════════════════════════════

locals {
  common_tags = {
    Project     = "bedrock-cost-monitor"
    Environment = var.environment
  }
}
# ↑ locals = このファイル内で繰り返し使う値を定義
#   local.common_tags で参照できる

# ═══════════════════════════════════════════════════════════════════════
# セクション4: モジュールの呼び出し（ここが本体！）
# ═══════════════════════════════════════════════════════════════════════

# --- SSMモジュール ---
module "ssm" {
  source = "./modules/ssm"
  # ↑ modules/ssmディレクトリの設定を読み込む

  slack_webhook_url = var.slack_webhook_url
  # ↑ 外部から受け取ったWebhook URLをSSMモジュールに渡す

  tags = local.common_tags
}

# --- SNSモジュール ---
module "sns" {
  source = "./modules/sns"

  topic_name = "bedrock-budget-alerts"
  tags       = local.common_tags
}

# --- Lambdaモジュール ---
module "lambda" {
  source = "./modules/lambda"

  function_name       = "bedrock-cost-notifier"
  sns_topic_arn       = module.sns.topic_arn
  # ↑ 重要！SNSモジュールのoutputを参照
  #   SNSが先に作成されないとARNが取得できない

  ssm_parameter_name  = module.ssm.parameter_name
  ssm_parameter_arn   = module.ssm.parameter_arn
  tags                = local.common_tags

  depends_on = [module.ssm, module.sns]
  # ↑ 明示的な依存関係
  #   SSMとSNSが作成されてからLambdaを作成
}

# --- Budgetsモジュール ---
module "budgets" {
  source = "./modules/budgets"

  budget_name        = "bedrock-monthly-budget"
  budget_amount      = var.budget_amount
  budget_start_date  = var.budget_start_date
  sns_topic_arn      = module.sns.topic_arn
  notification_email = var.notification_email
  tags               = local.common_tags

  depends_on = [module.sns]
}
```

### モジュール間の依存関係

```
                    ┌─────────┐
                    │variables│ (terraform.tfvars)
                    └────┬────┘
                         │ 変数を渡す
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                       main.tf                                │
│                                                              │
│  ┌───────┐                    ┌───────┐                     │
│  │  SSM  │                    │  SNS  │                     │
│  └───┬───┘                    └───┬───┘                     │
│      │                            │                          │
│      │ parameter_arn              │ topic_arn                │
│      │ parameter_name             │                          │
│      └────────────┬───────────────┘                          │
│                   ▼                                          │
│              ┌─────────┐                                     │
│              │ Lambda  │◀──────────────────┐                │
│              └─────────┘                    │                │
│                                             │ topic_arn      │
│              ┌─────────┐                    │                │
│              │ Budgets │────────────────────┘                │
│              └─────────┘                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📄 terraform/variables.tf - 変数定義

```hcl
# ═══════════════════════════════════════════════════════════════════════
# 必須変数（デフォルト値なし → terraform.tfvarsで必ず設定）
# ═══════════════════════════════════════════════════════════════════════

variable "budget_start_date" {
  description = "Budget start date in format YYYY-MM-DD_HH:MM"
  type        = string
  # ↑ デフォルト値がない = 必須
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for cost notifications"
  type        = string
  sensitive   = true
  # ↑ sensitive = true
  #   - terraform planで値が隠される
  #   - ログに出力されない
  #   - 秘密情報に使用
}

# ═══════════════════════════════════════════════════════════════════════
# オプション変数（デフォルト値あり → 設定しなくてもOK）
# ═══════════════════════════════════════════════════════════════════════

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  # ↑ 指定しなければ us-east-1 を使用
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = string
  default     = "200"
}

variable "notification_email" {
  description = "Optional email address for budget notifications"
  type        = string
  default     = ""
  # ↑ 空文字がデフォルト = オプション
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  # ↑ map(string) = キーと値が両方文字列の辞書型
  #   例: { "Team" = "Platform", "CostCenter" = "1234" }
  default     = {}
}
```

### 変数の型一覧

| 型 | 説明 | 例 |
|----|------|----|
| `string` | 文字列 | `"hello"` |
| `number` | 数値 | `42`, `3.14` |
| `bool` | 真偽値 | `true`, `false` |
| `list(string)` | 文字列のリスト | `["a", "b", "c"]` |
| `map(string)` | 文字列の辞書 | `{ key = "value" }` |
| `object({...})` | 構造化オブジェクト | 複雑な構造 |

---

## 📄 terraform/terraform.tfvars - 変数の値

```hcl
# ═══════════════════════════════════════════════════════════════════════
# このファイルで variables.tf で定義した変数に「値」を設定
# ═══════════════════════════════════════════════════════════════════════

aws_region         = "us-east-1"
# ↑ AWSリージョン。コスト監視はus-east-1推奨（Billing情報がここに集約）

environment        = "production"
# ↑ 環境名。タグに使用される

budget_amount      = "200"
# ↑ 月間予算（USD）。この金額の30%, 50%, 80%, 100%で通知

slack_webhook_url  = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# ↑ ★重要★ 自分のSlack Webhook URLに置き換える

budget_start_date  = "2026-02-01_00:00"
# ↑ 予算の開始日。通常は翌月1日を指定

# notification_email = "your-email@example.com"
# ↑ オプション。100%到達時にメールでも通知したい場合
```

### ⚠️ セキュリティ注意

```
# .gitignore に以下を追加！
terraform.tfvars
*.tfvars

# 理由: Webhook URLなどの秘密情報がGitHubに公開されてしまう
```

---

## 📄 modules/budgets/main.tf - 予算監視

```hcl
# 現在のAWSアカウントIDを取得（動的データ）
data "aws_caller_identity" "current" {}

# AWS Budget リソース
resource "aws_budgets_budget" "bedrock_monthly" {
  name              = var.budget_name
  budget_type       = "COST"
  # ↑ COST = コストベースの予算
  #   他に USAGE（使用量ベース）、RI_UTILIZATION（予約インスタンス利用率）などがある

  limit_amount      = var.budget_amount
  limit_unit        = "USD"
  time_period_start = var.budget_start_date
  time_unit         = "MONTHLY"
  # ↑ MONTHLY = 毎月リセット
  #   QUARTERLY = 四半期、ANNUALLY = 年次 も可能

  # ★重要★ Bedrockサービスのみをフィルタリング
  cost_filter {
    name = "Service"
    values = ["Amazon Bedrock"]
  }
  # ↑ これがないと全AWSサービスの合計になる
  #   "Amazon Bedrock" は正確なサービス名（大文字小文字注意）

  # 30%閾値の通知設定
  notification {
    comparison_operator        = "GREATER_THAN"
    # ↑ GREATER_THAN = より大きい
    #   LESS_THAN = より小さい
    #   EQUAL_TO = 等しい

    threshold                  = 30
    threshold_type            = "PERCENTAGE"
    # ↑ PERCENTAGE = パーセンテージ
    #   ABSOLUTE_VALUE = 絶対値（例: 60 USD）

    notification_type         = "ACTUAL"
    # ↑ ACTUAL = 実際の使用量
    #   FORECASTED = 予測値

    subscriber_sns_topic_arns = [var.sns_topic_arn]
    # ↑ 通知先のSNSトピック
  }

  # 50%, 80%, 100%も同様の構造で定義
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  # オプション: メール通知（100%時のみ）
  dynamic "notification" {
    for_each = var.notification_email != "" ? [1] : []
    # ↑ dynamic = 条件付きでブロックを生成
    #   notification_emailが空でなければnotificationブロックを1つ追加

    content {
      comparison_operator       = "GREATER_THAN"
      threshold                = 100
      threshold_type           = "PERCENTAGE"
      notification_type        = "ACTUAL"
      subscriber_email_addresses = [var.notification_email]
    }
  }
}
```

---

## 📄 modules/lambda/main.tf - Lambda関数

```hcl
# ═══════════════════════════════════════════════════════════════════════
# Lambda関数のパッケージング
# ═══════════════════════════════════════════════════════════════════════

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/index.py"
  # ↑ ${path.module} = このモジュールのディレクトリパス
  output_path = "${path.module}/lambda_function.zip"
}
# ↑ Pythonファイルを自動的にZIP化
#   これがないと手動でZIPを作成する必要がある

# ═══════════════════════════════════════════════════════════════════════
# IAMロール（Lambda関数の「身分証明書」）
# ═══════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  # ↑ 「信頼ポリシー」
  #   「誰がこのロールを使えるか」を定義
  #   lambda.amazonaws.com = Lambdaサービスのみが使用可能
}

# ═══════════════════════════════════════════════════════════════════════
# IAMポリシー（Lambda関数が「何をできるか」）
# ═══════════════════════════════════════════════════════════════════════

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # ↑ CloudWatch Logsへのログ出力を許可
      #   これがないとLambdaのログが見れない

      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = var.ssm_parameter_arn
      }
      # ↑ SSMパラメータの読み取りを許可
      #   var.ssm_parameter_arn = 特定のパラメータのみ許可（最小権限の原則）
    ]
  })
}

# ═══════════════════════════════════════════════════════════════════════
# Lambda関数本体
# ═══════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "cost_notifier" {
  filename         = data.archive_file.lambda_zip.output_path
  # ↑ アップロードするZIPファイル

  function_name    = var.function_name
  role            = aws_iam_role.lambda_execution_role.arn
  # ↑ 上で作成したIAMロールを使用

  handler         = "index.lambda_handler"
  # ↑ ファイル名.関数名
  #   index.py の lambda_handler 関数を実行

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # ↑ ZIPファイルのハッシュ値
  #   コードが変更されたかどうかを検知
  #   変更があれば自動的に再デプロイ

  runtime         = "python3.11"
  # ↑ 実行環境。python3.9, python3.10なども可能

  timeout         = 30
  # ↑ タイムアウト（秒）。デフォルトは3秒で短すぎる

  environment {
    variables = {
      SLACK_WEBHOOK_PARAMETER = var.ssm_parameter_name
    }
  }
  # ↑ 環境変数
  #   Pythonコードから os.environ['SLACK_WEBHOOK_PARAMETER'] で参照
}

# ═══════════════════════════════════════════════════════════════════════
# CloudWatch Logs
# ═══════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
  # ↑ ログを7日間保持
  #   長くするとストレージコストがかかる
}

# ═══════════════════════════════════════════════════════════════════════
# SNSとの連携
# ═══════════════════════════════════════════════════════════════════════

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.cost_notifier.arn
}
# ↑ LambdaをSNSトピックの「購読者」として登録
#   トピックにメッセージが来たらLambdaが呼び出される

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}
# ↑ SNSがLambdaを呼び出す「許可証」
#   これがないとSNSはLambdaを呼び出せない（Access Denied）
```

---

## 📄 modules/lambda/src/index.py - Pythonコード

```python
import json
import os
import urllib3
import boto3
from datetime import datetime

# HTTP接続プール（再利用で効率化）
http = urllib3.PoolManager()

# SSMクライアント
ssm_client = boto3.client('ssm')


def get_slack_webhook_url():
    """
    SSM Parameter StoreからSlack Webhook URLを取得

    なぜSSMを使う？
    - コードにURLを直書きしない（セキュリティ）
    - URLを変更してもLambdaの再デプロイが不要
    - 暗号化されて保存される
    """
    parameter_name = os.environ['SLACK_WEBHOOK_PARAMETER']
    # ↑ 環境変数からパラメータ名を取得
    #   Terraformで設定した値が入っている

    response = ssm_client.get_parameter(
        Name=parameter_name,
        WithDecryption=True  # 暗号化を解除して取得
    )
    return response['Parameter']['Value']


def get_notification_config(threshold):
    """
    閾値に応じた通知の見た目を決定

    threshold: 30, 50, 80, 100 のいずれか
    """
    if threshold >= 100:
        return {
            'color': '#FF0000',   # 赤
            'icon': '🚨',
            'level': '緊急'
        }
    elif threshold >= 80:
        return {
            'color': '#FF8C00',   # オレンジ
            'icon': '⚠️',
            'level': '警告'
        }
    elif threshold >= 50:
        return {
            'color': '#FFD700',   # 黄色
            'icon': '⚠️',
            'level': '注意'
        }
    else:
        return {
            'color': '#36A64F',   # 緑
            'icon': '🔵',
            'level': '情報'
        }


def parse_sns_message(event):
    """
    SNSから受け取ったイベントを解析

    eventの構造:
    {
      "Records": [
        {
          "Sns": {
            "Message": "{\"budgetName\": \"...\", ...}"
          }
        }
      ]
    }
    """
    sns_message = json.loads(event['Records'][0]['Sns']['Message'])
    # ↑ JSONが二重になっているので2回パース

    budget_name = sns_message.get('budgetName', 'Unknown')
    threshold = float(sns_message.get('thresholdPercentage', 0))
    actual_amount = float(sns_message.get('actualAmount', 0))
    limit_amount = float(sns_message.get('limitAmount', 0))

    usage_percentage = (actual_amount / limit_amount * 100) if limit_amount > 0 else 0

    return {
        'budget_name': budget_name,
        'threshold': threshold,
        'actual_amount': actual_amount,
        'limit_amount': limit_amount,
        'usage_percentage': usage_percentage
    }


def send_slack_notification(webhook_url, budget_info):
    """
    Slack Incoming Webhookを使って通知を送信

    Slack APIのフォーマットに従ってJSONを構築
    """
    config = get_notification_config(budget_info['threshold'])

    message = {
        'attachments': [
            {
                'color': config['color'],
                'title': f"{config['icon']} AWS Bedrock 予算アラート [{config['level']}]",
                'fields': [
                    {'title': '閾値', 'value': f"{budget_info['threshold']:.0f}%", 'short': True},
                    {'title': '現在の使用額', 'value': f"${budget_info['actual_amount']:.2f} USD", 'short': True},
                    {'title': '予算上限', 'value': f"${budget_info['limit_amount']:.0f} USD", 'short': True},
                    {'title': '使用率', 'value': f"{budget_info['usage_percentage']:.1f}%", 'short': True}
                ],
                'footer': 'AWS Bedrock Cost Monitor',
                'ts': int(datetime.now().timestamp())
            }
        ]
    }

    # HTTP POSTリクエスト
    response = http.request(
        'POST',
        webhook_url,
        body=json.dumps(message).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )

    return response.status == 200


def lambda_handler(event, context):
    """
    メインのエントリーポイント

    Lambdaはこの関数を呼び出す（Terraformでhandlerに指定）

    引数:
    - event: SNSからのイベントデータ
    - context: Lambda実行環境の情報（メモリ、タイムアウトなど）
    """
    print(f"Received event: {json.dumps(event)}")
    # ↑ CloudWatch Logsに出力される（デバッグ用）

    # 1. Webhook URL取得
    webhook_url = get_slack_webhook_url()

    # 2. メッセージ解析
    budget_info = parse_sns_message(event)

    # 3. Slack通知
    success = send_slack_notification(webhook_url, budget_info)

    # 4. レスポンス返却
    return {
        'statusCode': 200 if success else 500,
        'body': json.dumps({'message': 'Notification sent' if success else 'Failed'})
    }
```

---

## 🔄 データフローの詳細

### 1. 料金が閾値を超えた時

```
AWS Budgets
    │
    │ 「30%超えました」というメッセージを生成
    │
    ▼
SNS Topic (bedrock-budget-alerts)
    │
    │ 購読者（Lambda）にメッセージを配信
    │
    ▼
Lambda (bedrock-cost-notifier)
    │
    │ 1. eventからメッセージを取り出す
    │ 2. SSMからWebhook URLを取得
    │ 3. Slack形式にフォーマット
    │ 4. HTTP POSTでSlackに送信
    │
    ▼
Slack Webhook
    │
    ▼
Slackチャンネルに通知が表示される 🎉
```

### 2. メッセージの変換

```
【AWS Budgetsが生成するメッセージ】
{
  "budgetName": "bedrock-monthly-budget",
  "thresholdPercentage": 30,
  "actualAmount": 60.0,
  "limitAmount": 200.0
}

        ↓ Lambda関数で変換

【Slackに送信されるメッセージ】
{
  "attachments": [{
    "color": "#36A64F",
    "title": "🔵 AWS Bedrock 予算アラート [情報]",
    "fields": [
      {"title": "閾値", "value": "30%"},
      {"title": "現在の使用額", "value": "$60.00 USD"},
      {"title": "予算上限", "value": "$200 USD"},
      {"title": "使用率", "value": "30.0%"}
    ]
  }]
}
```

---

## ✅ 理解度チェック

以下の質問に答えられれば、このプロジェクトを完全に理解できています！

1. `terraform.tfvars` と `variables.tf` の違いは？
2. `depends_on` は何のために使う？
3. Lambda関数がSSMからURLを取得する理由は？
4. `cost_filter` を設定しないとどうなる？
5. `sensitive = true` を設定すると何が起きる？

---

**📚 このドキュメントを読めば、Terraformとこのプロジェクトの仕組みが完全に理解できるはずです！**
