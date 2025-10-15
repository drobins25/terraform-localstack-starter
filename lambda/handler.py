import json

def handler(event, context):
    # Log the whole event so we can see SQS messages in CloudWatch Logs
    print("EVENT:", json.dumps(event))
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"ok": True, "event": event}),
    }