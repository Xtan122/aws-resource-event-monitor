TÊN DỰ ÁN: HỆ THỐNG GIÁM SÁT VÀ QUẢN LÝ TRẠNG THÁI TÀI NGUYÊN AWS THỜI GIAN THỰC (SERVERLESS)
1. Tổng quan dự án (Executive Summary)
Trong môi trường điện toán đám mây hiện đại, việc kiểm soát biến động tài nguyên (tạo mới, thay đổi cấu hình, xóa bỏ) là thách thức lớn đối với quản trị viên. Dự án này xây dựng một hệ thống tự động hóa hoàn toàn nhằm theo dõi mọi biến động của các dịch vụ trên AWS (EC2, S3, RDS, VPC...) với độ trễ gần như bằng không (Near Real-time).

Hệ thống cung cấp cái nhìn tổng thể về "Trạng thái hiện tại" của toàn bộ hạ tầng thay vì chỉ dựa vào các file log thô, giúp tối ưu hóa bảo mật và kiểm soát chi phí vận hành.

2. Mục tiêu dự án
Tự động hóa 100%: Loại bỏ việc kiểm tra thủ công trên console.

Phản ứng tức thời: Nhận thông báo ngay khi có tài nguyên quan trọng bị thay đổi hoặc xóa bỏ.

Lưu trữ thông minh: Phân tách dữ liệu thành hai luồng: Trạng thái hiện tại (Hot data - DynamoDB) và Lịch sử chi tiết (Cold data - S3).

Tối ưu chi phí: Sử dụng kiến trúc Serverless (chỉ trả tiền khi có sự kiện phát sinh).

3. Công nghệ sử dụng (Technical Stack)
Dự án được xây dựng trên nền tảng AWS Serverless, bao gồm:

AWS CloudTrail: Nguồn dữ liệu ghi lại toàn bộ lịch sử API calls.

AWS Config: Giám sát và ghi lại các thay đổi cấu hình chi tiết của tài nguyên.

Amazon EventBridge: Xương sống điều phối sự kiện (Event-driven bus).

AWS Lambda (Python/Node.js): Xử lý logic, lọc và định dạng dữ liệu thô.

Amazon DynamoDB: Cơ sở dữ liệu NoSQL lưu trữ bảng trạng thái tài nguyên thời gian thực.

Amazon S3: Lưu trữ vĩnh viễn dữ liệu sự kiện để phục vụ Audit và báo cáo.

Amazon SNS: Hệ thống đẩy thông báo qua Email/Slack/SMS.

4. Mô tả Kiến trúc (Workflow)
Hệ thống vận hành theo quy trình khép kín:

Giai đoạn Thu thập: Bất kỳ hành động tạo/sửa/xóa nào từ User hoặc Script đều bị CloudTrail và AWS Config bắt lại.

Giai đoạn Lọc sự kiện: EventBridge sử dụng các Rules tùy chỉnh để chỉ lọc ra các hành động quan trọng (ví dụ: TerminateInstance, DeleteBucket).

Giai đoạn Xử lý: Lambda Function phân tích gói tin JSON từ sự kiện, trích xuất các thông tin: Resource ID, Service Type, Action (Create/Delete), Actor (User), Timestamp.

Giai đoạn Lưu trữ & Cảnh báo:

Cập nhật trạng thái mới nhất vào DynamoDB (Key-Value: ResourceID).

Lưu log thô vào S3 Partition theo ngày/tháng/năm.

Kích hoạt SNS gửi cảnh báo nếu phát hiện các hành động nguy hiểm hoặc không được phép.

5. Kết quả đạt được (Impact)
Tăng khả năng quan sát (Observability): Quản trị viên có thể truy vấn trạng thái của 1000+ tài nguyên chỉ trong vài mil giây qua DynamoDB.

Cải thiện bảo mật: Phát hiện ngay lập tức các hành vi tạo tài nguyên lạ hoặc xóa dữ liệu trái phép.

Hiệu quả kinh tế: Chi phí vận hành cực thấp (~$15/tháng cho quy mô 200 tài nguyên), rẻ hơn 90% so với các giải pháp giám sát của bên thứ ba.

Khả năng mở rộng: Dễ dàng tích hợp thêm các công cụ phân tích dữ liệu (như Amazon Athena) để chạy báo cáo hàng tháng từ dữ liệu lưu trữ trên S3.