# EFS File System for shared board storage across WBO instances
resource "aws_efs_file_system" "wbo_storage" {
  creation_token = "wbo-boards-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name        = "wbo-boards-efs"
    Environment = var.environment
  }
}

# EFS Mount Targets in Public Subnets (same as ECS tasks)
resource "aws_efs_mount_target" "wbo_mount_1" {
  file_system_id  = aws_efs_file_system.wbo_storage.id
  subnet_id       = aws_subnet.public_subnet_1.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "wbo_mount_2" {
  file_system_id  = aws_efs_file_system.wbo_storage.id
  subnet_id       = aws_subnet.public_subnet_2.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  name        = "wbo-efs-sg"
  description = "Security group for WBO EFS"
  vpc_id      = aws_vpc.wbo_vpc.id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "wbo-efs-sg"
    Environment = var.environment
  }
}

output "efs_file_system_id" {
  description = "EFS file system ID for WBO shared storage"
  value       = aws_efs_file_system.wbo_storage.id
}
