# nginx-frontend — Terraform IaC

Deploys a production-ready nginx frontend stack on AWS using a public ALB + private EC2 instances in an ASG.

## Architecture

```
Internet
   │
   ▼
[ALB] (public subnets, ports 80/443)
   │
   ▼
[Target Group]
   │
   ├── EC2 nginx (private subnet AZ-a)
   ├── EC2 nginx (private subnet AZ-b)
   └── EC2 nginx (private subnet AZ-c)  ← prod only

Private subnets → NAT Gateway → Internet (for yum, SSM, S3)
```

**Key design decisions:**
- EC2 instances sit in private subnets. Only the ALB is public.
- No SSH. Use SSM Session Manager via the attached IAM role.
- IMDSv2 enforced on all instances.
- Per-AZ NAT Gateways for HA (one per public subnet).
- HTTPS listener created only when `certificate_arn` is set.
- HTTP → HTTPS redirect is automatic when a cert is provided.

## Folder structure

```
.
├── main.tf                     # root module, wires everything together
├── variables.tf
├── outputs.tf
├── provider.tf
├── Makefile
├── modules/
│   ├── vpc/                    # VPC, subnets, IGW, NAT GW, route tables
│   ├── security-groups/        # ALB SG + instance SG
│   ├── alb/                    # ALB, target group, listeners
│   ├── asg/                    # Launch template, ASG, scaling policies
│   └── iam/                    # EC2 instance role + profile
└── environments/
    ├── dev/terraform.tfvars
    ├── staging/terraform.tfvars
    └── prod/terraform.tfvars
```

## Quick start

```bash
# 1. Init (first time or after provider changes)
make init ENV=dev

# 2. Plan
make plan ENV=dev

# 3. Apply
make apply ENV=dev
```

Without Make:
```bash
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Deploying to a different region

Change `aws_region` and `aws_profile` in the relevant `terraform.tfvars`.  
Also update `ami_id` — AMI IDs are region-specific.

Common Amazon Linux 2 AMIs:
- us-east-1: `ami-0c02fb55956c7d316`
- us-west-2: `ami-0892d3c7ee96c0bf7`
- eu-west-1: `ami-04dd4500af104442f`

Use SSM Parameter Store to always get the latest:
```hcl
data "aws_ssm_parameter" "al2" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
```

## Connecting to instances (no SSH needed)

```bash
# List running instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=nginx-frontend" \
  --query "Reservations[].Instances[].InstanceId" \
  --profile us1

# Start SSM session
aws ssm start-session --target i-xxxxxxxxxxxx --profile us1
```

## Updating nginx content

The user data script in `modules/asg/main.tf` bootstraps nginx on first boot.  
For ongoing deployments, either:
1. Upload a new build artifact to S3 and trigger an ASG instance refresh.
2. Use CodeDeploy with the ASG as the deployment group.

Trigger a rolling instance refresh manually:
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name nginx-frontend-prod-asg \
  --preferences '{"MinHealthyPercentage": 50}' \
  --profile us1
```

## Remote state (recommended for shared environments)

Uncomment the `backend "s3"` block in `provider.tf` and create the bucket + DynamoDB table first:

```bash
# Create state bucket
aws s3api create-bucket \
  --bucket gainsight-terraform-state \
  --region us-east-1 \
  --profile us1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket gainsight-terraform-state \
  --versioning-configuration Status=Enabled \
  --profile us1

# Create lock table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --profile us1
```
