import json
import os
import urllib3
import boto3
from datetime import datetime

http = urllib3.PoolManager()
ssm_client = boto3.client('ssm')

def get_slack_webhook_url():
    """Retrieve Slack Webhook URL from SSM Parameter Store"""
    try:
        parameter_name = os.environ['SLACK_WEBHOOK_PARAMETER']
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=True
        )
        return response['Parameter']['Value']
    except Exception as e:
        print(f"ERROR: Failed to retrieve Slack webhook URL from SSM: {str(e)}")
        raise

def get_notification_config(threshold):
    """Get notification color and icon based on threshold"""
    if threshold >= 100:
        return {
            'color': '#FF0000',  # Red
            'icon': '🚨',
            'level': '緊急'
        }
    elif threshold >= 80:
        return {
            'color': '#FF8C00',  # Orange
            'icon': '⚠️',
            'level': '警告'
        }
    elif threshold >= 50:
        return {
            'color': '#FFD700',  # Yellow
            'icon': '⚠️',
            'level': '注意'
        }
    else:
        return {
            'color': '#36A64F',  # Blue/Green
            'icon': '🔵',
            'level': '情報'
        }

def parse_sns_message(event):
    """Parse SNS message to extract budget information"""
    try:
        # SNS message is in the Records array
        sns_message = json.loads(event['Records'][0]['Sns']['Message'])

        # AWS Budgets notification format
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
    except Exception as e:
        print(f"ERROR: Failed to parse SNS message: {str(e)}")
        print(f"Event: {json.dumps(event)}")
        raise

def send_slack_notification(webhook_url, budget_info):
    """Send formatted notification to Slack"""
    config = get_notification_config(budget_info['threshold'])

    # Build Slack message
    message = {
        'attachments': [
            {
                'color': config['color'],
                'title': f"{config['icon']} AWS Bedrock 予算アラート [{config['level']}]",
                'fields': [
                    {
                        'title': '閾値',
                        'value': f"{budget_info['threshold']:.0f}%",
                        'short': True
                    },
                    {
                        'title': '現在の使用額',
                        'value': f"${budget_info['actual_amount']:.2f} USD",
                        'short': True
                    },
                    {
                        'title': '予算上限',
                        'value': f"${budget_info['limit_amount']:.0f} USD",
                        'short': True
                    },
                    {
                        'title': '使用率',
                        'value': f"{budget_info['usage_percentage']:.1f}%",
                        'short': True
                    }
                ],
                'footer': 'AWS Bedrock Cost Monitor',
                'ts': int(datetime.now().timestamp())
            }
        ]
    }

    try:
        encoded_message = json.dumps(message).encode('utf-8')
        response = http.request(
            'POST',
            webhook_url,
            body=encoded_message,
            headers={'Content-Type': 'application/json'}
        )

        if response.status != 200:
            print(f"ERROR: Slack API returned status {response.status}: {response.data}")
            return False

        print(f"SUCCESS: Notification sent to Slack (threshold: {budget_info['threshold']}%)")
        return True

    except Exception as e:
        print(f"ERROR: Failed to send Slack notification: {str(e)}")
        raise

def lambda_handler(event, context):
    """Main Lambda handler function"""
    print(f"Received event: {json.dumps(event)}")

    try:
        # Get Slack Webhook URL from SSM
        webhook_url = get_slack_webhook_url()

        # Parse budget information from SNS message
        budget_info = parse_sns_message(event)

        # Send notification to Slack
        success = send_slack_notification(webhook_url, budget_info)

        return {
            'statusCode': 200 if success else 500,
            'body': json.dumps({
                'message': 'Notification sent successfully' if success else 'Failed to send notification'
            })
        }

    except Exception as e:
        print(f"ERROR: Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error: {str(e)}'
            })
        }
