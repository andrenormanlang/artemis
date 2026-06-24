variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nome do projeto (usado em nomes de recursos / repo ECR)"
  type        = string
  default     = "artemis"
}

variable "image_tag" {
  description = "Tag da imagem no ECR a ser executada"
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  description = "CPU da task Fargate (unidades)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memória da task Fargate (MiB)"
  type        = string
  default     = "1024"
}

variable "delivery_time_zone" {
  description = "Fuso de entrega (IANA). Define a data de referência e o horário do schedule."
  type        = string
  default     = "Europe/Stockholm"
}

variable "schedule_expression" {
  description = "Expressão cron do EventBridge Scheduler (avaliada em delivery_time_zone)"
  type        = string
  default     = "cron(0 9 * * ? *)" # todo dia 09:00
}

variable "mail_from" {
  description = "Remetente verificado no SES (From)"
  type        = string
}

variable "app_host" {
  description = "Host público da app para o link 'Abrir Artemis' no e-mail"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC onde a task roda"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets para a task (com saída à internet: NAT ou IP público)"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Atribuir IP público (true para subnets públicas; false se usar NAT)"
  type        = bool
  default     = true
}

# Mapa: NOME_DA_ENV_VAR => nome do segredo no Secrets Manager.
# A execution role lê estes segredos e os injeta na task.
variable "secret_names" {
  description = "Segredos a injetar (env var => Secrets Manager secret name)"
  type        = map(string)
  default = {
    RAILS_MASTER_KEY    = "artemis/rails_master_key"
    DATABASE_URL        = "artemis/database_url"
    ASTRO_API_KEY       = "artemis/astro_api_key"
    DAILY_LUNAR_API_URL = "artemis/daily_lunar_api_url"
    REDIS_URL           = "artemis/redis_url"
  }
}
