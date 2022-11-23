############################################
# EMR Serverless Application | Credit Score
############################################

resource "aws_emrserverless_application" "credit_score_app" {
  name          = "credit-score-app"
  release_label = "emr-6.8.0"
  type          = "spark"

  # Specify initial & max capacity
  # https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/application-capacity.html
  initial_capacity {
    initial_capacity_type = "Driver"

    initial_capacity_config {
      worker_count = 2
      worker_configuration {
        cpu    = "2 vCPU"
        memory = "4 GB"
      }
    }
  }

  initial_capacity {
    initial_capacity_type = "Executor"

    initial_capacity_config {
      worker_count = 10
      worker_configuration {
        cpu    = "4 vCPU"
        memory = "8 GB"
      }
    }
  }

  maximum_capacity {
    cpu    = "100 vCPU"
    memory = "200 GB"
    disk   = "400 GB"
  }

  network_configuration {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.emr_serverless.id]
  }
}

##################
# ntc_sand_1 VPC
##################

data "aws_vpc" "ntc_sand" {
  tags = {
    Owner = "infrastructure"
    Tier  = "sand"
  }
}

##################################
# ntc_sand_1 VPC private subnets
##################################

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.ntc_sand.id]
  }

  tags = {
    SubnetType = "private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.ntc_sand.id]
  }

  tags = {
    SubnetType = "public"
  }
}

###############################################
# VPC security group for emr serverless apps
###############################################

resource "aws_security_group" "emr_serverless" {
  name   = "emr-serverless-sg"
  vpc_id = data.aws_vpc.ntc_sand.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
