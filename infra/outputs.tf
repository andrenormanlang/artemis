output "ecr_repository_url" {
  description = "URL do repositório ECR para push da imagem"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "task_definition_arn" {
  description = "ARN da task definition"
  value       = aws_ecs_task_definition.email.arn
}

output "schedule_name" {
  description = "Nome do EventBridge Schedule"
  value       = aws_scheduler_schedule.daily.name
}

output "log_group" {
  description = "Grupo de logs no CloudWatch"
  value       = aws_cloudwatch_log_group.task.name
}
