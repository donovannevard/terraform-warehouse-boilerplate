# Self-managed Airflow on EC2 — only created when use_airflow = true and airflow_type = "ec2"
locals {
  use_ec2_airflow = var.use_airflow && local.airflow_type == "ec2"
}

# EC2 Instance
resource "aws_instance" "airflow" {
  count = local.use_ec2_airflow ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.environment == "development" ? "t3.micro" : var.airflow_ec2_instance_type
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.airflow_ec2[0].id]

  iam_instance_profile = aws_iam_instance_profile.airflow[0].name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data_airflow.sh", {
    airflow_admin_password = var.airflow_admin_password
  }))

  tags = merge(local.tags, {
    Name = "${local.project_name}-airflow-ec2"
  })
}

# AMI data source (latest Amazon Linux 2)
data "aws_ami" "amazon_linux_2" {
  count = local.use_ec2_airflow ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group for EC2 Airflow
resource "aws_security_group" "airflow_ec2" {
  count  = local.use_ec2_airflow ? 1 : 0
  name   = "${local.project_name}-airflow-ec2-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.airflow_alb[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# ALB for public HTTPS access to Airflow UI
resource "aws_lb" "airflow" {
  count = local.use_ec2_airflow ? 1 : 0

  name               = "${local.project_name}-airflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.airflow_alb[0].id]
  subnets            = module.vpc.public_subnets

  tags = local.tags
}

resource "aws_security_group" "airflow_alb" {
  count  = local.use_ec2_airflow ? 1 : 0
  name   = "${local.project_name}-airflow-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# ACM Certificate (free, auto-validated)
resource "aws_acm_certificate" "airflow" {
  count = local.use_ec2_airflow ? 1 : 0

  domain_name = "airflow.${var.project_name}.example.com"  # Client replaces with real domain
  validation_method = "DNS"

  tags = local.tags
}

# ALB Listener + Target Group
resource "aws_lb_target_group" "airflow" {
  count = local.use_ec2_airflow ? 1 : 0

  name     = "${local.project_name}-airflow-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "airflow_https" {
  count = local.use_ec2_airflow ? 1 : 0

  load_balancer_arn = aws_lb.airflow[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.airflow[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow[0].arn
  }
}

# Attach instance to target group
resource "aws_lb_target_group_attachment" "airflow" {
  count = local.use_ec2_airflow ? 1 : 0

  target_group_arn = aws_lb_target_group.airflow[0].arn
  target_id        = aws_instance.airflow[0].id
  port             = 8080
}

# IAM Role + Instance Profile for EC2
resource "aws_iam_role" "airflow_ec2" {
  count = local.use_ec2_airflow ? 1 : 0

  name = "${local.project_name}-airflow-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "airflow" {
  count = local.use_ec2_airflow ? 1 : 0

  name = "${local.project_name}-airflow-ec2-profile"
  role = aws_iam_role.airflow_ec2[0].name
}

# Attach SSM + Redshift policies
resource "aws_iam_role_policy_attachment" "airflow_ssm" {
  count      = local.use_ec2_airflow ? 1 : 0
  role       = aws_iam_role.airflow_ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "airflow_redshift" {
  count      = local.use_ec2_airflow && local.use_redshift ? 1 : 0
  role       = aws_iam_role.airflow_ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"  # Tighten for prod
}

# Output
output "airflow_ec2_web_url" {
  description = "Airflow web UI URL (HTTPS via ALB)"
  value       = local.use_ec2_airflow ? "https://${aws_lb.airflow[0].dns_name}" : null
}

output "airflow_ec2_ssh_command" {
  description = "SSM command to access EC2 instance"
  value       = local.use_ec2_airflow ? "aws ssm start-session --target ${aws_instance.airflow[0].id}" : null
}