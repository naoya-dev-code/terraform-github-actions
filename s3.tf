resource "aws_s3_bucket" "github_actions_demo" {
  bucket = "naoya-terraform-github-actions-demo"

  tags = {
    Name      = "terraform-github-actions-demo"
    ManagedBy = "Terraform"
  }
}
