output "docker_push" {
  value = module.hosting.docker_push
}

output "image_repository" {
  value = module.hosting.image_repository
}

output "url" {
  value = "https://${module.hosting.endpoint}"
}
