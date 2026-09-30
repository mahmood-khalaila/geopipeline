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

  tags = {
    Name = "geopipeline-processor-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "geopipeline-rds-sg"
  description = "Allow PostgreSQL only from GeoPipeline processor"
  vpc_id      = aws_vpc.geopipeline.id

  ingress {
    description     = "PostgreSQL from processor"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.processor.id]
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

resource "aws_ecr_repository" "processor" {
  name                 = "geopipeline-processor"
  image_tag_mutability = "MUTABLE"
  force_delete         = true


  image_scanning_configuration {
    scan_on_push = true
  }

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
  image_uri    = "${aws_ecr_repository.processor.repository_url}:latest"

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