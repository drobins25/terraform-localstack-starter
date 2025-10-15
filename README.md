
Terraform + LocalStack Serverless Shop (Dev Sandbox)
====================================================

Spin up a realistic AWS-ish backend **locally** with LocalStack + Terraform. The default configuration requires Docker for running locally and does not require an AWS account. 

This project includes
- DynamoDB
- S3
- SQS
- SNS fan-out
- Lambda functions
- API Gateway
- EventBridge schedules 
- SSM Parameter Store
- Secrets Manager
- Python test suite (pytest + requests + boto3).

Contents
--------
1) Prerequisites
2) Quick Start (Docker, Terraform, AWS CLI alias)
3) Services & Resources
4) Endpoints (API Gateway)
5) Logs (CloudWatch Logs in LocalStack)
6) Tests (pytest + requests)
7) Makefile Shortcuts
8) Troubleshooting
9) Project Layout
10) Switching to real AWS later

1\. Prerequisites
----------------
- Docker & Docker Compose
- Terraform ≥ 1.5
- AWS CLI v2
- Python 3.11+ (3.13 OK) for tests
- (Optional) make

2\. Quick Start (from the project root):
--------------

### Start LocalStack
```
make up
```
### (or) 
```
cd localstack && docker compose up -d
```

### Provision infrastructure
```
make tf-apply
```

### (Optional) add a helpful alias for hitting LocalStack
 Put this in your `~/.zshrc` or `~/.bashrc` and open a new terminal:
```
alias awsls='aws --endpoint-url=http://localhost:4566'
```

### Verify
```
awsls dynamodb list-tables
awsls s3 ls
awsls sqs list-queues
```

### Tear down
```
make tf-destroy
make down
```

3\. Services & Resources
-----------------------
- **S3**
    - Bucket for app artifacts and an "uploads" bucket with S3 → Lambda notifications
- **DynamoDB**
    - Table: shop-dev-items (with Streams enabled for change events)
- **SQS**
    - Jobs queue + Dead Letter Queue (DLQ)
- **SNS**
    - Topic with subscription to the Jobs SQS queue (fan-out example)
- Lambda
    **-** `echo` _(test function; SQS → Lambda mapping)_
    - `items_api` _(CRUD for products; used by API Gateway)_
    - `ddb_listener` _(subscribed to DynamoDB Streams on the items table)_
    - `s3_listener` _(triggered by S3 object created events in the uploads bucket)_
- **API Gateway (REST)**
    - `/echo` _(GET)_
    - `/items` _(GET list, POST create)_
    - `/items/{id}` _(GET, PUT upsert, DELETE)_
- **EventBridge**
    - Scheduled rule `(rate(1 minute))` → SQS
    - On-demand rule that matches Source=demo.test → SQS (trigger via put-events)
- **Config & Secrets**
    - SSM Parameter: `/shop/dev/APP_ENV`
    - Secrets Manager: `shop/dev/DB_PASSWORD` (demo value, for local use)

4\. Endpoints (API Gateway) & Examples
-------------------------------------
### Get the item-by-id URL and derive the collection URL (zsh-safe)
```
ITEM_ID_URL=$(terraform -chdir=terraform output -raw items_api_url)
ITEMS_URL="${ITEM_ID_URL%/\{id\}}"
```

### Create
```
curl -s -X POST "$ITEMS_URL" -H 'Content-Type: application/json' \
-d '{"id":"p-1001","name":"Coffee Mug","price":12.99}'
```

### Get by id
```
curl -s "${ITEMS_URL}/p-1001"
```

### List
```
curl -s "$ITEMS_URL"
```

### Update (PUT upsert)
```
curl -s -X PUT "${ITEMS_URL}/p-1001" -H 'Content-Type: application/json' \
-d '{"price":14.0,"name":"Coffee Mug Plus"}'
```

### Delete
```
curl -s -X DELETE "${ITEMS_URL}/p-1001" -i | head -n 1   # 204
```
- should return: `204: No such file or directory`

### Echo function (direct Lambda test via CLI)
```
FN=$(terraform -chdir=terraform output -raw lambda_name)
awsls lambda invoke \
--function-name "$FN" \
--cli-binary-format raw-in-base64-out \
--payload '{"hello":"world"}' /tmp/out.json && cat /tmp/out.json
```

5\. Logs (CloudWatch Logs via LocalStack)
----------------------------------------
### Tail logs live for a function (e.g., items_api)
```
awsls logs describe-log-groups --query 'logGroups[].logGroupName' --output text | tr '\t' '\n'
awsls logs tail "/aws/lambda/shop-dev-items-api" --follow --format short
```

### Or latest stream snapshot
```
GROUP="/aws/lambda/shop-dev-items-api"
STREAM=$(awsls logs describe-log-streams --log-group-name "$GROUP" \
--order-by LastEventTime --descending --max-items 1 \
--query 'logStreams[0].logStreamName' --output text)
awsls logs get-log-events --log-group-name "$GROUP" --log-stream-name "$STREAM" \
--limit 50 --query 'events[].message' --output text
```

6\. Tests (pytest + requests + boto3)
------------------------------------
### One-time env
```
python3 -m venv tests/.venv && source tests/.venv/bin/activate
python -m pip install --upgrade pip
pip install -r tests/requirements.txt
```

### Run
```
pytest -q
```

7\. Makefile Shortcuts
---------------------
    | Command          | Description                                        |
    | ---------------- | -------------------------------------------------- |
    |  make up         | # start LocalStack (docker compose) + helpers      |
    |  make down       | # stop containers                                  |
    |  make tf-init    | # terraform init (upgrade provider pins if needed) |
    |  make tf-apply   | # terraform apply -auto-approve                    |
    |  make tf-plan    | # terraform plan                                   |
    |  make tf-destroy | # terraform destroy -auto-approve                  |
    |  make cli        | # shell into awscli helper container               |
    |  make test       | # run pytest (bootstraps tests/.venv on first run) |

8\. Troubleshooting
------------------
- CLI says `InvalidClientTokenId`
    - Always use the LocalStack endpoint; with the alias: `awsls`
    - Or add: 
      - ```
        --endpoint-url=http://localhost:4566
        ```

- zsh brace expansion breaks URLs like `/items/{id}`
    - Strip the token:
      - ```ITEMS_URL="${ITEM_ID_URL%/\{id\}}"```

- API Gateway deployment delete error (Active stage points to this deployment)
    - We set `create_before_destroy = true` on aws_api_gateway_deployment
      - If stuck: ```terraform apply -target=aws_api_gateway_deployment.api && terraform apply```

- Lambda invoke "Invalid base64"
    - On CLI v2 add: `--cli-binary-format raw-in-base64-out`

- No logs
    - Ensure LocalStack includes services: lambda, logs, cloudwatch, iam, sts; then tail via aws logs tail

- Nothing from EventBridge schedule yet
    - Give it ~60s, or test on-demand rule:
      - ```
        awsls events put-events --entries '[{"Source":"demo.test","DetailType":"check","Detail":"{\"msg\":\"hello\"}"}]'
        ```
9\. Project Layout
-----------------
```
.
├─ localstack/                # docker-compose (LocalStack + awscli helper)
├─ terraform/                 # IaC (aws_* resources, LocalStack endpoints)
│  ├─ apigw.tf                # API Gateway routes (/echo, /items, /items/{id})
│  ├─ events.tf               # EventBridge → SQS rules
│  ├─ lambda.tf               # echo Lambda + SQS event source mapping
│  ├─ items_api.tf            # items_api Lambda + REST resources/methods
│  ├─ ddb_streams.tf          # DynamoDB Streams → Lambda
│  ├─ s3_notify.tf            # S3 → Lambda notifications
│  ├─ sns.tf, sqs.tf, main.tf, variables.tf, locals.tf, outputs.tf, versions.tf
├─ lambda/
│  ├─ handler.py              # echo function
│  ├─ items_api.py            # CRUD for products
│  ├─ ddb_listener.py         # reacts to DDB stream changes
│  └─ s3_listener.py          # reacts to S3 uploads
└─ tests/
├─ conftest.py
├─ test_api_items.py
└─ requirements.txt
```

10\. Switching to real AWS later
-------------------------------
1. Replace the provider `aws` block to remove LocalStack endpoints and validation skips.
2. Swap backend "local" for an S3 backend with DynamoDB state locking.
3. Use AWS SSO (aws configure sso) or a named profile, then:
   - `terraform init -migrate-state`.
4. Update IAM least-privilege policies, KMS encryption, and API auth.
