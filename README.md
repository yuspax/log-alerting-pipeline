# AWS Log Alerting Pipeline

Event-driven pipeline that automatically detects errors in CloudWatch logs and delivers real-time alerts to Slack via Lambda. Fully automated with Terraform and GitHub Actions.

---

## Architecture

```text
EC2 Instance 1 ──┐
                 ├──► CloudWatch Agent ──► Log Group
EC2 Instance 2 ──┘
                          │
                          ▼
                    Metric Filter (ERROR, CRITICAL)
                          │
                          ▼
                    CloudWatch Alarm
                          │
                          ▼
                    SNS Topic
                          │
                          ▼
                    Lambda (Python 3.12)
                          │
                          ▼
                    Slack Alert ERROR detected on server
```

---

## Tech Stack

| Category        | Tool                          |
|-----------------|-------------------------------|
| Cloud           | AWS (EC2, CloudWatch, Lambda, SNS, Secrets Manager, IAM) |
| IaC             | Terraform (S3 Backend, DynamoDB Locking) |
| CI/CD           | GitHub Actions                |
| Language        | Python 3.12 (Boto3, urllib)   |
| Alerting        | Slack Incoming Webhooks       |
| Region          | eu-central-1 (Frankfurt)      |

---

## Project Structure

```text
log-alerting-pipeline/
├── .github/workflows/
│   └── ci-cd.yml          # Lint → Plan → Apply pipeline
├── lambda/
│   └── handler.py         # Slack alert logic
├── terraform/
│   ├── main.tf            # Provider and backend config
│   ├── networking.tf      # VPC, subnet, security groups
│   ├── compute.tf         # EC2, IAM, CloudWatch Agent
│   ├── monitoring.tf      # Log Group, Metric Filter, Alarm
│   ├── alerting.tf        # SNS, Lambda, Secrets Manager
│   ├── variables.tf       # Input variables
│   └── outputs.tf         # IPs, ARNs
├── scripts/
│   └── log_gen.sh         # Error generator script (used in user_data)
└── README.md
```

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.10.0
- Slack Incoming Webhook URL

---

## How to Run

### 1. Clone the repository
```bash
git clone [https://github.com/yuspax/log-alerting-pipeline](https://github.com/yuspax/log-alerting-pipeline)
cd log-alerting-pipeline
```

### 2. Create S3 backend and DynamoDB lock table
```bash
aws s3api create-bucket \
  --bucket aws-log-alerting-tfstate \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket aws-log-alerting-tfstate \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

### 3. Deploy infrastructure
```bash
cd terraform
terraform init
terraform apply -var="slack_webhook_url=YOUR_SLACK_WEBHOOK_URL"
```

### 4. Verify deployment
```bash
terraform output
```
You will see EC2 public IPs, SNS topic ARN, and Lambda function name.

---

## CI/CD Pipeline

| Trigger       | Jobs             | Description                        |
|---------------|------------------|------------------------------------|
| Pull Request  | lint + plan      | Validates formatting and previews changes |
| Merge to main | lint + apply     | Deploys infrastructure automatically |

### Required GitHub Secrets

| Secret                  | Description              |
|-------------------------|--------------------------|
| `AWS_ACCESS_KEY_ID`     | AWS access key           |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key           |
| `SLACK_WEBHOOK_URL`     | Slack incoming webhook   |

---

## Testing the Pipeline

### 1. Automated Log Generation
The EC2 instances are provisioned with a custom `systemd` service (`log-gen.service`) via `user_data`. This script automatically generates random application logs (INFO, WARNING, ERROR, CRITICAL) every 60 seconds. You don't need to SSH into the instances.

### 2. Check CloudWatch Logs
Navigate to **AWS Console → CloudWatch → Log Groups → `/ec2/log-alerting/application`**. You will see the incoming log streams.

### 3. Receive Slack Alert
Wait 1-2 minutes. Once the script generates an `ERROR` or `CRITICAL` log, the metric filter will trigger the CloudWatch Alarm → SNS → Lambda → and you will receive a real-time notification in your Slack channel!

---

## Cost Estimate

| Service          | Cost                    |
|------------------|-------------------------|
| EC2 t3.micro x2  | ~$15/month
| Lambda           | Free tier (1M requests) |
| CloudWatch       | Free tier (5GB logs)    |
| Secrets Manager  | ~$0.40/secret/month     |
| **Total** | **~$15-16/month** |

> **Note:** Stop or destroy the EC2 instances when not in use to minimize costs.

---

## Destroy Infrastructure
```bash
cd terraform
terraform destroy -var="slack_webhook_url=YOUR_SLACK_WEBHOOK_URL"
```

---

## Why These Tools?

- **Terraform** — industry standard IaC, reproducible infrastructure
- **CloudWatch** — native AWS monitoring, no extra cost for basic usage
- **Lambda** — serverless, no server management, pay per invocation
- **Secrets Manager** — secure credential storage, no hardcoded tokens
- **GitHub Actions** — integrated CI/CD, no additional tools needed
