import json
import logging
import boto3
import urllib.request
import urllib.error
import base64
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_slack_webhook_url() -> str:
    secret_name = os.environ["SECRET_NAME"]
    region = os.environ["AWS_REGION_NAME"]

    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_name)

    return response["SecretString"]


def send_slack_alert(webhook_url: str, message: str) -> None:
    payload = json.dumps({
        "text": message
    }).encode("utf-8")

    request = urllib.request.Request(
        url=webhook_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(request) as response:
            logger.info("Slack response status: %s", response.status)
    except urllib.error.HTTPError as e:
        logger.error("Slack HTTP error: %s %s", e.code, e.reason)
        raise
    except urllib.error.URLError as e:
        logger.error("Slack URL error: %s", e.reason)
        raise


def parse_sns_message(event: dict) -> str:
    record = event["Records"][0]
    sns_message = json.loads(record["Sns"]["Message"])

    alarm_name = sns_message.get("AlarmName", "Unknown Alarm")
    alarm_description = sns_message.get("AlarmDescription", "")
    new_state = sns_message.get("NewStateValue", "UNKNOWN")
    reason = sns_message.get("NewStateReason", "")
    region = sns_message.get("Region", "")

    return (
        f":rotating_light: *AWS Alert Triggered*\n"
        f"*Alarm:* {alarm_name}\n"
        f"*Description:* {alarm_description}\n"
        f"*State:* {new_state}\n"
        f"*Reason:* {reason}\n"
        f"*Region:* {region}"
    )


def lambda_handler(event: dict, context) -> dict:
    logger.info("Received event: %s", json.dumps(event))

    try:
        message = parse_sns_message(event)
        webhook_url = get_slack_webhook_url()
        send_slack_alert(webhook_url, message)

        logger.info("Alert sent to Slack successfully")
        return {"statusCode": 200, "body": "Alert sent"}

    except KeyError as e:
        logger.error("Missing key in event: %s", e)
        raise
    except Exception as e:
        logger.error("Unexpected error: %s", e)
        raise