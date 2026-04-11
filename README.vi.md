# AWS Resource Event Monitor

[English](README.md)

AWS Resource Event Monitor la mot pipeline giam sat su kien ha tang theo huong serverless tren AWS: nhan su kien, chuan hoa du lieu, luu state moi nhat, luu archive va gui canh bao.

## Du an nay lam gi

- Nhan su kien tu EventBridge custom bus.
- Xu ly su kien CloudTrail API va AWS Config change.
- Chuan hoa payload trong Lambda.
- Ghi state moi nhat vao DynamoDB.
- Luu raw/normalized payload vao S3 theo partition ngay.
- Gui canh bao muc do cao qua SNS.

## Kien truc hien tai

- Event source: EventBridge rules cho CloudTrail va Config.
- Compute: Lambda processor ([src/handlers/processor.py](src/handlers/processor.py)).
- State store: DynamoDB (model PK/SK, item STATE#LATEST).
- Archive store: S3 co versioning, SSE, block public access.
- Notification: SNS topic de publish alert.
- IaC: Terraform root + modules trong [infra](infra).

## Luong xu ly

1. EventBridge route event vao Lambda.
2. Lambda detect event type (cloudtrail/config/unknown).
3. Lambda build normalized payload schema v1.
4. Lambda ghi state vao DynamoDB.
5. Lambda luu:
   - raw/year=YYYY/month=MM/day=DD/event_id=....json
   - normalized/year=YYYY/month=MM/day=DD/event_id=....json
6. Lambda tinh severity va publish SNS cho HIGH/CRITICAL.

## Cau truc thu muc

- [infra](infra): Terraform root va module.
- [infra/modules/dynamodb](infra/modules/dynamodb): module DynamoDB.
- [infra/modules/lambda](infra/modules/lambda): module Lambda + IAM + log group.
- [infra/modules/eventbridge](infra/modules/eventbridge): event bus, rules, targets, permissions.
- [infra/modules/notifications](infra/modules/notifications): SNS topic va email subscription tuy chon.
- [src/handlers](src/handlers): source Lambda handlers.
- [CHECKLIST_BAI_HOC.md](CHECKLIST_BAI_HOC.md): checklist bai hoc.
- [CHAT_HISTORY.md](CHAT_HISTORY.md): lich su mentoring/lam viec.

## Yeu cau truoc khi chay

- Terraform >= 1.5 (khuyen nghi).
- AWS CLI da cau hinh account.
- Python 3.12 (de dong bo voi runtime Lambda).

## Deploy moi truong dev

    cd infra
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan -var-file=dev.tfvars
    terraform apply -var-file=dev.tfvars

## Output quan trong

Sau khi apply, Terraform tra ra:

- archive_bucket_name
- dynamodb_table_name
- dynamodb_table_arn
- sns_topic_arn
- name_prefix

## Huong dan test end-to-end

Xem runbook tai [BAI25_E2E_TEST_BLOCK.md](BAI25_E2E_TEST_BLOCK.md).

Luu y:

- Khi test put-events thu cong, dung source custom.cloudtrail.
- Custom event co source bat dau bang aws. co the bi EventBridge tu choi.

## Destroy de tiet kiem chi phi

    cd infra
    terraform destroy -var-file=dev.tfvars

Neu bucket S3 khong xoa duoc vi con du lieu, can xoa object versions/delete markers truoc roi destroy lai.

## Goi y mo ta song ngu EN/VI

1. Dung [README.md](README.md) lam ban chinh tieng Anh.
2. Dung [README.vi.md](README.vi.md) cho ban tieng Viet day du.
3. Dat language switch link o dau 2 file.
4. Giu cac muc ky thuat dong bo de tranh lech thong tin:
   - Overview
   - Architecture
   - Deploy
   - Test
   - Destroy
