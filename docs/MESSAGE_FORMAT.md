# 📨 メッセージフォーマット詳細ガイド

AWS BudgetsからSlackまでのメッセージ変換フローと、各段階でのJSON構造を詳しく解説します。

---

## 🔄 メッセージフロー全体像

```
AWS Budgets
    ↓ (JSON形式でSNSに送信)
SNS Topic
    ↓ (SNSのイベント構造でLambdaに配信)
Lambda Function
    ↓ (Slack Webhook形式に変換)
Slack Workflow
```

---

## 📊 1. AWS Budgets → SNS（元データ）

### AWS Budgetsが送信するメッセージ

```json
{
  "budgetName": "bedrock-monthly-budget",
  "thresholdPercentage": 30,
  "actualAmount": 60.0,
  "limitAmount": 200.0
}
```

### フィールド説明

| フィールド | 型 | 説明 | 例 |
|-----------|----|----|-----|
| `budgetName` | string | 予算名 | "bedrock-monthly-budget" |
| `thresholdPercentage` | number | 閾値（%） | 30, 50, 80, 100 |
| `actualAmount` | number | 現在の使用額（USD） | 60.0 |
| `limitAmount` | number | 予算上限（USD） | 200.0 |

---

## 📦 2. SNS → Lambda（SNSイベント構造）

Lambda関数が受け取る実際のeventオブジェクト：

```json
{
  "Records": [
    {
      "EventSource": "aws:sns",
      "EventVersion": "1.0",
      "EventSubscriptionArn": "arn:aws:sns:us-east-1:580572930080:bedrock-budget-alerts:c69c9dc6-...",
      "Sns": {
        "Type": "Notification",
        "MessageId": "45af77fd-0a0d-5525-9c82-160b00bbbdb9",
        "TopicArn": "arn:aws:sns:us-east-1:580572930080:bedrock-budget-alerts",
        "Subject": null,
        "Message": "{\"budgetName\":\"bedrock-monthly-budget\",\"thresholdPercentage\":30,\"actualAmount\":60.0,\"limitAmount\":200.0}",
        "Timestamp": "2026-01-30T12:34:56.789Z",
        "SignatureVersion": "1",
        "Signature": "...",
        "SigningCertUrl": "...",
        "UnsubscribeUrl": "..."
      }
    }
  ]
}
```

**重要**: `Sns.Message` フィールドは**JSON文字列**なので、2回パースが必要！

```python
# Lambda内での処理
sns_message_string = event['Records'][0]['Sns']['Message']  # 文字列
sns_message = json.loads(sns_message_string)  # オブジェクトに変換
```

---

## 💬 3. Lambda → Slack（Slack Webhook形式）

### Lambda関数が送信するSlackメッセージ

```json
{
  "attachments": [
    {
      "color": "#36A64F",
      "title": "🔵 AWS Bedrock 予算アラート [情報]",
      "fields": [
        {
          "title": "閾値",
          "value": "30%",
          "short": true
        },
        {
          "title": "現在の使用額",
          "value": "$60.00 USD",
          "short": true
        },
        {
          "title": "予算上限",
          "value": "$200 USD",
          "short": true
        },
        {
          "title": "使用率",
          "value": "30.0%",
          "short": true
        }
      ],
      "footer": "AWS Bedrock Cost Monitor",
      "ts": 1738242896
    }
  ]
}
```

### 閾値別のカラーとアイコン

| 閾値 | カラーコード | アイコン | レベル |
|-----|------------|---------|--------|
| 30% | `#36A64F` (緑) | 🔵 | 情報 |
| 50% | `#FFD700` (黄) | ⚠️ | 注意 |
| 80% | `#FF8C00` (橙) | ⚠️ | 警告 |
| 100% | `#FF0000` (赤) | 🚨 | 緊急 |

---

## 🔧 Slack Workflow用の変数マッピング

Slackワークフローでは、以下の変数を使用できます：

### 入力変数（AWS Budgetsから）

```javascript
// Workflow Builder で使用する変数名
{
  "budget_name": "bedrock-monthly-budget",      // 予算名
  "threshold": 30,                               // 閾値（%）
  "actual_amount": 60.0,                        // 使用額
  "limit_amount": 200.0,                        // 予算上限
  "usage_percentage": 30.0                      // 使用率（計算済み）
}
```

### Slackメッセージブロック例

```json
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🔵 AWS Bedrock 予算アラート",
        "emoji": true
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*閾値:*\n{{threshold}}%"
        },
        {
          "type": "mrkdwn",
          "text": "*使用額:*\n${{actual_amount}} USD"
        },
        {
          "type": "mrkdwn",
          "text": "*予算上限:*\n${{limit_amount}} USD"
        },
        {
          "type": "mrkdwn",
          "text": "*使用率:*\n{{usage_percentage}}%"
        }
      ]
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "AWS Bedrock Cost Monitor | <!date^{{timestamp}}^{date_short_pretty} at {time}|timestamp>"
        }
      ]
    }
  ]
}
```

---

## 🧪 テスト用JSONデータ

### 30%閾値テスト

```json
{
  "budgetName": "bedrock-monthly-budget",
  "thresholdPercentage": 30,
  "actualAmount": 60.0,
  "limitAmount": 200.0
}
```

### 50%閾値テスト

```json
{
  "budgetName": "bedrock-monthly-budget",
  "thresholdPercentage": 50,
  "actualAmount": 100.0,
  "limitAmount": 200.0
}
```

### 80%閾値テスト

```json
{
  "budgetName": "bedrock-monthly-budget",
  "thresholdPercentage": 80,
  "actualAmount": 160.0,
  "limitAmount": 200.0
}
```

### 100%閾値テスト（緊急）

```json
{
  "budgetName": "bedrock-monthly-budget",
  "thresholdPercentage": 100,
  "actualAmount": 200.0,
  "limitAmount": 200.0
}
```

---

## 📝 Slackワークフロー設定手順

### 方法1: Incoming Webhook（現在の設定）

1. Slack App設定 → Incoming Webhooks
2. Webhook URLをコピー
3. Lambda関数が自動的に整形して送信

**メリット**: 簡単、Lambda側で完全制御
**デメリット**: Slack側でカスタマイズ不可

### 方法2: Workflow Builder

1. Slack → Tools → Workflow Builder
2. 新規ワークフロー作成
3. トリガー: Webhook
4. 変数を定義:
   ```
   - budget_name (テキスト)
   - threshold (数値)
   - actual_amount (数値)
   - limit_amount (数値)
   ```
5. アクション: メッセージを送信
6. Webhook URLを取得
7. `terraform.tfvars` の `slack_webhook_url` を更新
8. `terraform apply` で反映

**メリット**: Slack側でメッセージをカスタマイズ可能
**デメリット**: 初期設定が少し複雑

---

## 🔍 Lambda関数の処理フロー（コード解説）

```python
def lambda_handler(event, context):
    # 1. SNSイベントからメッセージを取り出す
    sns_message_string = event['Records'][0]['Sns']['Message']

    # 2. JSON文字列をオブジェクトに変換
    sns_message = json.loads(sns_message_string)

    # 3. 必要な値を抽出
    budget_name = sns_message.get('budgetName', 'Unknown')
    threshold = float(sns_message.get('thresholdPercentage', 0))
    actual_amount = float(sns_message.get('actualAmount', 0))
    limit_amount = float(sns_message.get('limitAmount', 0))

    # 4. 使用率を計算
    usage_percentage = (actual_amount / limit_amount * 100) if limit_amount > 0 else 0

    # 5. 閾値に応じた色とアイコンを決定
    config = get_notification_config(threshold)  # 30% → 緑、100% → 赤

    # 6. Slack形式のメッセージを構築
    message = {
        'attachments': [{
            'color': config['color'],
            'title': f"{config['icon']} AWS Bedrock 予算アラート [{config['level']}]",
            'fields': [
                {'title': '閾値', 'value': f"{threshold:.0f}%", 'short': True},
                {'title': '現在の使用額', 'value': f"${actual_amount:.2f} USD", 'short': True},
                {'title': '予算上限', 'value': f"${limit_amount:.0f} USD", 'short': True},
                {'title': '使用率', 'value': f"{usage_percentage:.1f}%", 'short': True}
            ]
        }]
    }

    # 7. Slack Webhook URLにPOST送信
    response = http.request(
        'POST',
        webhook_url,
        body=json.dumps(message).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )

    return {'statusCode': 200}
```

---

## 🧩 Slack Block Kit Builder

より高度なメッセージをデザインしたい場合：

**Block Kit Builder**: https://app.slack.com/block-kit-builder

このツールで視覚的にメッセージをデザインし、生成されたJSONをLambda関数に反映できます。

---

## 🎯 よくある質問

### Q1: Webhook URLを変更したら？

```bash
# terraform.tfvarsを編集
vim terraform/terraform.tfvars

# 変更を適用
terraform apply
```

### Q2: メッセージの内容を変更したい

[modules/lambda/src/index.py](terraform/modules/lambda/src/index.py) の `send_slack_notification` 関数を編集してください。

### Q3: 変数が正しく渡されているか確認するには？

```bash
# Lambda実行ログを確認
aws logs tail /aws/lambda/bedrock-cost-notifier --region us-east-1 --follow
```

---

**💡 このガイドを使って、Slackワークフローに必要な変数を正しく設定してください！**
