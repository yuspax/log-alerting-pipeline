data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = var.public_key 
}

resource "aws_instance" "server" {
  count         = 2
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-cloudwatch-agent
    mkdir -p /var/log/app
    chmod 777 /var/log/app

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/app/application.log",
                "log_group_name": "/ec2/log-alerting/application",
                "log_stream_name": "{instance_id}",
                "retention_in_days": 7
              }
            ]
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

    cat > /usr/local/bin/log_gen.sh << 'SCRIPT'
    #!/bin/bash
    LEVELS=("ERROR" "CRITICAL" "WARNING" "INFO")
    MESSAGES=(
      "Database connection failed"
      "Service timeout after 30s"
      "Disk usage above 90 percent"
      "Memory allocation failed"
      "API rate limit exceeded"
    )

    while true; do
      LEVEL=$${LEVELS[$$RANDOM % $${#LEVELS[@]}]}
      MESSAGE=$${MESSAGES[$$RANDOM % $${#MESSAGES[@]}]}
      echo "$$(date '+%Y-%m-%d %H:%M:%S') $$LEVEL: $$MESSAGE" >> /var/log/app/application.log
      sleep 60
    done
    SCRIPT

    chmod +x /usr/local/bin/log_gen.sh

    cat > /etc/systemd/system/log-gen.service << 'SERVICE'
    [Unit]
    Description=Log Generator
    After=network.target

    [Service]
    Type=simple
    ExecStart=/bin/bash /usr/local/bin/log_gen.sh
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable log-gen
    systemctl start log-gen
  EOF
  )

  tags = {
    Name = "${var.project_name}-${var.environment}-server-${count.index + 1}"
  }
}