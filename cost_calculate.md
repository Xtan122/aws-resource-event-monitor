# Tính Toán Chi Phí Hạ Tầng AWS
## Dự án: AWS Resource Event Monitor (Serverless)
> Môi trường: **dev** | Region: **us-east-1** | Cập nhật: 2026-04-14

---

## Giả định tính toán

| Thông số | Giá trị giả định |
|---|---|
| Số tài nguyên AWS được giám sát | ~200 resources |
| Số sự kiện CloudTrail/Config mỗi ngày | ~500 events/ngày |
| Số sự kiện mỗi tháng | ~15.000 events/tháng |
| Tỷ lệ sự kiện HIGH/CRITICAL (kích hoạt SNS) | ~10% = 1.500 events/tháng |
| Kích thước payload trung bình mỗi sự kiện | ~5 KB |
| Lambda memory | 256 MB (cấu hình mặc định trong `variables.tf`) |
| Lambda timeout | 30 giây (cấu hình mặc định) |
| Lambda thực thi trung bình | ~1 giây/invocation |
| Retention CloudWatch Logs | 14 ngày (cấu hình trong `lambda/main.tf`) |

---

## 1. AWS Lambda

**Cấu hình từ code:**
- Runtime: `python3.12`
- Memory: `256 MB`
- Timeout: `30s`
- Số lần gọi: ~15.000 invocations/tháng
- Thời gian thực thi trung bình: ~1.000ms

**Tính toán:**

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| Requests | 15.000 invocations × $0.0000002/request | $0.003 |
| Duration | 15.000 × 1s × 256MB/1024 = 3.750 GB-seconds × $0.0000166667/GB-s | $0.063 |
| **Free Tier** | 1M requests + 400.000 GB-s/tháng (miễn phí) | **-$0.066** |
| **Tổng Lambda** | | **~$0.00** |

> Free tier Lambda hoàn toàn bao phủ workload này. Chi phí thực tế = $0 trong năm đầu, sau đó ~$0.07/tháng.

---

## 2. Amazon DynamoDB

**Cấu hình từ code (`dynamodb/main.tf`):**
- Billing mode: `PAY_PER_REQUEST` (On-demand)
- 1 bảng chính với `pk` (RESOURCE#id) + `sk` (STATE#LATEST)
- 1 GSI: `gsi_service_event_time` (projection: ALL)

**Tính toán:**

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| Write Request Units (WRU) | 15.000 writes × $0.00000125/WRU | $0.019 |
| Read Request Units (RRU) | ~5.000 reads/tháng × $0.00000025/RRU | $0.001 |
| Storage | ~200 items × 1KB = 0.2 MB × $0.25/GB | ~$0.00 |
| GSI WRU | 15.000 × $0.00000125/WRU | $0.019 |
| **Free Tier** | 25 WCU + 25 RCU + 25GB storage (always free) | **-$0.039** |
| **Tổng DynamoDB** | | **~$0.00** |

> On-demand với workload nhỏ + free tier = thực tế $0. Nếu vượt free tier: ~$0.04/tháng.

---

## 3. Amazon S3 (Events Archive Bucket)

**Cấu hình từ code (`main.tf`):**
- Versioning: `Enabled`
- Encryption: `AES256` (SSE-S3)
- Public access: hoàn toàn blocked
- Lưu 2 bản/event: `raw/` + `normalized/`

**Tính toán:**

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| PUT requests | 15.000 events × 2 objects = 30.000 PUTs × $0.000005/PUT | $0.150 |
| Storage tháng 1 | 30.000 objects × 5KB = 150MB × $0.023/GB | $0.003 |
| Storage tích lũy 12 tháng | ~1.8GB × $0.023/GB | $0.041 |
| GET requests (audit/query) | ~1.000 GETs/tháng × $0.0000004/GET | ~$0.00 |
| Versioning overhead | ~20% thêm storage | $0.001 |
| **Free Tier** | 5GB storage + 20.000 GETs + 2.000 PUTs (12 tháng đầu) | **-$0.010** |
| **Tổng S3/tháng** | | **~$0.15** |

---

## 4. Amazon EventBridge

**Cấu hình từ code (`eventbridge/main.tf`):**
- 1 Custom Event Bus: `aws-resource-event-monitor-dev-event-bus`
- Logging: `FULL` / Level: `TRACE` (chi phí CloudWatch Logs)
- 4 Rules:
  - `default-forward-cloudtrail` (default bus)
  - `default-forward-config` (default bus)
  - `cloudtrail-critical-events` (custom bus)
  - `config-changes` (custom bus)

**Tính toán:**

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| Custom Event Bus events | 15.000 events × $0.000001/event | $0.015 |
| Default bus forwarding rules | 15.000 events × $0.000001/event | $0.015 |
| **Free Tier** | 14M events/tháng từ AWS services (miễn phí) | **-$0.015** |
| **Tổng EventBridge** | | **~$0.015** |

> Events từ CloudTrail/Config qua default bus miễn phí. Custom bus tính phí: ~$0.015/tháng.

---

## 5. Amazon SNS (Notifications)

**Cấu hình từ code (`notifications/main.tf`):**
- 1 SNS Topic: `aws-resource-event-monitor-dev-alerts`
- Protocol: Email (subscription)
- Chỉ publish khi severity = HIGH hoặc CRITICAL (~10% events)

**Tính toán:**

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| API Requests (Publish) | 1.500 publishes × $0.00000050/request | $0.001 |
| Email deliveries | 1.500 emails × $0.00002/email | $0.030 |
| **Free Tier** | 1M SNS requests/tháng (miễn phí) | **-$0.001** |
| **Tổng SNS** | | **~$0.030** |

---

## 6. Amazon CloudWatch Logs

**Cấu hình từ code:**
- Log group Lambda: `/aws/lambda/{function_name}` — retention 14 ngày
- Log group EventBridge: logging level `TRACE` (toàn bộ events)
- Log group Amazon Q/Chatbot: `/aws/chatbot/aws-resource-event-monitor-dev-alerts-slack`

**Tính toán:**

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| Lambda log ingestion | 15.000 invocations × ~2KB log/invocation = 30MB × $0.50/GB | $0.015 |
| EventBridge TRACE logs | 15.000 events × ~3KB = 45MB × $0.50/GB | $0.023 |
| Chatbot logs | ~1.500 events × 1KB = 1.5MB × $0.50/GB | $0.001 |
| Storage (14 ngày retention) | ~76MB × $0.03/GB | $0.002 |
| **Free Tier** | 5GB ingestion + 5GB storage/tháng (12 tháng đầu) | **-$0.041** |
| **Tổng CloudWatch Logs** | | **~$0.041** |

> **Lưu ý quan trọng:** EventBridge logging level `TRACE` ghi toàn bộ event detail — có thể tăng chi phí đáng kể nếu traffic lớn. Nên đổi sang `ERROR` ở production.

---

## 7. AWS CloudTrail

**Vai trò trong hệ thống:** Nguồn dữ liệu đầu vào (event source), không phải resource do Terraform quản lý trực tiếp.

| Hạng mục | Chi phí |
|---|---|
| Management events (1 trail miễn phí/region) | $0.00 |
| Data events (nếu bật) | $0.10/100.000 events — **không bật trong dự án này** |
| **Tổng CloudTrail** | **$0.00** |

---

## 8. AWS Config

**Vai trò trong hệ thống:** Nguồn dữ liệu thứ hai (configuration changes).

| Hạng mục | Công thức | Chi phí |
|---|---|---|
| Configuration items recorded | ~200 resources × 5 changes/tháng = 1.000 items × $0.003/item | $3.00 |
| **Free Tier** | Không có free tier cho Config | $0.00 |
| **Tổng AWS Config** | | **~$3.00** |

> AWS Config là dịch vụ **tốn chi phí nhất** trong hệ thống này. Chi phí tăng tuyến tính theo số lượng tài nguyên và tần suất thay đổi.

---

## 9. Amazon Q Developer / AWS Chatbot (Slack Integration)

**Cấu hình từ code (`main.tf`):**
- Resource: `aws_chatbot_slack_channel_configuration`
- IAM Role với `ReadOnlyAccess` policy
- Kết nối SNS → Slack channel

| Hạng mục | Chi phí |
|---|---|
| Amazon Q Developer in chat applications | $0.00 (miễn phí cho chat integration cơ bản) |
| IAM Role | $0.00 |
| **Tổng Chatbot/Amazon Q** | **$0.00** |

---

## 10. IAM (Identity and Access Management)

| Hạng mục | Chi phí |
|---|---|
| IAM Roles (Lambda role, EventBridge role, Chatbot role) | $0.00 |
| IAM Policies | $0.00 |
| **Tổng IAM** | **$0.00** |

---

## Tổng Hợp Chi Phí Toàn Bộ Hạ Tầng

### Môi trường Dev (us-east-1) — ~200 resources, ~15.000 events/tháng

| # | Dịch vụ | Chi phí/tháng | Ghi chú |
|---|---|---|---|
| 1 | AWS Lambda | ~$0.00 | Free tier bao phủ hoàn toàn |
| 2 | Amazon DynamoDB | ~$0.00 | Free tier bao phủ hoàn toàn |
| 3 | Amazon S3 | ~$0.15 | PUT requests + storage |
| 4 | Amazon EventBridge | ~$0.02 | Custom bus events |
| 5 | Amazon SNS | ~$0.03 | Email deliveries |
| 6 | Amazon CloudWatch Logs | ~$0.04 | Lambda + EventBridge TRACE logs |
| 7 | AWS CloudTrail | $0.00 | 1 trail miễn phí |
| 8 | AWS Config | ~$3.00 | Chi phí lớn nhất — per config item |
| 9 | Amazon Q / Chatbot | $0.00 | Miễn phí |
| 10 | IAM | $0.00 | Miễn phí |
| | **TỔNG CỘNG** | **~$3.24/tháng** | |
| | **TỔNG NĂM** | **~$38.88/năm** | |

---

## So Sánh Với Ước Tính Trong Tài Liệu Dự Án

| Nguồn | Chi phí ước tính |
|---|---|
| `tongquanduan.md` (tác giả dự án) | ~$15/tháng cho 200 tài nguyên |
| Tính toán chi tiết (file này) | ~$3.24/tháng |

> Chênh lệch do tài liệu gốc có thể tính thêm CloudTrail data events, Config rules, hoặc workload cao hơn. Với cấu hình hiện tại trong code, chi phí thực tế thấp hơn đáng kể.

---

## Phân Tích Chi Phí Theo Môi Trường

### Dev vs Production

| Dịch vụ | Dev/tháng | Prod/tháng (ước tính 10x traffic) |
|---|---|---|
| Lambda | $0.00 | ~$0.07 |
| DynamoDB | $0.00 | ~$0.40 |
| S3 | $0.15 | ~$1.50 |
| EventBridge | $0.02 | ~$0.15 |
| SNS | $0.03 | ~$0.30 |
| CloudWatch Logs | $0.04 | ~$0.40 |
| AWS Config | $3.00 | ~$15.00 (500 resources) |
| **Tổng** | **~$3.24** | **~$17.82** |

---

## Khuyến Nghị Tối Ưu Chi Phí

1. **AWS Config** — Chiếm ~93% tổng chi phí. Cân nhắc:
   - Chỉ record các resource types cần thiết (EC2, S3, RDS, IAM) thay vì all resources
   - Có thể tiết kiệm 40-60% chi phí Config

2. **EventBridge Logging** — Đang dùng `TRACE` level trong `eventbridge/main.tf`:
   ```hcl
   log_config {
     include_detail = "FULL"
     level          = "TRACE"  # ← Đổi thành "ERROR" ở production
   }
   ```
   Tiết kiệm ~$0.02/tháng ở dev, nhiều hơn ở production.

3. **S3 Lifecycle Policy** — Chưa có trong code hiện tại. Thêm lifecycle rule để:
   - Chuyển objects > 90 ngày sang S3 Glacier (~$0.004/GB thay vì $0.023/GB)
   - Tiết kiệm ~70% chi phí storage dài hạn

4. **Lambda Memory** — 256MB là hợp lý cho workload hiện tại. Không cần tối ưu thêm.

5. **DLQ (Dead Letter Queue)** — Đã được đề cập trong README là việc còn lại. Thêm SQS DLQ sẽ tốn thêm ~$0.01/tháng nhưng tăng độ tin cậy đáng kể.

---

*Giá AWS tham chiếu tại thời điểm tính toán (us-east-1, tháng 4/2026). Giá thực tế có thể thay đổi theo AWS pricing updates.*
