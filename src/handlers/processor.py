import os
import json
from datetime import datetime, timezone
import logging
import boto3
from botocore.exceptions import ClientError
import uuid


logger = logging.getLogger()
logger.setLevel(logging.INFO)



def lambda_handler(event, context):
    try: 
        event_type = detect_event_type(event)

        if event_type == "cloudtrail":
            parsed_event = parse_cloudtrail(event)
        elif event_type == "config":
            parsed_event = parse_config(event)
        else:
            parsed_event = {
                "event_type": "unknown",
                "service": "unknown",
                "action": "unknown",
                "resource_id": "unknown",
                "actor": "unknown",
                "event_time": event.get("time", "unknown"),
                "raw_event": event
            }
        payload = build_normalized_payload(event, parsed_event)

        save_to_dynamodb(payload)
        save_to_s3(payload, event)
        
        severity = calculate_severity(payload)
        if severity == "HIGH" or severity == "CRITICAL":
            publish_to_sns(payload)
        
        return {
            "statusCode": 200,
            "body": json.dumps(payload)
        }
    except Exception as e:
        print(f"System Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error', 
                'details': str(e)[:100]  
            })
        }

def detect_event_type(event):
    detail_type = event.get("detail-type", "")
    if "AWS API Call via CloudTrail" in detail_type:
        return "cloudtrail"
    elif "Configuration Item Change" in detail_type:
        return "config"
    return "unknown"
    
def parse_cloudtrail(event):
    detail = event.get("detail", {})
    resource = detail.get("resources", [])
    return {
        "event_type": "cloudtrail",
        "service": detail.get("eventSource", "").split(".")[0],
        "action": detail.get("eventName", "ConfigurationItemChange"),
        "resource_id": resource[0].get("ARN", "unknown") if resource else "unknown",
        "actor": detail.get("userIdentity", {}).get("arn", "unknown"),
        "event_time": detail.get("eventTime", ""),
        "raw_event": event
    }

def parse_config(event):
    detail = event.get("detail", {})
    config_item = detail.get("configurationItem", {})
    return {
        "event_type": "config",
        "service": detail.get("service", "aws.config"),
        "action": detail.get("messageType", "ConfigurationItemChange"),
        "resource_id": config_item.get("resourceId", "unknown"),
        "actor": "aws-config",
        "event_time": event.get("time", "") or config_item.get("configurationItemCaptureTime", ""),
        "raw_event": event
    }

def build_normalized_payload(event, parsed_event):
    return {
        "schema_version": "v1",
        "event_id": event.get("id", "unknown"),
        "event_type": parsed_event.get("event_type"),
        "source": event.get("source", "unknown"),
        "detail_type": event.get("detail-type", "unknown"),
        "service": parsed_event.get("service"),
        "action": parsed_event.get("action"),
        "resource_id": parsed_event.get("resource_id"),
        "actor": parsed_event.get("actor"),
        "event_time": parsed_event.get("event_time"),
        "ingested_at": datetime.now(timezone.utc).isoformat(),
        "raw_event": parsed_event.get("raw_event")
    }

def save_to_dynamodb(payload):
    table_name = os.environ.get('DYNAMODB_TABLE')

    if not table_name:
        is_local = os.environ.get('AWS_SAM_LOCAL') == 'true' or not os.environ.get('AWS_LAMBDA_FUNCTION_NAME')
        
        if is_local:
            print("Policy A: Local environment detected, skipping DynamoDB save.")
            return
        else:
            raise Exception("Environment variable DYNAMODB_TABLE is missing in production.")
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    resource_id = payload.get("resource_id", "unknown")

    item = {
        "pk": f"RESOURCE#{resource_id}",
        "sk": "STATE#LATEST",
        "service": payload.get("service", "unknown"),
        "action": payload.get("action", "unknown"),
        "actor": payload.get("actor", "unknown"),
        "event_time": payload.get("event_time", "unknown"),
        "event_type": payload.get("event_type", "unknown"),
        "source": payload.get("source", "unknown"),
        "detail_type": payload.get("detail_type", "unknown"),
        "updated_at": payload.get("ingested_at", "unknown")
    }
    
    table.put_item(Item=item)

def generate_s3_key(prefix, event_id):
    now = datetime.now(timezone.utc)
    year = now.strftime("%Y")
    month = now.strftime("%m")
    day = now.strftime("%d")

    if not event_id or event_id == "unknown":
        timestamp = int(now.timestamp())
        random_suffix = uuid.uuid4().hex[:6]
        event_id = f"{timestamp}_{random_suffix}"
    
    return f"{prefix}/year={year}/month={month}/day={day}/event_id={event_id}.json"

def save_to_s3(payload, event):
    s3_client = boto3.client('s3')
    ARCHIVE_BUCKET = os.environ.get('ARCHIVE_BUCKET')
    ENV = os.environ.get('ENV', 'dev')

    if not ARCHIVE_BUCKET:
        if ENV == 'dev':
            logger.info("ARCHIVE_BUCKET is not set, skipping S3 save in dev environment.")
            return
        else:
            logger.error("Environment variable ARCHIVE_BUCKET is missing in production.")
            raise Exception("Environment variable ARCHIVE_BUCKET is missing in production.")
    event_id = payload.get("event_id", "unknown")

    # save raw
    raw_key = generate_s3_key("raw", event_id)

    try:
        s3_client.put_object(
            Bucket=ARCHIVE_BUCKET,
            Key=raw_key,
            Body=json.dumps(event, ensure_ascii=False),
            ContentType='application/json'
        )
        logger.info(f"Raw event saved to S3: s3://{ARCHIVE_BUCKET}/{raw_key}")
    except ClientError as e:
        logger.error(f"Failed to save raw event to S3: {str(e)}")
        raise e
    
    # save normalized
    normalized_key = generate_s3_key("normalized", event_id)
    try:
        s3_client.put_object(
            Bucket=ARCHIVE_BUCKET,  
            Key=normalized_key,
            Body=json.dumps(payload, ensure_ascii=False),
            ContentType='application/json'
        )
        logger.info(f"Normalized event saved to S3: s3://{ARCHIVE_BUCKET}/{normalized_key}")
    except ClientError as e:
        logger.error(f"Failed to save normalized event to S3: {str(e)}")
        raise e 
    

def calculate_severity(payload):
    action = payload.get("action", "").lower()
    service = payload.get("service", "").lower()

    critical_actions = ["delete", "remove", 
                        "terminate", "stop", 
                        "drop", "remove", "unauthorize"]
    
    if any(critical in action for critical in critical_actions):
        return "HIGH"
    
    if service in ["iam", "kms", "cloudtrail"]:
        return "HIGH"
    
    return "LOW"


def publish_to_sns(payload):
    sns_client = boto3.client('sns')
    topic_arn = os.environ.get('SNS_TOPIC_ARN')

    if not topic_arn:
        if os.environ.get('AWS_SAM_LOCAL') == 'true' or not os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
            logger.info("SNS_TOPIC_ARN is not set, skipping SNS publish in local environment.")
            return
        else:
            logger.error("Environment variable SNS_TOPIC_ARN is missing in production.")
            raise Exception("Environment variable SNS_TOPIC_ARN is missing in production.")

    else:
        severity = calculate_severity(payload)
        event_id = payload.get("event_id", "unknown")
        service = payload.get("service", "unknown")
        action = payload.get("action", "unknown")
        actor = payload.get("actor", "unknown")
        resource_id = payload.get("resource_id", "unknown")
        event_time = payload.get("event_time", "unknown")

        custom_notification = {
            "version": "1.0",
            "source": "custom",
            "id": str(event_id),
            "content": {
                "textType": "client-markdown",
                "title": f"[{severity}] {service}:{action}",
                "description": (
                    f"*Severity:* {severity}\n"
                    f"*Service:* {service}\n"
                    f"*Action:* {action}\n"
                    f"*Resource:* {resource_id}\n"
                    f"*Actor:* {actor}\n"
                    f"*Event Time:* {event_time}"
                )
            },
            "metadata": {
                "summary": f"{severity} event for {service}",
                "eventType": "monitoring"
            }
        }

        try:
            sns_client.publish(
                TopicArn=topic_arn,
                Message=json.dumps(custom_notification, ensure_ascii=False)
            )
            logger.info(f"Event published to SNS topic: {topic_arn}")
        except ClientError as e:
            logger.error(f"Failed to publish event to SNS: {str(e)}")
            raise e
        
