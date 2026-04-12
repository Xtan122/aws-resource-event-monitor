# AWS Resource Event Monitor

[Tieng Viet](README.vi.md)

AWS Resource Event Monitor is a serverless monitoring pipeline on AWS that captures infrastructure events, normalizes them, stores latest resource state, archives raw/normalized payloads, and publishes high-severity alerts.

## Project Status (As Of 2026-04-13)

Completed:

- Infrastructure modules are deployed and validated (DynamoDB, Lambda, EventBridge, SNS, Slack integration).
- End-to-end flow is working for high-severity events:
	- EventBridge -> Lambda -> DynamoDB/S3 -> SNS -> Amazon Q Developer in chat applications -> Slack.
- Critical Slack delivery issue has been resolved by switching Lambda SNS payloads to supported custom notification schema.

Remaining (next milestones):

- B37: run and document at least 5 critical E2E scenarios.
- B27: add DLQ for Lambda.
- B28: add CloudWatch alarms (errors, throttles).
- B29: set up CI/CD (GitHub Actions, plan/apply workflow with approval).
- B30: add unit and integration tests.

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
- Notifications: SNS topic with Amazon Q Developer in chat applications (formerly AWS Chatbot) to deliver alerts to Slack.
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
7. Amazon Q Developer in chat applications forwards SNS alerts to Slack channel.

## Critical Slack Delivery Fix Reference

Background:

- Symptom: SNS publish succeeded but Slack channel did not show alert messages.
- Root cause: Amazon Q chat integration rejected plain SNS notification bodies with "Event received is not supported".

Fix implemented:

- Lambda now publishes Amazon Q/AWS Chatbot custom notification schema (JSON with version/source/id/content/metadata).
- Chat configuration logging level is set to INFO for easier delivery diagnostics.

Code references:

- Custom notification payload construction: [src/handlers/processor.py](src/handlers/processor.py)
- Amazon Q Slack channel configuration and logging level: [infra/main.tf](infra/main.tf)

Operational references:

- Amazon Q service logs for Slack delivery path: `/aws/chatbot/aws-resource-event-monitor-dev-alerts-slack`
- Typical success markers in logs:
	- `Successfully processed custom event`
	- `Sending message to Slack`

External references:

- Custom notifications announcement: https://aws.amazon.com/about-aws/whats-new/2023/09/custom-notifications-aws-chatbot/
- Chatbot (Amazon Q in chat applications) service compatibility notes: https://docs.aws.amazon.com/chatbot/latest/adminguide/related-services.html

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

Recommended production-like test sequence:

1. Trigger a real management event (for example create/delete an S3 bucket).
2. Verify Lambda logs contain state/archive markers and SNS publish marker.
3. Verify DynamoDB has updated STATE#LATEST item for the resource.
4. Verify S3 has new raw and normalized objects.
5. Verify Amazon Q chat log group contains:
	- `Successfully processed custom event`
	- `Sending message to Slack`

Important note:

- For manual put-events testing, use source custom.cloudtrail.
- Using source starting with aws. in custom events can be rejected by EventBridge.
- Configure Amazon Q Developer in chat applications (formerly AWS Chatbot) to subscribe to the deployed SNS topic before running Slack alert tests.

Naming note:

- In Terraform, AWS provider resources still use names like aws_chatbot_slack_channel_configuration.

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