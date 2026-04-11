# AWS Resource Event Monitor

[Tieng Viet](README.vi.md)

AWS Resource Event Monitor is a serverless monitoring pipeline on AWS that captures infrastructure events, normalizes them, stores latest resource state, archives raw/normalized payloads, and publishes high-severity alerts.

## What This Project Does

- Ingests events from EventBridge custom bus.
- Handles CloudTrail API events and AWS Config change events.
- Normalizes event payloads in Lambda.
- Writes latest resource state to DynamoDB.
- Archives raw and normalized payloads to S3 (date-based partition).
- Publishes high-severity alerts to SNS.

## Current Architecture

- Event source: EventBridge rules for CloudTrail and Config patterns.
- Compute: Lambda processor ([src/handlers/processor.py](src/handlers/processor.py)).
- State store: DynamoDB table (PK/SK model, latest state item).
- Archive store: S3 bucket with versioning, SSE, and public access block.
- Notifications: SNS topic for alert publishing.
- Infrastructure as Code: Terraform root + reusable modules in [infra](infra).

## Event Processing Flow

1. EventBridge routes matched events to Lambda.
2. Lambda detects event type (cloudtrail/config/unknown).
3. Lambda builds normalized schema v1 payload.
4. Lambda writes latest state to DynamoDB.
5. Lambda writes:
   - raw/year=YYYY/month=MM/day=DD/event_id=....json
   - normalized/year=YYYY/month=MM/day=DD/event_id=....json
6. Lambda calculates severity and publishes SNS for HIGH/CRITICAL events.

## Repository Layout

- [infra](infra): Terraform root and modules.
- [infra/modules/dynamodb](infra/modules/dynamodb): DynamoDB module.
- [infra/modules/lambda](infra/modules/lambda): Lambda + IAM + log group.
- [infra/modules/eventbridge](infra/modules/eventbridge): Event bus, rules, targets, invoke permissions.
- [infra/modules/notifications](infra/modules/notifications): SNS topic and optional email subscription.
- [src/handlers](src/handlers): Lambda handlers.
- [CHECKLIST_BAI_HOC.md](CHECKLIST_BAI_HOC.md): lesson checklist and progress.
- [CHAT_HISTORY.md](CHAT_HISTORY.md): mentoring/work history.

## Prerequisites

- Terraform >= 1.5 (recommended).
- AWS CLI configured for your target account.
- Python 3.12 (for Lambda runtime parity and local script checks).

## Deploy (Dev)

	cd infra
	terraform init
	terraform fmt -recursive
	terraform validate
	terraform plan -var-file=dev.tfvars
	terraform apply -var-file=dev.tfvars

## Useful Outputs

After apply, Terraform exposes:

- archive_bucket_name
- dynamodb_table_name
- dynamodb_table_arn
- sns_topic_arn
- name_prefix

## End-to-End Test Guide

Use the runbook in [BAI25_E2E_TEST_BLOCK.md](BAI25_E2E_TEST_BLOCK.md).

Important note:

- For manual put-events testing, use source custom.cloudtrail.
- Using source starting with aws. in custom events can be rejected by EventBridge.

## Destroy (Cost Control)

	cd infra
	terraform destroy -var-file=dev.tfvars

If S3 bucket deletion fails because the bucket is not empty, delete object versions/delete markers first, then run destroy again.

## Bilingual Documentation Recommendation

If you want both English and Vietnamese docs:

1. Keep [README.md](README.md) as the primary English entry point.
2. Keep full Vietnamese version in [README.vi.md](README.vi.md).
3. Add language switch links at the top of both files.
4. Keep technical sections mirrored to avoid drift:
   - Overview
   - Architecture
   - Deploy
   - Test
   - Destroy