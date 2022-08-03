# TODO: Update to use terraform resources once available.
# See: https://github.com/hashicorp/terraform-provider-aws/issues/22330
resource "null_resource" "inspector_enable" {
  triggers = {
    region = var.region
  }

  provisioner "local-exec" {
    when    = create
    command = "aws inspector2 enable --resource-types EC2 ECR --region ${self.triggers.region}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws inspector2 disable --region ${self.triggers.region}"
  }
}
