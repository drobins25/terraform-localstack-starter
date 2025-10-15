# tests/conftest.py
import json
import os
import subprocess
from pathlib import Path

import boto3
import pytest

# Defaults for LocalStack / dummy creds
LOCALSTACK_URL = os.getenv("LOCALSTACK_URL", "http://localhost:4566")
REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
DUMMY_KEY = os.getenv("AWS_ACCESS_KEY_ID", "test")
DUMMY_SECRET = os.getenv("AWS_SECRET_ACCESS_KEY", "test")


def _tf_output_json():
    """
    Load `terraform output -json` from the terraform directory.
    - Honors TF_DIR if set.
    - Otherwise, resolves ../terraform relative to THIS file (not CWD),
      so tests work no matter your IDE's working directory.
    """
    tf_dir_env = os.getenv("TF_DIR")
    if tf_dir_env:
        tf_dir = Path(tf_dir_env).expanduser().resolve()
    else:
        tf_dir = (Path(__file__).resolve().parents[1] / "terraform").resolve()

    out = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=tf_dir,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(out.stdout)


@pytest.fixture(scope="session")
def tf_outputs():
    try:
        return _tf_output_json()
    except Exception as e:
        pytest.skip(f"Terraform outputs not available ({e}); run `terraform apply` first.")


@pytest.fixture(scope="session")
def s3_client():
    return boto3.client(
        "s3",
        region_name=REGION,
        aws_access_key_id=DUMMY_KEY,
        aws_secret_access_key=DUMMY_SECRET,
        endpoint_url=LOCALSTACK_URL,
    )


@pytest.fixture(scope="session")
def ddb_client():
    return boto3.client(
        "dynamodb",
        region_name=REGION,
        aws_access_key_id=DUMMY_KEY,
        aws_secret_access_key=DUMMY_SECRET,
        endpoint_url=LOCALSTACK_URL,
    )
