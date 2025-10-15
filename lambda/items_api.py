import os, json
import boto3
from decimal import Decimal

TABLE_NAME = os.getenv("TABLE_NAME", "shop-dev-items")
REGION = os.getenv("AWS_REGION", "us-east-1")

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)

def _dumps(obj):
    return json.dumps(obj, default=lambda x: float(x) if isinstance(x, Decimal) else x)

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
}

def handler(event, context):
    method = (event.get("httpMethod") or "").upper()
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    # CORS preflight
    if method == "OPTIONS":
        return {"statusCode": 200, "headers": CORS, "body": ""}

    try:
        if method == "GET" and item_id:
            # GET /items/{id}
            resp = table.get_item(Key={"id": item_id}, ConsistentRead=True)
            item = resp.get("Item")
            if not item:
                return {"statusCode": 404, "headers": {**CORS, "Content-Type": "application/json"},
                        "body": json.dumps({"error": f"Item {item_id} not found"})}
            return {"statusCode": 200, "headers": {**CORS, "Content-Type": "application/json"},
                    "body": _dumps({"item": item})}

        if method == "GET" and not item_id:
            # GET /items
            resp = table.scan(Limit=50)
            items = resp.get("Items", [])
            return {"statusCode": 200, "headers": {**CORS, "Content-Type": "application/json"},
                    "body": _dumps({"items": items})}

        if method == "POST":
            # POST /items
            data = json.loads(event.get("body") or "{}")
            for key in ("id", "name", "price"):
                if key not in data:
                    return {"statusCode": 400, "headers": {**CORS, "Content-Type": "application/json"},
                            "body": json.dumps({"error": f"Missing field: {key}"})}
            table.put_item(Item={"id": data["id"], "name": data["name"], "price": Decimal(str(data["price"]))})
            return {"statusCode": 201, "headers": {**CORS, "Content-Type": "application/json"},
                    "body": _dumps({"ok": True, "id": data["id"]})}

        if method == "PUT" and item_id:
            # PUT /items/{id}  (upsert using id from path)
            data = json.loads(event.get("body") or "{}")
            # allow partial body; keep simple by put_item (idempotent upsert)
            name = data.get("name")
            price = data.get("price")
            if name is None and price is None:
                return {"statusCode": 400, "headers": {**CORS, "Content-Type": "application/json"},
                        "body": json.dumps({"error": "Provide at least one of: name, price"})}
            # build item (existing attrs will be overwritten)
            item = {"id": item_id}
            if name is not None: item["name"] = name
            if price is not None: item["price"] = Decimal(str(price))
            table.put_item(Item=item)
            return {"statusCode": 200, "headers": {**CORS, "Content-Type": "application/json"},
                    "body": _dumps({"ok": True, "id": item_id})}

        if method == "DELETE" and item_id:
            # DELETE /items/{id}
            table.delete_item(Key={"id": item_id})
            return {"statusCode": 204, "headers": CORS, "body": ""}

        return {"statusCode": 405, "headers": {**CORS, "Content-Type": "application/json"},
                "body": json.dumps({"error": "Method not allowed"})}

    except Exception as e:
        print("ERROR:", repr(e))
        return {"statusCode": 500, "headers": {**CORS, "Content-Type": "application/json"},
                "body": json.dumps({"error": "Internal error"})}
