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

## Trạng Thái Dự Án (2026-04-14)

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

## Baseline Chi Phí (Dev, us-east-1)

Mô hình chi phí chi tiết: [cost_calculate.md](cost_calculate.md)

Ước tính theo workload hiện tại (~200 tài nguyên, ~15.000 sự kiện/tháng):

| Dịch vụ | Ước tính chi phí/tháng | Thành phần chi phí chính |
|---|---:|---|
| AWS Config | ~$3.00 | Số lượng configuration items |
| Amazon S3 | ~$0.15 | PUT requests và lưu trữ object |
| Amazon SNS | ~$0.03 | Số lượng email gửi đi |
| Amazon EventBridge | ~$0.02 | Lưu lượng custom event bus |
| Amazon CloudWatch Logs | ~$0.04 | Log từ Lambda và EventBridge |
| AWS Lambda | ~$0.00 | Được free tier bao phủ ở mức tải hiện tại |
| DynamoDB | ~$0.00 | Được free tier bao phủ ở mức tải hiện tại |
| CloudTrail | $0.00 | Baseline management events |
| Amazon Q / Chatbot | $0.00 | Baseline tích hợp chat |
| IAM | $0.00 | Không có phí dịch vụ trực tiếp |
| **Tổng** | **~$3.24/tháng** | **Baseline môi trường dev** |

Quy đổi theo năm cho dev: **~$38.88/năm**.

Ước tính production theo cùng mô hình: **~$17.82/tháng**.

Làm rõ phương pháp tính:

- Đây là ước tính theo kịch bản cho từng dịch vụ, không phải phép nhân trực tiếp từ tổng dev.
- Nhóm dịch vụ xử lý sự kiện được giả định tăng lưu lượng, còn AWS Config được giả định tăng số lượng tài nguyên giám sát.
- Tổng production được cộng từ từng giả định dịch vụ:
   - Lambda (0.07) + DynamoDB (0.40) + S3 (1.50) + EventBridge (0.15) + SNS (0.30) + CloudWatch Logs (0.40) + AWS Config (15.00) = **17.82 USD/tháng**.
- Bảng nguồn tham chiếu: mục Dev vs Production trong [cost_calculate.md](cost_calculate.md).

## Khuyến Nghị FinOps Và Quản Trị Chi Phí

- Xem AWS Config là rủi ro chi phí trọng yếu (chiếm tỷ trọng lớn nhất trong baseline hiện tại).
- Giới hạn phạm vi ghi nhận AWS Config theo nhóm tài nguyên cần thiết thay vì ghi nhận toàn bộ.
- Đặt logging EventBridge ở mức `ERROR` cho production; chỉ dùng `TRACE` trong giai đoạn điều tra sự cố.
- Thiết lập lifecycle policy cho S3 archive dài hạn (ví dụ chuyển Glacier sau 90 ngày).
- Thiết lập budget alarm và phát hiện bất thường chi phí cho Config, S3, CloudWatch Logs.
- Theo dõi KPI chi phí trong vận hành: chi phí trên 1.000 sự kiện và chi phí trên mỗi tài nguyên được giám sát.

## Chu Kỳ Rà Soát Chi Phí

- Cập nhật giả định chi phí theo tháng hoặc ngay sau khi có thay đổi kiến trúc lớn.
- Re-baseline khi bổ sung dịch vụ giám sát mới, thêm Config rules hoặc nguồn sự kiện lưu lượng cao.
- Giữ tham chiếu giá theo đúng khu vực triển khai (ước tính hiện tại áp dụng cho `us-east-1`).

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