# 🚀 5分でわかるクイックスタート

このガイドでは、最短ルートでシステムを理解・デプロイする方法を説明します。

---

## 📖 このシステムは何をするの？

**一言で言うと**: AWS Bedrockの料金が予算を超えそうになったらSlackに通知してくれるシステム

```
Bedrockで$60使った（予算$200の30%）
         ↓
   Slackに通知が届く
   「🔵 予算の30%を超えました！」
```

---

## 🏗️ 登場人物（AWSサービス）

| サービス | 役割 | イメージ |
|---------|------|---------|
| **AWS Budgets** | お金を監視 | 👀 見張り番 |
| **SNS** | メッセージを伝える | 📮 郵便配達員 |
| **Lambda** | 通知を整形して送る | 🤖 翻訳ロボット |
| **SSM** | URLを安全に保管 | 🔐 金庫 |

---

## 🗂️ ファイル構成（これだけ覚えれば OK）

```
terraform/
├── main.tf           ← 「何を作るか」の指示書
├── variables.tf      ← 「変更可能な設定」の定義
├── terraform.tfvars  ← ★あなたが編集するファイル★
└── modules/          ← 各サービスの詳細設定
    ├── budgets/      ← 予算監視の設定
    ├── lambda/       ← 通知処理の設定
    ├── sns/          ← メッセージキューの設定
    └── ssm/          ← 秘密保管の設定
```

---

## ⚡ デプロイ手順（コピペでOK）

### Step 1: 設定ファイルを作成

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: 設定を編集

```bash
# terraform.tfvars を開いて、Webhook URLを設定
vim terraform.tfvars
```

**変更するのはこれだけ：**
```hcl
slack_webhook_url = "https://hooks.slack.com/services/あなたの/URL"
```

### Step 3: デプロイ

```bash
terraform init    # 初回のみ
terraform apply   # 「yes」と入力
```

### 完了！ 🎉

---

## 🔧 Terraformコマンド早見表

| やりたいこと | コマンド |
|-------------|---------|
| 初期化（最初に1回） | `terraform init` |
| 変更内容を確認 | `terraform plan` |
| 実行（作成/更新） | `terraform apply` |
| 全削除 | `terraform destroy` |
| 出力値を見る | `terraform output` |

---

## 🧪 テスト方法

```bash
# SNSにテストメッセージを送信
aws sns publish \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --message '{"budgetName":"test","thresholdPercentage":30,"actualAmount":60,"limitAmount":200}'
```

Slackに通知が届けば成功！

---

## ❓ よくある質問

### Q: terraform.tfvars には何を書けばいい？

```hcl
aws_region         = "us-east-1"           # そのままでOK
environment        = "production"          # そのままでOK
budget_amount      = "200"                 # 月間予算（USD）
slack_webhook_url  = "https://..."         # ★これだけ必須★
budget_start_date  = "2026-02-01_00:00"    # 予算開始日
```

### Q: エラーが出た！

```bash
# まず初期化を試す
terraform init

# それでもダメなら詳細ログを確認
TF_LOG=DEBUG terraform apply
```

### Q: 全部消したい

```bash
terraform destroy
```

---

## 📚 もっと詳しく知りたい

| ドキュメント | 内容 |
|-------------|------|
| [TERRAFORM_BEGINNER_GUIDE.md](./TERRAFORM_BEGINNER_GUIDE.md) | Terraform完全初心者向け解説 |
| [PROJECT_DEEP_DIVE.md](./PROJECT_DEEP_DIVE.md) | コードの1行1行を詳細解説 |
| [../README.md](../README.md) | 公式README |

---

**💡 ヒント**: 困ったら `terraform plan` を実行してみてください。何が起きるか事前に確認できます！
