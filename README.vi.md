# AWS Resource Event Monitor

[English](README.md)

## Tóm Tắt Điều Hành
AWS Resource Event Monitor là giải pháp giám sát hạ tầng AWS theo mô hình serverless, giúp thu thập sự kiện, chuẩn hóa dữ liệu, lưu trạng thái tài nguyên mới nhất, lưu trữ lịch sử sự kiện và gửi cảnh báo mức độ cao lên Slack.

Mục tiêu chính:

- Cung cấp khả năng quan sát gần thời gian thực về hành động vận hành và thay đổi trạng thái tài nguyên AWS trong phạm vi dịch vụ đã chọn.

## Sơ Đồ Kiến Trúc
![Sơ đồ kiến trúc AWS Resource Event Monitor](docs/aws-diagram.png)

## Phạm Vi Hiện Tại
Các dịch vụ nằm trong phạm vi MVP:

- EC2
- S3
- RDS
- Lambda
- IAM
- VPC
- ECS

Nguồn sự kiện:

- CloudTrail (hoạt động API)
- AWS Config (thay đổi cấu hình/trạng thái tài nguyên)

## Kiến Trúc Tổng Quan

- Ingestion: EventBridge nhận sự kiện từ CloudTrail và Config.
- Processing: Lambda phân tích và chuẩn hóa dữ liệu sự kiện theo schema thống nhất.
- Hot state: DynamoDB lưu trạng thái mới nhất cho từng tài nguyên (`pk/sk`, `STATE#LATEST`).
- Cold archive: S3 lưu payload raw và normalized theo partition ngày.
- Notification: SNS publish cảnh báo mức cao; Amazon Q Developer trong ứng dụng chat chuyển tiếp sang Slack.

## Luồng Xử Lý End-To-End

1. Một hành động trên dịch vụ AWS trong phạm vi giám sát xảy ra.
2. CloudTrail/Config phát sinh sự kiện.
3. EventBridge match rule và chuyển sự kiện sang Lambda.
4. Lambda:
   - Nhận diện loại sự kiện.
   - Tạo payload chuẩn hóa (`schema_version: v1`).
   - Ghi trạng thái mới nhất vào DynamoDB.
   - Ghi bản raw + normalized vào S3.
   - Tính severity.
5. Nếu severity là `HIGH` hoặc `CRITICAL`, Lambda publish SNS.
6. Amazon Q chat integration gửi cảnh báo vào kênh Slack đã cấu hình.

## Trạng Thái Dự Án (2026-04-13)

Đã hoàn thành và xác thực:

- Bộ module Terraform và wiring tại root.
- Luồng xử lý Lambda và lưu trữ dữ liệu.
- Routing EventBridge.
- Đường gửi cảnh báo SNS -> Amazon Q -> Slack.
- Bản vá lỗi quan trọng cho Slack delivery bằng custom notification schema hợp lệ.

Phần còn lại để đạt mức production-ready:

- Bổ sung DLQ cho Lambda.
- Bổ sung CloudWatch Alarm (errors, throttles).
- Thiết lập CI/CD (GitHub Actions, flow plan/apply có approve).
- Bổ sung unit test và integration test.
- Mở rộng bộ kiểm thử E2E (tối thiểu 5 kịch bản critical).

## Ghi Chú Tương Thích Khi Gửi Slack
Amazon Q chat integration không xử lý đúng với mọi payload SNS dạng text tự do trong luồng hiện tại.

Yêu cầu bắt buộc:

- Lambda cần publish đúng custom notification JSON schema được hỗ trợ.
- Nên bật logging cho chat integration để dễ điều tra sự cố.

Log group vận hành:

- `/aws/chatbot/aws-resource-event-monitor-dev-alerts-slack`

Dấu hiệu thành công trong log:

- `Successfully processed custom event`
- `Sending message to Slack`

Tham chiếu triển khai:

- Logic tạo payload thông báo: [src/handlers/processor.py](src/handlers/processor.py)
- Cấu hình integration Slack: [infra/main.tf](infra/main.tf)

## Cấu Trúc Thư Mục

- [infra](infra): Cấu hình Terraform root.
- [infra/modules/dynamodb](infra/modules/dynamodb): Module DynamoDB.
- [infra/modules/lambda](infra/modules/lambda): Module Lambda và IAM.
- [infra/modules/eventbridge](infra/modules/eventbridge): Event bus/rules/targets.
- [infra/modules/notifications](infra/modules/notifications): SNS topic và subscription.
- [src/handlers](src/handlers): Logic ứng dụng Lambda.
- [docs](docs): Tài nguyên sơ đồ và tài liệu hỗ trợ.

## Điều Kiện Tiên Quyết

- Terraform >= 1.5
- AWS CLI đã cấu hình đúng account/region
- Python 3.12

## Triển Khai Môi Trường Dev
```bash
cd infra
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Output Quan Trọng

- `archive_bucket_name`
- `dynamodb_table_name`
- `dynamodb_table_arn`
- `sns_topic_arn`
- `name_prefix`

## Runbook Vận Hành (Kiểm Tra Nhanh)

1. Tạo một sự kiện quản trị thực tế (ví dụ tạo/xóa S3 bucket).
2. Kiểm tra log Lambda có dấu hiệu xử lý và publish SNS.
3. Kiểm tra DynamoDB đã cập nhật `STATE#LATEST`.
4. Kiểm tra S3 có thêm object mới ở cả raw và normalized.
5. Kiểm tra log Amazon Q có dấu hiệu xử lý thành công và gửi Slack.

## Ràng Buộc Đã Biết

- Khi test custom EventBridge event, `source` không được bắt đầu bằng `aws.`.
- Tên resource phía Terraform provider vẫn dùng chuẩn `aws_chatbot_*`.
- Khi destroy S3 bucket có versioning, cần dọn object versions trước.

## Hủy Hạ Tầng (Tiết Kiệm Chi Phí)
```bash
cd infra
terraform destroy -var-file=dev.tfvars
```

## Ngôn Ngữ Tài Liệu

- English: [README.md](README.md)
- Tiếng Việt: [README.vi.md](README.vi.md)