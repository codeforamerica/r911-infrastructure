output "docker_push" {
  value = <<EOT
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.containers.registry_id}.dkr.ecr.${var.region}.amazonaws.com
docker build -t ${local.prefix}-web .
docker tag ${local.prefix}-web:latest ${aws_ecr_repository.containers.repository_url}:latest
docker push ${aws_ecr_repository.containers.repository_url}:latest
EOT
}

output "endpoint" {
  value = aws_route53_record.web.name
}

output "image_repository" {
  value = aws_ecr_repository.containers
}

output "task_task_definition" {
  value = aws_ecs_task_definition.db_migrate
}

output "web_cluster_name" {
  value = aws_ecs_cluster.web.name
}

output "web_security_group" {
  value = aws_security_group.web_private
}

output "web_service_name" {
  value = aws_ecs_service.web.name
}
