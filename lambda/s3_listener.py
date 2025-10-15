import json

def handler(event, context):
    # You’ll see the S3 event records in CloudWatch Logs
    print("S3_EVENT:", json.dumps(event))
    return {"ok": True, "records": len(event.get("Records", []))}