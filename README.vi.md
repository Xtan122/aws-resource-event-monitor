# AWS Resource Event Monitor

[English](README.md)

AWS Resource Event Monitor là một pipeline giám sát sự kiện hạ tầng theo hướng serverless trên AWS: nhận sự kiện, chuẩn hóa dữ liệu, lưu state mới nhất, lưu archive và gửi cảnh báo.

## Dự án này làm gì

- Nhận sự kiện từ EventBridge custom bus.
- Xử lý sự kiện CloudTrail API và AWS Config change.
- Chuẩn hóa payload trong Lambda.
- Ghi state mới nhất vào DynamoDB.
- Lưu raw/normalized payload vào S3 theo partition ngày.
- Gửi cảnh báo mức độ cao qua SNS.

## Kiến trúc hiện tại

- Event source: EventBridge rules cho CloudTrail và Config.
- Compute: Lambda processor ([src/handlers/processor.py](src/handlers/processor.py)).
- State store: DynamoDB (model PK/SK, item STATE#LATEST).
- Archive store: S3 có versioning, SSE, block public access.
- Notification: SNS topic để publish alert.
- IaC: Terraform root + modules trong [infra](infra).

## Luồng xử lý

1. EventBridge route event vào Lambda.
2. Lambda detect event type (cloudtrail/config/unknown).
3. Lambda build normalized payload schema v1.
4. Lambda ghi state vào DynamoDB.
5. Lambda lưu:
   - raw/year=YYYY/month=MM/day=DD/event_id=....json
   - normalized/year=YYYY/month=MM/day=DD/event_id=....json
6. Lambda tính severity và publish SNS cho HIGH/CRITICAL.

## Cấu trúc thư mục

- [infra](infra): Terraform root và module.
- [infra/modules/dynamodb](infra/modules/dynamodb): module DynamoDB.
- [infra/modules/lambda](infra/modules/lambda): module Lambda + IAM + log group.
- [infra/modules/eventbridge](infra/modules/eventbridge): event bus, rules, targets, permissions.
- [infra/modules/notifications](infra/modules/notifications): SNS topic và email subscription tùy chọn.
- [src/handlers](src/handlers): source Lambda handlers.
- [CHECKLIST_BAI_HOC.md](CHECKLIST_BAI_HOC.md): checklist bài học.
- [CHAT_HISTORY.md](CHAT_HISTORY.md): lịch sử mentoring/làm việc.

## Yêu cầu trước khi chạy

- Terraform >= 1.5 (khuyến nghị).
- AWS CLI đã cấu hình account.
- Python 3.12 (để đồng bộ với runtime Lambda).

## Deploy môi trường dev

    cd infra
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan -var-file=dev.tfvars
    terraform apply -var-file=dev.tfvars

## Output quan trọng

Sau khi apply, Terraform trả ra:

- archive_bucket_name
- dynamodb_table_name
- dynamodb_table_arn
- sns_topic_arn
- name_prefix

## Hướng dẫn test end-to-end

Xem runbook tại [BAI25_E2E_TEST_BLOCK.md](BAI25_E2E_TEST_BLOCK.md).

Lưu ý:

- Khi test put-events thủ công, dùng source custom.cloudtrail.
- Custom event có source bắt đầu bằng aws. có thể bị EventBridge từ chối.

## Destroy để tiết kiệm chi phí

    cd infra
    terraform destroy -var-file=dev.tfvars

Nếu bucket S3 không xóa được vì còn dữ liệu, cần xóa object versions/delete markers trước rồi destroy lại.

## Gợi ý mô tả song ngữ EN/VI

1. Dùng [README.md](README.md) làm bản chính tiếng Anh.
2. Dùng [README.vi.md](README.vi.md) cho bản tiếng Việt đầy đủ.
3. Đặt language switch link ở đầu 2 file.
4. Giữ các mục kỹ thuật đồng bộ để tránh lệch thông tin:
   - Overview
   - Architecture
   - Deploy
   - Test
   - Destroy