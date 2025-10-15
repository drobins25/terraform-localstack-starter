
# ---- Config ----
COMPOSE := docker compose -f localstack/docker-compose.yml
TF_DIR  := terraform
TESTS   := tests

# ---- Phony targets ----
.PHONY: up down restart logs cli cli-host tf-init tf-apply tf-destroy tf-plan test clean

# Start LocalStack + helpers
up:
	$(COMPOSE) up -d

# Stop everything
down:
	$(COMPOSE) down

# Restart LocalStack (quick)
restart: down up

# Tail LocalStack logs
logs:
	$(COMPOSE) logs -f localstack

# Open a shell in the awscli container (endpoint: http://localhost:4566)
cli:
	$(COMPOSE) exec awscli sh

# (Optional) Run awscli on the host with dummy creds for a single command
# Usage: make cli-host CMD='aws --endpoint-url=http://localhost:4566 sqs list-queues'
cli-host:
	@if [ -z "$$CMD" ]; then echo "Usage: make cli-host CMD='aws ...'"; exit 1; fi
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 $$CMD

# Terraform helpers
tf-init:
	cd $(TF_DIR) && terraform init -upgrade

tf-plan:
	cd $(TF_DIR) && terraform plan

tf-apply:
	cd $(TF_DIR) && terraform apply -auto-approve

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

# Python tests (pytest + boto3). Assumes you've set up a venv under tests/.venv
test:
	@if [ ! -d "$(TESTS)/.venv" ]; then echo "Creating test venv..."; \
		python3 -m venv $(TESTS)/.venv && . $(TESTS)/.venv/bin/activate && \
		python -m pip install --upgrade pip setuptools wheel && \
		pip install -r $(TESTS)/requirements.txt ; \
	else . $(TESTS)/.venv/bin/activate && pytest -q ; fi

# Clean Terraform local state & plan artifacts (safe for local practice)
clean:
	rm -f $(TF_DIR)/plan.bin $(TF_DIR)/plan.json
	find . -name ".terraform" -type d -prune -exec rm -rf {} +
	find . -name ".terraform.lock.hcl" -delete
