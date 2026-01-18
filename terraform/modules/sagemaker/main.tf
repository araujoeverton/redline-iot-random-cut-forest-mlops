# ============================================================================
# SageMaker Studio Domain Module
# ============================================================================

# VPC Configuration for SageMaker Studio
resource "aws_default_vpc" "default" {
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-default-vpc"
  })
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-default-subnet-az1"
  })
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-default-subnet-az2"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for SageMaker Studio
resource "aws_security_group" "sagemaker_studio" {
  name_prefix = "${var.project_name}-${var.environment}-sagemaker-studio-"
  description = "Security group for SageMaker Studio Domain"
  vpc_id      = aws_default_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-sagemaker-studio-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SageMaker Studio Domain
resource "aws_sagemaker_domain" "studio" {
  domain_name = "${var.project_name}-${var.environment}-studio"
  auth_mode   = "IAM"
  vpc_id      = aws_default_vpc.default.id
  subnet_ids  = [
    aws_default_subnet.default_az1.id,
    aws_default_subnet.default_az2.id
  ]

  default_user_settings {
    execution_role = var.sagemaker_execution_role_arn

    security_groups = [aws_security_group.sagemaker_studio.id]

    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://${var.s3_bucket_name}/sagemaker-studio-output/"
    }

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = "system"
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = var.default_instance_type
      }
    }
  }

  default_space_settings {
    execution_role = var.sagemaker_execution_role_arn

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = "system"
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = var.default_instance_type
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-studio-domain"
  })
}

# SageMaker Studio User Profile
resource "aws_sagemaker_user_profile" "default_user" {
  domain_id         = aws_sagemaker_domain.studio.id
  user_profile_name = var.user_profile_name

  user_settings {
    execution_role = var.sagemaker_execution_role_arn

    security_groups = [aws_security_group.sagemaker_studio.id]

    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://${var.s3_bucket_name}/sagemaker-studio-output/"
    }

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = "system"
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = var.default_instance_type
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.user_profile_name}"
  })
}
