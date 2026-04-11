aws-resource-monitor/
├── .github/                   # Cấu hình CI/CD (GitHub Actions)
│   └── workflows/
│       └── deploy.yml
├── infra/                     # Toàn bộ mã nguồn hạ tầng (Terraform)
│   ├── modules/               # Các thành phần tái sử dụng
│   │   ├── lambda/            # Module định nghĩa Lambda & IAM Role
│   │   ├── dynamodb/          # Module định nghĩa bảng dữ liệu
│   │   ├── eventbridge/       # Module định nghĩa Rules & Triggers
│   │   └── notifications/     # Module định nghĩa SNS/Slack Webhook
│   ├── environments/          # Biến số riêng cho từng môi trường
│   │   ├── dev.tfvars         # File biến cho môi trường Lab/Dev
│   │   └── prod.tfvars        # File biến cho môi trường Production
│   ├── main.tf                # File chính gọi các modules
│   ├── variables.tf           # Định nghĩa các biến đầu vào
│   ├── outputs.tf             # Các giá trị đầu ra (ARN, Endpoint)
│   └── provider.tf            # Cấu hình AWS Provider & Backend (S3)
├── src/                       # Mã nguồn của ứng dụng (Lambda Functions)
│   ├── handlers/              # Các file xử lý sự kiện chính
│   │   ├── processor.py       # Xử lý logic từ EventBridge
│   │   └── notifier.py        # Xử lý gửi tin nhắn sang Slack/Email
│   ├── layers/                # AWS Lambda Layers (Thư viện dùng chung)
│   │   └── common_lib/
│   ├── utils/                 # Các hàm bổ trợ (Helper functions)
│   │   ├── aws_client.py      # Khởi tạo boto3 clients
│   │   └── slack_helper.py    # Format tin nhắn Slack
│   └── requirements.txt       # Các thư viện Python cần thiết
├── tests/                     # Unit tests cho Lambda
│   ├── unit/
│   └── integration/
├── scripts/                   # Các script bổ trợ (Bash/Python)
│   └── setup_env.sh
├── docs/                      # Tài liệu hướng dẫn & Diagram
│   └── architecture.png
├── .gitignore
├── Makefile                   # Lệnh tắt để build/deploy nhanh
└── README.md                  # Hướng dẫn quan trọng nhất của dự án