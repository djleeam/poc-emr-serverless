variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_db_instance" "creditscore" {
  allocated_storage                   = 50
  backup_retention_period             = 0
  backup_window                       = "06:55-07:25"
  ca_cert_identifier                  = "rds-ca-2019"
  db_name                             = "creditscore"
  db_subnet_group_name                = aws_db_subnet_group.public.name
  deletion_protection                 = false
  engine                              = "postgres"
  engine_version                      = "13.7"
  iam_database_authentication_enabled = true
  identifier                          = "creditscore"
  instance_class                      = "db.t3.small"
  license_model                       = "postgresql-license"
  maintenance_window                  = "mon:08:12-mon:08:42"
  max_allocated_storage               = 0
  multi_az                            = false
  skip_final_snapshot                 = true
  storage_type                        = "gp2"
  username                            = var.db_username
  password                            = var.db_password
  publicly_accessible                 = true
  customer_owned_ip_enabled           = false
  enabled_cloudwatch_logs_exports     = []
  storage_encrypted                   = false
  tags                                = {}
  iops                                = 0
  vpc_security_group_ids              = [aws_security_group.rds_creditscore_sg.id]

  timeouts {}
}

##############################
# RDS DB subnet group
##############################

resource "aws_db_subnet_group" "public" {
  name       = "public-db-subnet-grp"
  subnet_ids = data.aws_subnets.public.ids
}

resource "aws_db_subnet_group" "private" {
  name       = "private-db-subnet-grp"
  subnet_ids = data.aws_subnets.private.ids
}

##############################
# VPC security group for RDS
##############################

resource "aws_security_group" "rds_creditscore_sg" {
  description = "Allow postgres access"
  name        = "rds-creditscore-sg"
  vpc_id      = data.aws_vpc.ntc_sand.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    description = "from my local network"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    from_port   = 5432
    protocol    = "tcp"
    to_port     = 5432
  }

  ingress {
    description = "from private subnets (where EMR Serverless is running)"
    cidr_blocks = [
      "10.2.64.0/24",
      "10.2.65.0/24",
      "10.2.66.0/24"
    ]
    from_port = 5432
    protocol  = "tcp"
    to_port   = 5432
  }

}