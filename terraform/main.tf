resource "aws_vpc" "geopipeline" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "geopipeline-vpc"
  }
}
################## add 4 subnets ###############################3
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.geopipeline.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "geopipeline-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.geopipeline.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "geopipeline-public-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.geopipeline.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "geopipeline-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.geopipeline.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "geopipeline-private-2"
  }
}
#### gate way + routing ###########################################
resource "aws_internet_gateway" "geopipeline" {
  vpc_id = aws_vpc.geopipeline.id

  tags = {
    Name = "geopipeline-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.geopipeline.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.geopipeline.id
  }

  tags = {
    Name = "geopipeline-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
#########################################################
#s3
###########
resource "aws_s3_bucket" "ingest" {
  bucket_prefix = "geopipeline-ingest-"

  tags = {
    Name = "geopipeline-ingest"
  }
}

resource "aws_s3_bucket_public_access_block" "ingest" {
  bucket = aws_s3_bucket.ingest.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#####################DB###################
resource "aws_db_subnet_group" "geopipeline" {
  name = "geopipeline-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name = "geopipeline-db-subnet-group"
  }
}


resource "aws_security_group" "processor" {
  name        = "geopipeline-processor-sg"
  description = "Security group for GeoPipeline processor"
  vpc_id      = aws_vpc.geopipeline.id
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "geopipeline-processor-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "geopipeline-rds-sg"
  description = "Allow PostgreSQL only from GeoPipeline processor"
  vpc_id      = aws_vpc.geopipeline.id

  # Lambda / Processor → RDS
  ingress {
    description     = "PostgreSQL from processor"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.processor.id]
  }

  # MapServer → RDS
  ingress {
    description     = "PostgreSQL from MapServer"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.mapserver.id]
  }

  tags = {
    Name = "geopipeline-rds-sg"
  }
}
resource "aws_db_instance" "geopipeline" {
  identifier = "geopipeline-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"

  db_name  = "geopipeline"
  username = "geopipeline"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.geopipeline.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "geopipeline-postgres"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.geopipeline.id

  tags = {
    Name = "geopipeline-private-rt"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.geopipeline.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "geopipeline-s3-endpoint"
  }
}

resource "aws_ecr_repository" "mapserver" {
  name                 = "geopipeline-mapserver"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name = "geopipeline-mapserver"
  }
}
resource "aws_ecr_repository" "processor" {
  name                 = "geopipeline-processor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name = "geopipeline-processor"
  }
}

resource "aws_iam_role" "processor" {
  name = "geopipeline-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "processor_s3" {
  name = "geopipeline-processor-s3"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "s3:GetObject"
      ]

      Resource = "${aws_s3_bucket.ingest.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "processor" {
  function_name = "geopipeline-processor"

  role         = aws_iam_role.processor.arn
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.processor.repository_url}:v2"

  lifecycle {
    ignore_changes = [image_uri]
  }

  timeout     = 60
  memory_size = 1024

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    security_group_ids = [
      aws_security_group.processor.id
    ]
  }

  environment {
    variables = {
      DB_HOST       = aws_db_instance.geopipeline.address
      DB_PORT       = tostring(aws_db_instance.geopipeline.port)
      DB_NAME       = "geopipeline"
      DB_SECRET_ARN = aws_db_instance.geopipeline.master_user_secret[0].secret_arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.processor_s3
  ]

  tags = {
    Name = "geopipeline-processor"
  }
}
resource "aws_iam_role_policy" "processor_secret" {
  name = "geopipeline-processor-secret"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "secretsmanager:GetSecretValue"
      ]

      Resource = aws_db_instance.geopipeline.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_security_group" "secrets_endpoint" {
  name        = "geopipeline-secrets-endpoint-sg"
  description = "Allow Lambda to access Secrets Manager endpoint"
  vpc_id      = aws_vpc.geopipeline.id

  ingress {
    description     = "HTTPS from processor"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.processor.id]
  }
  ingress {
    description     = "HTTPS from MapServer"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.mapserver.id]
  }

  tags = {
    Name = "geopipeline-secrets-endpoint-sg"
  }
}


resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.geopipeline.id
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  security_group_ids = [
    aws_security_group.secrets_endpoint.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "geopipeline-secretsmanager-endpoint"
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ingest.arn
}

resource "aws_s3_bucket_notification" "ingest" {
  bucket = aws_s3_bucket.ingest.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".geojson"
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}

# GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}


# IAM Role used by GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "geopipeline-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:mahmood-khalaila@274218691/geopipeline@1381942348:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Name = "geopipeline-github-actions-role"
  }
}


# Permissions GitHub needs for ECR + Lambda deployment
resource "aws_iam_role_policy" "github_actions" {
  name = "geopipeline-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]

        Resource = aws_ecr_repository.processor.arn
      },

      {
        Effect = "Allow"

        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction"
        ]

        Resource = aws_lambda_function.processor.arn
      }
    ]
  })
}


output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

resource "aws_security_group" "mapserver" {
  name        = "geopipeline-mapserver-sg"
  description = "Allow HTTP access to MapServer"
  vpc_id      = aws_vpc.geopipeline.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "geopipeline-mapserver-sg"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "mapserver" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_1.id

  vpc_security_group_ids = [
    aws_security_group.mapserver.id
  ]

  iam_instance_profile        = aws_iam_instance_profile.mapserver.name
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Install and start Docker
    dnf install -y docker
    systemctl enable --now docker

    # Login to ECR
    aws ecr get-login-password --region ${var.aws_region} \
      | docker login --username AWS --password-stdin \
      ${split("/", aws_ecr_repository.mapserver.repository_url)[0]}

    # Pull MapServer image
    docker pull ${aws_ecr_repository.mapserver.repository_url}:latest

    # Get RDS credentials from Secrets Manager
    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id ${aws_db_instance.geopipeline.master_user_secret[0].secret_arn} \
      --region ${var.aws_region} \
      --query SecretString \
      --output text)

    DB_USERNAME=$(echo "$SECRET" | python3 -c 'import sys,json; print(json.load(sys.stdin)["username"])')
    DB_PASSWORD=$(echo "$SECRET" | python3 -c 'import sys,json; print(json.load(sys.stdin)["password"])')

    # Create PostgreSQL service configuration
    mkdir -p /opt/mapserver

    printf '[geopipeline]\nhost=%s\nport=5432\ndbname=geopipeline\nuser=%s\npassword=%s\nsslmode=require\n' \
      '${aws_db_instance.geopipeline.address}' \
      "$DB_USERNAME" \
      "$DB_PASSWORD" \
      > /opt/mapserver/pg_service.conf

    # MapServer container runs its Apache workers as www-data (UID 33).
    # Keep the DB credentials readable only by root and that container user.
    chown root:33 /opt/mapserver/pg_service.conf
    chmod 640 /opt/mapserver/pg_service.conf

    # Remove credentials from shell variables once the config is created
    unset SECRET DB_USERNAME DB_PASSWORD

    # Run MapServer
    docker run -d \
      --name mapserver \
      --restart unless-stopped \
      -p 80:80 \
      -e PGSERVICEFILE=/etc/mapserver/pg_service.conf \
      -e HOME=/tmp \
      -v /opt/mapserver/pg_service.conf:/etc/mapserver/pg_service.conf:ro \
      ${aws_ecr_repository.mapserver.repository_url}:latest
  EOF

  tags = {
    Name = "geopipeline-mapserver"
  }
}

resource "aws_iam_role" "mapserver" {
  name = "geopipeline-mapserver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "mapserver_secrets" {
  name = "geopipeline-mapserver-secrets"
  role = aws_iam_role.mapserver.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = aws_db_instance.geopipeline.master_user_secret[0].secret_arn
    }]
  })
}
resource "aws_iam_role_policy_attachment" "mapserver_ssm" {
  role       = aws_iam_role.mapserver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "mapserver_ecr" {
  role       = aws_iam_role.mapserver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "mapserver" {
  name = "geopipeline-mapserver-profile"
  role = aws_iam_role.mapserver.name
}