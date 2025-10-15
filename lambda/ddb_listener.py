import json

def handler(event, context):
    # For Debugging, add new/old image logs
    print("DDB_STREAM_EVENT:", json.dumps(event))
    # No special response is required for DynamoDB stream triggers
    return {"ok": True, "records": len(event.get("Records", []))}
