# AWS Resource Event Monitor

[English](README.md)

AWS Resource Event Monitor là một pipeline giám sát sự kiện hạ tầng theo hướng serverless trên AWS: nhận sự kiện, chuẩn hóa dữ liệu, lưu state mới nhất, lưu archive và gửi cảnh báo.

## Trang thai du an (cap nhat den 2026-04-13)

Da hoan thanh:

- Da trien khai va validate day du cac module ha tang (DynamoDB, Lambda, EventBridge, SNS, Slack integration).
- Luong E2E cho su kien muc do cao da hoat dong:
    - EventBridge -> Lambda -> DynamoDB/S3 -> SNS -> Amazon Q Developer trong ung dung chat -> Slack.
- Da fix loi quan trong khong hien thi Slack bang cach doi payload SNS cua Lambda sang custom notification schema duoc ho tro.

Con lai (cac cot moc tiep theo):

- Bai 37: chay va luu bang chung toi thieu 5 kich ban E2E critical.
- Bai 27: bo sung DLQ cho Lambda.
- Bai 28: bo sung CloudWatch Alarm (errors, throttles).
- Bai 29: thiet lap CI/CD (GitHub Actions, workflow plan/apply co approve).
- Bai 30: bo sung unit test va integration test.

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
- Notification: SNS topic ket hop Amazon Q Developer trong ung dung chat (ten cu: AWS Chatbot) de day canh bao sang Slack.
- IaC: Terraform root + modules trong [infra](infra).

## Luồng xử lý

1. EventBridge route event vào Lambda.
2. Lambda detect event type (cloudtrail/config/unknown).
3. Lambda build normalized payload schema v1.
4. Lambda ghi state vào DynamoDB.
5. Lambda lưu:
   - raw/year=YYYY/month=MM/day=DD/event_id=....json
   - normalized/year=YYYY/month=MM/day=DD/event_id=....json
6. Lambda tinh severity va publish SNS cho HIGH/CRITICAL.
7. Amazon Q Developer trong ung dung chat nhan tu SNS va day canh bao len kenh Slack.

## Reference quan trong cho loi gui Slack

Boi canh:

- Trieu chung: SNS publish thanh cong nhung Slack khong hien thi canh bao.
- Nguyen nhan goc: Amazon Q chat integration tu choi message body SNS dang plain text, log bao "Event received is not supported".

Ban fix da ap dung:

- Lambda da publish theo custom notification schema duoc ho tro boi Amazon Q/AWS Chatbot (JSON gom version/source/id/content/metadata).
- Logging level cua cau hinh chat da dat INFO de debug delivery de hon.

Code reference:

- Noi tao custom notification payload: [src/handlers/processor.py](src/handlers/processor.py)
- Cau hinh kenh Slack Amazon Q va logging level: [infra/main.tf](infra/main.tf)

Van hanh reference:

- Log group theo doi duong gui Slack: `/aws/chatbot/aws-resource-event-monitor-dev-alerts-slack`
- Dau hieu thanh cong thuong gap trong log:
    - `Successfully processed custom event`
    - `Sending message to Slack`

Tai lieu tham khao:

- Thong bao tinh nang custom notification: https://aws.amazon.com/about-aws/whats-new/2023/09/custom-notifications-aws-chatbot/
- Ghi chu tuong thich service Chatbot (Amazon Q trong chat applications): https://docs.aws.amazon.com/chatbot/latest/adminguide/related-services.html

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

Trinh tu test khuyen nghi gan voi production:

1. Tao su kien management thuc te (vi du tao/xoa S3 bucket).
2. Kiem tra log Lambda co dau hieu save state/archive va publish SNS.
3. Kiem tra DynamoDB da cap nhat item STATE#LATEST cua resource.
4. Kiem tra S3 da co object moi o nhanh raw va normalized.
5. Kiem tra log Amazon Q co dau hieu:
    - `Successfully processed custom event`
    - `Sending message to Slack`

Lưu ý:

- Khi test put-events thủ công, dùng source custom.cloudtrail.
- Custom event có source bắt đầu bằng aws. có thể bị EventBridge từ chối.
- Can cau hinh Amazon Q Developer trong ung dung chat (ten cu: AWS Chatbot) subscribe vao SNS topic truoc khi test canh bao Slack.

Luu y naming:

- Trong Terraform, provider AWS van dung ten resource dang aws_chatbot_*.

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