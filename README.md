# Terraform GitHub Actions CI/CD

TerraformとGitHub Actionsを使用して、AWSインフラストラクチャのCI/CD環境を構築したプロジェクトです。

GitHub ActionsからAWSへの認証にはOIDCを使用し、長期的なAWSアクセスキーをGitHubに保存しない構成にしています。

TerraformのStateはAmazon S3でリモート管理し、GitHub ActionsからTerraform Planおよび手動Applyを実行できるようにしています。

## Architecture

```text
Developer
    |
    | git push / pull request
    v
GitHub
    |
    v
GitHub Actions
    |
    | OIDC
    v
AWS IAM Role
    |
    v
Terraform
    |
    +-----------------------+
    |                       |
    v                       v
S3 Remote State        Demo S3 Bucket
```

## Technologies

- AWS
- Terraform
- Amazon S3
- AWS IAM
- GitHub
- GitHub Actions
- OpenID Connect (OIDC)
- AWS IAM Identity Center

## Features

### Terraform CI/CD

GitHub Actionsを使用してTerraformのCI/CDを構築しています。

通常のPushおよびPull Requestでは以下を実行します。

```text
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Terraform Applyは自動実行せず、GitHub Actionsの`workflow_dispatch`から手動で実行する構成にしています。

これにより、コードをPushしただけでAWSリソースが意図せず変更されることを防いでいます。

## GitHub Actions and AWS Authentication

GitHub ActionsからAWSへの認証にはOIDCを使用しています。

```text
GitHub Actions
      |
      | OIDC Token
      v
AWS IAM
      |
      | AssumeRoleWithWebIdentity
      v
GitHubActions-Terraform-Deploy
```

AWS Access KeyやSecret Access Keyなどの長期認証情報をGitHub Secretsに保存する必要がありません。

IAM RoleのTrust Policyでは、対象のGitHub Repositoryおよびmainブランチからのアクセスに制限しています。

## Terraform Remote State

Terraform StateはAmazon S3に保存しています。

```text
S3 Bucket
naoya-terraform-github-actions-state

└── terraform-github-actions/
    └── terraform.tfstate
```

State管理用S3バケットには以下を設定しています。

- Versioning
- SSE-S3 (AES256)
- Block Public Access
- Terraform State Lock

TerraformのS3 Backendでは`use_lockfile = true`を使用しています。

## Bootstrap

Terraform Stateを保存するS3バケット自体は、メインTerraform構成とは分離した`bootstrap`ディレクトリで作成しています。

```text
bootstrap/
└── main.tf
```

最初にローカルからState管理用S3バケットを作成し、その後メインTerraform構成をS3 Backendへ移行しました。

これにより、Terraformが自身のStateを保存するバケットを安全に管理できる構成にしています。

## AWS Resources

このプロジェクトでは以下のAWSリソースを使用しています。

```text
IAM
└── GitHubActions-Terraform-Deploy

S3
├── naoya-terraform-github-actions-state
└── naoya-terraform-github-actions-demo
```

`naoya-terraform-github-actions-demo`はTerraformによって管理されています。

## Security

以下のセキュリティ設計を採用しています。

- GitHub ActionsからAWSへの認証にOIDCを使用
- AWSの長期アクセスキーをGitHubに保存しない
- IAM RoleのTrust PolicyでGitHub RepositoryとBranchを制限
- Terraform用IAM権限を必要なAWS操作に限定
- Terraform State用S3バケットのPublic Accessをブロック
- StateファイルをS3で暗号化
- S3 Versioningを有効化

## Troubleshooting

### GitHub OIDC Subject Mismatch

GitHub ActionsからAWS IAM RoleをAssumeする際に、以下のエラーが発生しました。

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

CloudTrailを確認して、GitHubから送信されたOIDC Tokenの`sub` ClaimとIAM Trust Policyを比較しました。

Trust PolicyのRepository Subjectに誤りがあることを特定し、正しいSubjectへ修正することでOIDC認証を成功させました。

### Terraform IAM Permission Errors

GitHub Actions上でTerraform Planを実行した際、TerraformがIAM RoleのStateをRefreshするための参照権限が不足していました。

必要な権限を確認し、以下のIAM参照権限を追加しました。

```text
iam:GetRole
iam:GetRolePolicy
iam:ListRolePolicies
iam:ListAttachedRolePolicies
```

必要な権限のみを段階的に追加しました。

### Terraform State Lock

GitHub ActionsのTerraform Applyを途中で停止した際、S3 BackendにState Lockが残りました。

Terraformは同じStateに対する複数の同時変更を防ぐため、次のTerraform処理をブロックしました。

Lockの所有者と実行中のTerraform処理が存在しないことを確認した上で、`terraform force-unlock`を使用してLockを解除しました。

### Recovering an Existing AWS Resource

GitHub ActionsのApply中にS3バケットの作成自体は完了しましたが、Terraform処理がState更新前に停止しました。

その結果、

```text
AWS
  -> S3 Bucket exists

Terraform State
  -> S3 Bucket not registered
```

という状態になりました。

既存のAWSリソースを削除して作り直すのではなく、`terraform import`を使用してTerraform Stateへ取り込みました。

```bash
terraform import \
  aws_s3_bucket.github_actions_demo \
  naoya-terraform-github-actions-demo
```

Import後に`terraform plan`を実行し、残っていたタグの差分のみをApplyしました。

最終的にAWS上のリソースとTerraform Stateを一致させました。

## Terraform Workflow

ローカル環境ではAWS IAM Identity Centerを利用しています。

```bash
aws sso login --profile naoya-sso
```

Terraformの基本的な実行フローは以下です。

```bash
AWS_PROFILE=naoya-sso terraform init

terraform fmt
terraform validate

AWS_PROFILE=naoya-sso terraform plan
AWS_PROFILE=naoya-sso terraform apply
```

GitHub ActionsではOIDCを利用するため、ローカルのAWS SSO Profileは使用しません。

## What I Learned

このプロジェクトを通して以下を実践しました。

- TerraformによるAWSリソース管理
- Terraform Remote State
- Terraform State Lock
- Terraform Import
- Terraform Stateの復旧
- GitHub ActionsによるTerraform CI/CD
- GitHub OIDCとAWS IAMの連携
- IAM最小権限設計
- AWS IAM Identity Centerを使用したローカル認証
- CloudTrailを使用したOIDCトラブルシューティング

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── terraform.yml
├── bootstrap/
│   └── main.tf
├── iam.tf
├── provider.tf
├── s3.tf
├── .gitignore
└── README.md
```
