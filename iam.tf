data "aws_caller_identity" "current" {}

resource "aws_iam_role" "github_actions" {
  name = "GitHubActions-Terraform-Deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:naoya-dev-code@331560908/terraform-github-actions@1381602096:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_s3" {
  name = "TerraformS3Access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:Get*",
          "s3:PutBucketTagging"
        ]

        Resource = [
          "arn:aws:s3:::naoya-terraform-github-actions-demo"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          "arn:aws:s3:::naoya-terraform-github-actions-state"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "arn:aws:s3:::naoya-terraform-github-actions-state/terraform-github-actions/terraform.tfstate",
          "arn:aws:s3:::naoya-terraform-github-actions-state/terraform-github-actions/terraform.tfstate.tflock"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]

        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActions-Terraform-Deploy"
        ]
      }
    ]
  })
}
