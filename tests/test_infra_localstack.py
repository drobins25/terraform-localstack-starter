import json
import boto3
from botocore.exceptions import ClientError

def test_s3_bucket_properties(s3_client, tf_outputs):
    bucket = tf_outputs["bucket_name"]["value"]

    # Bucket exists (HeadBucket)
    s3_client.head_bucket(Bucket=bucket)

    # Versioning is Enabled
    vr = s3_client.get_bucket_versioning(Bucket=bucket)
    assert vr.get("Status") == "Enabled"

    # Encryption is AES256
    enc = s3_client.get_bucket_encryption(Bucket=bucket)
    rules = enc["ServerSideEncryptionConfiguration"]["Rules"]
    algo = rules[0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"]
    assert algo == "AES256"

def test_s3_versioning_behaviour(s3_client, tf_outputs):
    bucket = tf_outputs["bucket_name"]["value"]
    key = "sample.txt"

    # Put first version
    put1 = s3_client.put_object(Bucket=bucket, Key=key, Body=b"hello")
    v1 = put1["VersionId"]

    # Put second version
    put2 = s3_client.put_object(Bucket=bucket, Key=key, Body=b"hello v2")
    v2 = put2["VersionId"]

    assert v1 != v2  # versioning actually producing distinct versions

    # Get a specific version
    obj_v1 = s3_client.get_object(Bucket=bucket, Key=key, VersionId=v1)
    assert obj_v1["Body"].read() == b"hello"

def test_dynamodb_crud(ddb_client, tf_outputs):
    table = tf_outputs["dynamodb_table"]["value"]

    # Create (PutItem)
    ddb_client.put_item(
        TableName=table,
        Item={
            "id": {"S": "p-3001"},
            "name": {"S": "Water Bottle"},
            "price": {"N": "14.50"},
            "inStock": {"BOOL": True},
        },
    )

    # Read (GetItem)
    get = ddb_client.get_item(TableName=table, Key={"id": {"S": "p-3001"}})
    assert "Item" in get
    assert get["Item"]["name"]["S"] == "Water Bottle"

    # Update (UpdateItem)
    upd = ddb_client.update_item(
        TableName=table,
        Key={"id": {"S": "p-3001"}},
        UpdateExpression="SET price = :p",
        ExpressionAttributeValues={":p": {"N": "12.00"}},
        ReturnValues="ALL_NEW",
    )
    assert upd["Attributes"]["price"]["N"] == "12.00"

    # Delete (DeleteItem)
    ddb_client.delete_item(TableName=table, Key={"id": {"S": "p-3001"}})
    gone = ddb_client.get_item(TableName=table, Key={"id": {"S": "p-3001"}})
    assert "Item" not in gone
