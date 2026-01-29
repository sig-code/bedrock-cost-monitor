# 🎓 Terraform 完全初心者ガイド

このガイドでは、Terraformを全く知らない方でも「Bedrock Cost Monitor」システムを完全に理解できるよう、ゼロから丁寧に解説します。

---

## 📚 目次

1. [Terraformとは何か？](#1-terraformとは何か)
2. [なぜTerraformを使うのか？](#2-なぜterraformを使うのか)
3. [基本的な用語集](#3-基本的な用語集)
4. [Terraformの基本構文](#4-terraformの基本構文)
5. [このプロジェクトの全体像](#5-このプロジェクトの全体像)
6. [ファイル構成の詳細解説](#6-ファイル構成の詳細解説)
7. [各モジュールの詳細解説](#7-各モジュールの詳細解説)
8. [Terraformコマンドの使い方](#8-terraformコマンドの使い方)
9. [トラブルシューティング](#9-トラブルシューティング)

---

## 1. Terraformとは何か？

### 簡単な説明

**Terraform**は、**インフラをコードで管理するツール**です。

通常、AWSのサービス（Lambda、SNS、予算アラートなど）を作成するには：
1. AWSコンソール（Webブラウザ）にログイン
2. 各サービスの画面を開いて、ボタンをクリック
3. 設定値を手動で入力
4. 「作成」ボタンを押す

これを**100個のリソース**に対して行うのは大変ですし、**ミスも起きやすい**です。

### Terraformを使うと...

```
設定ファイルを書く → terraformコマンド実行 → AWSリソースが自動作成される！
```

つまり、**コードを書いて実行するだけで、AWSの環境が自動的に構築される**のです。

### 例え話

| 手動でAWS構築 | Terraform |
|-------------|-----------|
| レシピなしで料理を作る | レシピを見て料理を作る |
| 毎回同じ味にならない | 毎回同じ味になる |
| 手順を忘れる | レシピが残る |
| 他の人に教えにくい | レシピを渡せばOK |

---

## 2. なぜTerraformを使うのか？

### メリット

| メリット | 説明 |
|---------|------|
| 🔄 **再現性** | 同じコードで同じ環境を何度でも作れる |
| 📝 **ドキュメント化** | コード自体がインフラの設計書になる |
| 👥 **チーム共有** | Gitでバージョン管理、レビューができる |
| 🗑️ **簡単削除** | `terraform destroy`で全リソースを一括削除 |
| 🔍 **変更検知** | 何が変わるか事前に確認できる |

### このプロジェクトでの恩恵

手動で作ると以下を全て個別に作成・設定する必要があります：
- AWS Budget（予算設定）
- SNS Topic（メッセージキュー）
- Lambda関数（通知処理）
- IAMロール・ポリシー（権限設定）
- SSM Parameter（秘密情報保存）

Terraformなら`terraform apply`**1コマンドで全て作成**できます！

---

## 3. 基本的な用語集

### 🔑 必須用語

| 用語 | 意味 | 例え |
|-----|------|-----|
| **Provider** | 操作対象のクラウドサービス | AWSやGCPなど。「どのお店で買い物するか」 |
| **Resource** | 実際に作成されるインフラ部品 | Lambda関数、S3バケットなど。「買う商品」 |
| **Variable** | 設定値を外部から渡す仕組み | リージョン名や予算額など。「注文オプション」 |
| **Module** | 再利用可能なリソースのまとまり | 「セット商品」 |
| **State** | 現在のインフラ状態を記録したファイル | 「購入履歴」 |
| **Plan** | 変更内容の事前確認 | 「会計前の確認」 |
| **Apply** | 変更の実行 | 「会計・購入」 |
| **Destroy** | リソースの削除 | 「返品」 |

### 📁 ファイル拡張子

| 拡張子 | 説明 |
|--------|------|
| `.tf` | Terraform設定ファイル |
| `.tfvars` | 変数の値を設定するファイル |
| `.tfstate` | 状態管理ファイル（自動生成） |

---

## 4. Terraformの基本構文

Terraformは**HCL（HashiCorp Configuration Language）**という言語で書きます。

### 4.1 Providerの宣言

```hcl
# どのクラウドサービスを使うか宣言
provider "aws" {
  region = "us-east-1"    # AWSのどのリージョンを使うか
}
```

### 4.2 Resourceの作成

```hcl
# リソースの種類   # 識別用の名前（任意）
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name-12345"
}
```

**構文パターン：**
```hcl
resource "リソースタイプ" "識別名" {
  設定項目1 = "値1"
  設定項目2 = "値2"
}
```

### 4.3 Variableの定義

```hcl
# 変数の定義
variable "budget_amount" {
  description = "月次予算額（USD）"   # 説明
  type        = string               # データ型
  default     = "200"                # デフォルト値
}

# 変数の使用
resource "aws_budgets_budget" "example" {
  limit_amount = var.budget_amount   # var.変数名 で参照
}
```

### 4.4 Moduleの使用

```hcl
# モジュールの呼び出し
module "lambda" {
  source = "./modules/lambda"    # モジュールの場所

  # モジュールに渡す引数
  function_name = "my-function"
  sns_topic_arn = module.sns.topic_arn   # 他モジュールの出力を参照
}
```

### 4.5 Outputの定義

```hcl
# 作成したリソースの情報を出力
output "lambda_function_name" {
  description = "作成されたLambda関数の名前"
  value       = aws_lambda_function.example.function_name
}
```

---

## 5. このプロジェクトの全体像

### 5.1 システムの目的

**AWS Bedrockの料金を監視し、予算の一定割合を超えたらSlackに通知する**

### 5.2 アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS クラウド                                  │
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │  AWS Budgets │───▶│  SNS Topic   │───▶│   Lambda     │          │
│  │              │    │              │    │              │          │
│  │ ・30%到達    │    │ メッセージを  │    │ 通知を整形   │          │
│  │ ・50%到達    │    │ 中継         │    │ してSlackへ  │          │
│  │ ・80%到達    │    │              │    │              │          │
│  │ ・100%到達   │    │              │    │      │       │          │
│  └──────────────┘    └──────────────┘    └──────┼───────┘          │
│                                                  │                   │
│  ┌──────────────┐                               │                   │
│  │     SSM      │◀──────────────────────────────┘                   │
│  │ Parameter    │  Webhook URLを取得                                │
│  │ Store        │                                                    │
│  └──────────────┘                                                    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                            ┌──────────────┐
                            │    Slack     │
                            │              │
                            │  通知受信    │
                            └──────────────┘
```

### 5.3 各AWSサービスの役割

| サービス | 役割 | 分かりやすく言うと |
|---------|------|------------------|
| **AWS Budgets** | 料金が閾値を超えたら通知 | 「お金の見張り番」 |
| **SNS** | メッセージを次のサービスに渡す | 「伝言係」 |
| **Lambda** | 通知メッセージを整形してSlackに送信 | 「翻訳・配達係」 |
| **SSM Parameter Store** | Slack URLを安全に保存 | 「金庫」 |

### 5.4 通知の流れ

1. **料金が閾値を超える** → AWS Budgetsが検知
2. **SNSにメッセージ送信** → 「30%超えました！」
3. **Lambdaが起動** → SNSからのメッセージを受信
4. **SSMからWebhook URL取得** → 安全に保存されたURLを取得
5. **Slackに通知** → 見やすく整形されたメッセージを送信

---

## 6. ファイル構成の詳細解説

```
terraform/
├── main.tf              # メイン設定（モジュールの呼び出し）
├── variables.tf         # 入力変数の定義
├── outputs.tf           # 出力値の定義
├── terraform.tfvars     # 変数の実際の値（自分で設定）
├── terraform.tfvars.example  # 設定例（参考用）
├── backend.tf           # 状態管理の設定
│
└── modules/             # 再利用可能なモジュール群
    ├── budgets/         # 予算監視モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── lambda/          # 通知処理モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── src/
    │       └── index.py # Lambda関数のコード
    │
    ├── sns/             # メッセージキューモジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── ssm/             # 秘密情報保存モジュール
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 各ファイルの役割

| ファイル | 役割 | 中身の例 |
|---------|------|---------|
| `main.tf` | メインの設定 | provider宣言、module呼び出し |
| `variables.tf` | 変数の「定義」 | 変数名、型、説明、デフォルト値 |
| `terraform.tfvars` | 変数の「値」 | 実際に使う値を設定 |
| `outputs.tf` | 出力の定義 | 作成後に表示する情報 |
| `backend.tf` | 状態ファイルの保存先 | ローカルやS3など |

---

## 7. 各モジュールの詳細解説

### 7.1 SSMモジュール（秘密情報保存）

📁 **場所**: `modules/ssm/`

**目的**: Slack Webhook URLを安全に保存する

```hcl
# modules/ssm/main.tf の内容

resource "aws_ssm_parameter" "slack_webhook_url" {
  name        = "/bedrock-cost-monitor/slack-webhook-url"  # パラメータの名前（パス形式）
  description = "Slack Incoming Webhook URL..."            # 説明
  type        = "SecureString"                             # 暗号化して保存！
  value       = var.slack_webhook_url                      # 実際のURL（変数から）
}
```

**ポイント**:
- `SecureString` = AWS KMSで自動的に暗号化
- URLをコードに直書きしない（セキュリティ対策）
- Lambda関数が実行時に取得

---

### 7.2 SNSモジュール（メッセージ配信）

📁 **場所**: `modules/sns/`

**目的**: AWS BudgetsからLambdaへメッセージを中継

```hcl
# SNS Topic（メッセージの宛先）を作成
resource "aws_sns_topic" "budget_alerts" {
  name = "bedrock-budget-alerts"   # トピック名
}

# 誰がこのトピックにメッセージを送れるか設定
resource "aws_sns_topic_policy" "budget_alerts_policy" {
  arn = aws_sns_topic.budget_alerts.arn

  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"   # AWS Budgetsからの送信を許可
        }
        Action   = "SNS:Publish"
      }
    ]
  })
}
```

**ポイント**:
- SNS = Simple Notification Service
- Pub/Sub（発行/購読）モデル
- Budgetsが「発行者」、Lambdaが「購読者」

---

### 7.3 Lambdaモジュール（通知処理）

📁 **場所**: `modules/lambda/`

**目的**: SNSからのメッセージを受け取り、Slackに通知

#### 7.3.1 Lambda関数本体

```hcl
resource "aws_lambda_function" "cost_notifier" {
  filename         = "lambda_function.zip"      # アップロードするコード
  function_name    = "bedrock-cost-notifier"    # 関数名
  role            = aws_iam_role.lambda_role.arn  # 実行権限
  handler         = "index.lambda_handler"      # エントリーポイント
  runtime         = "python3.11"                # 実行環境

  environment {
    variables = {
      SLACK_WEBHOOK_PARAMETER = "/bedrock-cost-monitor/slack-webhook-url"
    }
  }
}
```

#### 7.3.2 IAMロール（権限設定）

```hcl
# Lambda関数が「何をできるか」を定義
resource "aws_iam_role" "lambda_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"   # Lambda サービスがこのロールを使える
      }
    }]
  })
}

# 具体的な権限
resource "aws_iam_role_policy" "lambda_policy" {
  policy = jsonencode({
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",      # ログを作成
          "logs:CreateLogStream",     # ログストリームを作成
          "logs:PutLogEvents"         # ログを書き込み
        ]
        Resource = "*"
      },
      {
        Action = ["ssm:GetParameter"]  # SSMからパラメータを取得
        Resource = "arn:aws:ssm:..."   # 特定のパラメータのみ許可
      }
    ]
  })
}
```

#### 7.3.3 SNSとの連携

```hcl
# Lambda関数をSNSトピックに購読登録
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = var.sns_topic_arn                   # どのトピックを購読するか
  protocol  = "lambda"                             # Lambda経由で受信
  endpoint  = aws_lambda_function.cost_notifier.arn
}

# SNSからLambdaを呼び出す許可
resource "aws_lambda_permission" "allow_sns" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_notifier.function_name
  principal     = "sns.amazonaws.com"              # SNSサービスからの呼び出しを許可
  source_arn    = var.sns_topic_arn
}
```

---

### 7.4 Budgetsモジュール（予算監視）

📁 **場所**: `modules/budgets/`

**目的**: Bedrockの利用料金を監視し、閾値超過時に通知

```hcl
resource "aws_budgets_budget" "bedrock_monthly" {
  name              = "bedrock-monthly-budget"
  budget_type       = "COST"           # コスト監視
  limit_amount      = "200"            # 予算上限（USD）
  limit_unit        = "USD"
  time_unit         = "MONTHLY"        # 月次

  # 重要！Bedrockサービスのみを監視対象に
  cost_filter {
    name = "Service"
    values = ["Amazon Bedrock"]
  }

  # 30%到達時の通知
  notification {
    comparison_operator = "GREATER_THAN"
    threshold          = 30             # 30%
    threshold_type     = "PERCENTAGE"
    notification_type  = "ACTUAL"       # 実際の使用量
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  # 50%, 80%, 100%も同様に設定...
}
```

**ポイント**:
- `cost_filter` でBedrockのみを対象に
- 複数の`notification`ブロックで4段階の閾値を設定
- `ACTUAL` = 予測ではなく実際の使用量

---

## 8. Terraformコマンドの使い方

### 8.1 基本コマンド一覧

| コマンド | 説明 | いつ使う？ |
|---------|------|----------|
| `terraform init` | 初期化 | 最初に1回だけ実行 |
| `terraform plan` | 変更内容の確認 | 実行前に必ず確認 |
| `terraform apply` | 変更の適用 | リソースを作成/更新 |
| `terraform destroy` | 全削除 | 全てのリソースを削除 |
| `terraform output` | 出力値の表示 | ARNなどを確認 |
| `terraform fmt` | コード整形 | コードを綺麗に |
| `terraform validate` | 構文チェック | エラーがないか確認 |

### 8.2 実行の流れ

```bash
# 1. terraformディレクトリに移動
cd terraform

# 2. 初期化（プラグインのダウンロード）
terraform init

# 3. 設定の確認
terraform plan

# 出力例:
# Plan: 8 to add, 0 to change, 0 to destroy.
# ↑ 8個のリソースが新規作成されるという意味

# 4. 実行（リソース作成）
terraform apply

# 確認メッセージが表示される
# Do you want to perform these actions?
#   Enter a value: yes  ← "yes"と入力

# 5. 作成されたリソースの情報を確認
terraform output
```

### 8.3 planの読み方

```
# aws_lambda_function.cost_notifier will be created
  + resource "aws_lambda_function" "cost_notifier" {
      + function_name = "bedrock-cost-notifier"
      + runtime       = "python3.11"
      ...
    }
```

| 記号 | 意味 |
|-----|------|
| `+` | 新規作成 |
| `-` | 削除 |
| `~` | 変更（更新） |
| `-/+` | 削除して再作成 |

### 8.4 よく使う操作

```bash
# 特定のリソースだけ再作成
terraform apply -replace="aws_lambda_function.cost_notifier"

# 出力値だけ表示
terraform output sns_topic_arn

# 現在の状態を確認
terraform state list

# 詳細なログを表示
TF_LOG=DEBUG terraform apply
```

---

## 9. トラブルシューティング

### 9.1 よくあるエラー

#### ❌ Provider認証エラー

```
Error: No valid credential sources found
```

**原因**: AWS認証情報が設定されていない

**解決策**:
```bash
# AWS CLIで認証設定
aws configure

# または環境変数を設定
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

#### ❌ リソースが既に存在

```
Error: Error creating SNS Topic: TopicAlreadyExists
```

**原因**: 同じ名前のリソースが既存

**解決策**:
1. 既存リソースを手動削除
2. または `terraform import` でインポート

#### ❌ 権限エラー

```
Error: AccessDenied: User is not authorized
```

**原因**: IAMユーザーに必要な権限がない

**解決策**: 必要なIAMポリシーをアタッチ

#### ❌ 変数が未設定

```
Error: No value for required variable
```

**原因**: `terraform.tfvars` に必要な値がない

**解決策**:
```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集して値を設定
```

### 9.2 状態ファイルの問題

```bash
# 状態ファイルが壊れた場合
terraform state pull > backup.tfstate    # バックアップ
terraform state list                      # 現在の状態確認

# 特定リソースを状態から削除（実際のリソースは削除されない）
terraform state rm aws_sns_topic.budget_alerts

# リソースをインポート
terraform import aws_sns_topic.budget_alerts arn:aws:sns:...
```

### 9.3 デバッグ方法

```bash
# 詳細ログを有効化
export TF_LOG=DEBUG
terraform apply 2>&1 | tee terraform.log

# 特定リソースの詳細を確認
terraform state show aws_lambda_function.cost_notifier
```

---

## 📝 まとめ

### このプロジェクトで学んだこと

1. **Terraform** = インフラをコードで管理するツール
2. **HCL** = Terraformの設定言語
3. **Provider** = AWS等のクラウドサービスへの接続設定
4. **Resource** = 実際に作成されるインフラ部品
5. **Module** = 再利用可能なResourceのまとまり
6. **Variable** = 設定値を外部から注入する仕組み

### 基本的なワークフロー

```
設定ファイル作成 → init → plan → apply → 完成！
```

### 次のステップ

1. [公式ドキュメント](https://developer.hashicorp.com/terraform/docs)を読む
2. [Terraform Registry](https://registry.terraform.io/)でモジュールを探す
3. 自分でシンプルなリソースを作ってみる

---

**🎉 おめでとうございます！これでTerraformの基礎は完璧です！**
