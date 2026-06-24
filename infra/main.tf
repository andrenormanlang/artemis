###############################################################################
# Artemis — boletim lunar por fase em AWS.
#
# EventBridge Scheduler (cron diário, no fuso de entrega) -> ecs:RunTask
#   -> Fargate roda `rake cron:lunar_phase_email` (imagem do Dockerfile do repo)
#     -> só envia em dia de fase principal / lua especial, via AWS SES.
#
# Recursos: ECR, ECS (cluster + task definition), IAM (execution + task roles),
# CloudWatch Logs, Security Group e o EventBridge Schedule.
# Pré-requisitos manuais: identidade verificada no SES (e saída do sandbox) e
# os segredos criados no Secrets Manager (ver infra/README.md).
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.project}-lunar-email"
  tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Component = "lunar-phase-email"
  }
}

###############################################################################
# ECR — repositório da imagem da aplicação
###############################################################################
resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

###############################################################################
# CloudWatch Logs
###############################################################################
resource "aws_cloudwatch_log_group" "task" {
  name              = "/ecs/${local.name}"
  retention_in_days = 30
  tags              = local.tags
}

###############################################################################
# Segredos (criados fora do Terraform; aqui só referenciamos por ARN)
###############################################################################
data "aws_secretsmanager_secret" "secrets" {
  for_each = var.secret_names
  name     = each.value
}

###############################################################################
# IAM — execution role (puxar imagem do ECR, escrever logs, ler segredos)
###############################################################################
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for s in data.aws_secretsmanager_secret.secrets : s.arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${local.name}-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

###############################################################################
# IAM — task role (runtime): enviar e-mail via SES
###############################################################################
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "task_ses" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_ses" {
  name   = "${local.name}-task-ses"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_ses.json
}

###############################################################################
# ECS — cluster + task definition (Fargate)
###############################################################################
resource "aws_ecs_cluster" "this" {
  name = local.name
  tags = local.tags
}

resource "aws_ecs_task_definition" "email" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "lunar-email"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      # Sobrescreve o CMD do Dockerfile para rodar a tarefa de cron e sair.
      command = ["./bin/rails", "cron:lunar_phase_email"]

      environment = [
        { name = "RAILS_ENV", value = "production" },
        { name = "MAIL_DELIVERY_METHOD", value = "ses" },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "DELIVERY_TIME_ZONE", value = var.delivery_time_zone },
        { name = "MAIL_FROM", value = var.mail_from },
        { name = "APP_HOST", value = var.app_host },
      ]

      secrets = [
        for key, secret_name in var.secret_names : {
          name      = key
          valueFrom = data.aws_secretsmanager_secret.secrets[key].arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.task.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "lunar-email"
        }
      }
    }
  ])

  tags = local.tags
}

###############################################################################
# Security Group — egress para Postgres (Neon), Redis e HTTPS (API/SES)
###############################################################################
resource "aws_security_group" "task" {
  name        = "${local.name}-task"
  description = "Egress for the lunar email task"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

###############################################################################
# EventBridge Scheduler — dispara o RunTask diariamente
###############################################################################
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.email.arn, "${aws_ecs_task_definition.email.arn}:*"]
  }
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${local.name}-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}

resource "aws_scheduler_schedule" "daily" {
  name       = local.name
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  # Roda todo dia no horário/fuso de entrega; o job decide se há fase hoje.
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.delivery_time_zone

  target {
    arn      = aws_ecs_cluster.this.arn
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.email.arn
      launch_type         = "FARGATE"
      task_count          = 1

      network_configuration {
        subnets          = var.subnet_ids
        security_groups  = [aws_security_group.task.id]
        assign_public_ip = var.assign_public_ip
      }
    }
  }
}
