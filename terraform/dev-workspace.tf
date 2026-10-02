# Latest Windows Server 2022 AMI
data "aws_ami" "windows_server" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "dev_workspace" {
  name        = "geopipeline-dev-workspace-sg"
  description = "Allow RDP access to development workspace"
  vpc_id      = aws_vpc.geopipeline.id

  ingress {
    description = "RDP from configured IP range"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.rdp_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "geopipeline-dev-workspace-sg"
  }
}
resource "aws_key_pair" "dev_workspace" {
  key_name   = "geopipeline-rdp-key"
  public_key = file("~/.ssh/geopipeline-rdp.pub")
}

resource "aws_instance" "dev_workspace" {
  ami           = data.aws_ami.windows_server.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_1.id

  vpc_security_group_ids = [
    aws_security_group.dev_workspace.id
  ]
  key_name = aws_key_pair.dev_workspace.key_name

  tags = {
    Name = "geopipeline-dev-workspace"
  }
}

