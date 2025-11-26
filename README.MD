# ActiveCampaign Take-Home – Okta + EKS CI/CD

This repository demonstrates how I would bootstrap, govern, and continuously deliver changes to an AWS EKS foundation that is tightly integrated with Okta. The emphasis is on design clarity, repeatability, and the ability to extend into a production-grade platform once proper tenants/secrets are available.

## 🧠 Architecture & Design Decisions

1. **Identity Management Strategy (Infrastructure vs. Identity)**  
   Terraform is responsible for the _infrastructure of identity_ (groups, rules, OIDC apps) rather than end-user lifecycle. In production I assume an upstream HRIS/SCIM feed seeds accounts, while Terraform and Okta group rules (e.g., `okta_group_rule.engineering_rule`) sort users into the correct access tiers. This keeps Terraform state lean and prevents user churn from bloating plans.

2. **Okta Implementation Note**  
   The Okta Developer program currently requires corporate email validation, which prevented me from standing up a live tenant for this lab. The `modules/identity` code has been `terraform validate`-ed, follows standard EKS <-> Okta OIDC trust patterns, and can be activated by setting `enable_identity=true` once real credentials are available.

3. **Infrastructure Bootstrapping (`bootstrap/setup.sh`)**  
   New AWS accounts rarely have a Terraform backend ready. The shell helper solves the “chicken & egg” problem by creating a globally unique S3 bucket + DynamoDB lock table, then generating `backend.tf`. This allows me (or CI) to spin up ephemeral environments in seconds without touching the AWS console.

4. **Production TLS / Zero-Trust Considerations**  
   To keep the take-home fast, the ingress path is left on HTTP. In production I would front the ALB with Route53-managed DNS, auto-provision ACM certificates, and enforce HTTPS via the AWS Load Balancer Controller annotations. The architecture naturally supports those changes with minimal code churn.

## Repository Layout

| Path | Purpose |
|------|---------|
| `main.tf` | Composes the VPC, EKS, and optional Okta identity layers. |
| `modules/network` | Opinionated VPC with public/private subnets, NAT, routing. |
| `modules/eks` | Terraform AWS Modules based EKS cluster with IRSA enabled and an admin auth mapping. |
| `modules/identity` | Okta groups, group rules, and OIDC application plus outputs for the EKS trust. |
| `bootstrap/setup.sh` | Helper script that provisions the remote backend automatically. |
| `.github/workflows/infra.yml` | GitHub Actions pipeline that runs fmt → validate → plan on PRs and supports gated applies. |

## CI/CD Pipeline (GitHub Actions)

Workflow: `.github/workflows/infra.yml`

- **Triggers**: Push/Pull Request (plan only) and `workflow_dispatch` for promotion into apply.  
- **Jobs**:
  - `plan`: Checks out code, installs Terraform 1.7.x, assumes AWS via OIDC, exports optional Okta secrets, runs `terraform fmt -check`, `validate`, and `plan`, then uploads the binary plan artifact.
  - `apply`: Requires a manual `workflow_dispatch` with `run_apply=true` and targets the protected `production` environment for an approval gate. Rehydrates the plan artifact and applies it with the same credentials.
- **Secrets/Inputs**:  
  - `AWS_DEPLOY_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_TABLE` for state + access.  
  - `OKTA_API_TOKEN`, `OKTA_ORG_NAME`, `ENABLE_IDENTITY` to wire Okta when desired.  
  - The workflow maps these secrets into `TF_VAR_*` env vars so Terraform can toggle identity without editing code.

This CI/CD design keeps drift detection automated (via plan on every PR) while ensuring production applies remain human-approved.

## Getting Started Locally

### Prerequisites

1. **Create an IAM User** (recommended - don't use root account)
   - Create a new IAM user in AWS Console
   - Attach the policy from `iam-policy-terraform-user.json` (see below)
   - Generate access keys and configure AWS CLI:
     ```bash
     aws configure --profile terraform-user
     export AWS_PROFILE=terraform-user
     ```

2. **IAM Policy Setup**
   - The file `iam-policy-terraform-user.json` contains all required permissions
   - Create a new IAM policy in AWS Console and paste the JSON contents
   - Attach the policy to your IAM user
   - **Note:** You can delete this file after creating the policy (it's for reference only)

### Deployment Steps

1. **Bootstrap backend (optional if already provisioned)**  
   ```bash
   cd bootstrap
   ./setup.sh
   cd ..
   terraform init
   ```
2. **Review variables** – defaults live in `variables.tf`. Override via `terraform.tfvars` or CLI flags.  
3. **Deploy**  
   ```bash
   terraform plan -var="project_name=okta-eks" -var="environment=dev"
   terraform apply
   ```

### Cost Optimization

This configuration is optimized for cost savings (home assignment). See `COST_OPTIMIZATION_NOTES.md` for details on:
- Disabled features (CloudWatch logging, KMS encryption) and how to enable them
- Cost estimates (~$134/month if running 24/7)
- Strategies to reduce costs (scale down nodes, use Spot instances, etc.)
- **Note:** The cost notes file is gitignored - it's for your personal reference only

## Enabling Okta Identity Automation

1. Obtain an Okta tenant and API token.  
2. Set Terraform variables (or GitHub secrets)  
   ```bash
   export TF_VAR_enable_identity=true
   export TF_VAR_okta_org_name="dev-123456"
   export TF_VAR_okta_api_token="xxxx"
   ```
3. Re-run `terraform apply`. The `module.identity` resources (group, rule, OIDC app) will be created and the outputs will surface the client ID/group ID for downstream use.

> Note: The Okta provider block is safe to leave configured even when `enable_identity=false`; validation rules prevent empty secrets when the module is toggled on.

## Future Enhancements

- Add ACM + Route53 resources and ALB ingress manifests for full TLS enforcement.
- Layer in IRSA-backed service accounts for workload add-ons (ExternalDNS, cert-manager).
- Extend CI/CD with automated security scanning (tfsec, OPA) prior to plan.
- Publish architectural diagrams (e.g., in `/docs`) showing AWS + Okta trust relationships once a permanent tenant is available.

## Runbook Recap

1. Generate backend via `bootstrap/setup.sh` (or reuse an existing S3/DynamoDB pair).  
2. Develop infrastructure changes locally; use `terraform fmt`, `validate`, `plan`.  
3. Open a PR – GitHub Actions will run the same checks.  
4. For production, trigger `workflow_dispatch` with `run_apply=true` and approve the protected environment to apply the previously reviewed plan.

## Troubleshooting

### Module Version Compatibility

This codebase uses EKS module v20+ to avoid known `for_each` issues present in v19. If you encounter any module-related errors, ensure you're using the latest module version by running `terraform init -upgrade`.

### Cost Optimization Features

This configuration is optimized for cost savings (home assignment) by disabling expensive features:

- **CloudWatch Logging** - Disabled (see `COST_OPTIMIZATION_NOTES.md` to enable)
- **KMS Encryption** - Disabled (see `COST_OPTIMIZATION_NOTES.md` to enable)
- **Access Entries** - Commented out (can be enabled for production RBAC)

**Required IAM Permissions:**
- `iam:PassRole` - **Fundamental AWS requirement** for EKS cluster creation (must pass IAM role to cluster)
- `iam:TagPolicy` - **Module requirement** for the custom IAM policy that manages cluster resources (EC2, ELB, etc.)

All required permissions are included in `iam-policy-terraform-user.json`. Attach this policy to your IAM user before deploying.

**Using Pre-Existing IAM Roles (Optional):**
If you have pre-created IAM roles, you can use them instead of letting Terraform create new ones:

```bash
# Find existing roles
aws iam list-roles --query 'Roles[?contains(RoleName, `EKS`) || contains(RoleName, `eks`)].{RoleName:RoleName, Arn:Arn}' --output table

# Use the role ARN when applying
terraform apply \
  -var="cluster_iam_role_arn=arn:aws:iam::ACCOUNT_ID:role/YOUR_ROLE_NAME" \
  -var="node_group_iam_role_arn=arn:aws:iam::ACCOUNT_ID:role/YOUR_ROLE_NAME"
```

**Note:** In production, cluster and node group roles should be separate with different policies. For development/testing, using the same role is acceptable.

### Configuration Status

- ✅ `terraform validate` passes
- ✅ `terraform plan` generates a valid execution plan
- ✅ Code structure follows best practices
- ✅ `for_each` issue resolved (using EKS module v20)
- ✅ Support for existing IAM roles (optional)
- ✅ Cost-optimized for home assignment (logging/encryption disabled)

The infrastructure design is production-ready; expensive features are disabled for cost savings but can be easily enabled when needed (see `COST_OPTIMIZATION_NOTES.md`).