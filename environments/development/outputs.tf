output "connection_url" {
  value = module.ci_cd.connection_url
}

output "docker_push" {
  value = module.hosting.docker_push
}

output "image_repository" {
  value = module.hosting.image_repository.repository_url
}

output "url" {
  value = "https://${module.hosting.endpoint}"
}
