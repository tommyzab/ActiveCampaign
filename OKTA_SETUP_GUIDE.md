# Okta Setup Guide

This guide will help you connect your Okta account to the EKS cluster for identity management.

## Prerequisites

1. **Okta Account**: You need an Okta organization (org)
   - If you don't have one, sign up at: https://developer.okta.com/signup/
   - **Note**: Okta Developer accounts may require corporate email validation

2. **EKS Cluster**: Your EKS cluster must be deployed and active
   - Run `terraform apply` first to create the cluster
   - Wait for cluster to be in "Active" status

## Step 1: Get Your Okta Org Name

1. Log in to your Okta Admin Console
2. Look at the URL in your browser - it will be something like:
   ```
   https://dev-123456-admin.okta.com
   ```
3. Your **org name** is the part before `.okta.com`, but **REMOVE `-admin`**:
   - ❌ Wrong: `dev-123456-admin` (includes -admin)
   - ✅ Correct: `dev-123456` (just the org name)
   
   **Example**: If your URL is `https://integrator-4772467-admin.okta.com`, use `integrator-4772467`

## Step 2: Create an Okta API Token

1. In Okta Admin Console, go to **Security** → **API** → **Tokens**
2. Click **Create Token**
3. Give it a name (e.g., "Terraform EKS Integration")
4. Click **Create Token**
5. **IMPORTANT**: Copy the token immediately - you won't be able to see it again!
6. Save it securely (you'll need it for Terraform)

## Step 3: Configure Terraform Variables

You have two options to provide Okta credentials:

### Option A: Environment Variables (Recommended)

```bash
export TF_VAR_enable_identity=true
export TF_VAR_okta_org_name="dev-123456"  # Replace with your org name
export TF_VAR_okta_api_token="YOUR_API_TOKEN_HERE"  # Replace with your token
```

### Option B: terraform.tfvars File

Create a file called `terraform.tfvars`:

```hcl
enable_identity = true
okta_org_name   = "dev-123456"  # Replace with your org name
okta_api_token  = "YOUR_API_TOKEN_HERE"  # Replace with your token
```

**Security Note**: Add `terraform.tfvars` to `.gitignore` to avoid committing secrets!

## Step 4: Initialize Terraform with Okta Provider

```bash
terraform init
```

This will download the Okta provider.

## Step 5: Plan and Apply

```bash
# Review what will be created
terraform plan

# Apply the Okta configuration
terraform apply
```

## What Gets Created

The Okta module will create:

1. **Okta Group**: `k8s-cluster-admins`
   - Users in this group will have cluster-admin access to EKS

2. **Group Rule**: `Auto-Assign Engineering`
   - Automatically adds users with `department = "Engineering"` to the admin group
   - You can customize this rule in `modules/identity/main.tf`

3. **OIDC Application**: `EKS Cluster Access`
   - This is the OIDC client that EKS will trust
   - Returns the `client_id` needed for EKS authentication

## Step 6: Configure EKS to Trust Okta

After Terraform creates the Okta resources, you need to configure EKS to trust the Okta OIDC application.

### Get the Required Values

After `terraform apply`, get the outputs:

```bash
terraform output
```

You'll need:
- `okta_client_id` - The OIDC client ID from Okta
- `cluster_oidc_issuer_url` - The EKS OIDC issuer URL

### Update EKS OIDC Identity Provider

1. Go to AWS Console → IAM → Identity providers
2. Find your EKS OIDC provider (it should already exist from Terraform)
3. Add the Okta client ID to the provider's audience list

OR use AWS CLI:

```bash
# Get the OIDC provider ARN
OIDC_PROVIDER_ARN=$(terraform output -raw oidc_provider_arn)

# Get the Okta client ID
OKTA_CLIENT_ID=$(terraform output -raw okta_client_id)

# Update the OIDC provider (this is a manual step - AWS doesn't support updating via CLI easily)
# You may need to do this via the AWS Console
```

## Step 7: Configure Kubernetes Authentication

You'll need to install and configure the Okta authentication plugin for kubectl:

1. Install `kubelogin` (Okta plugin for kubectl):
   ```bash
   # macOS
   brew install int128/kubelogin/kubelogin
   
   # Linux
   wget https://github.com/int128/kubelogin/releases/latest/download/kubelogin_linux_amd64.zip
   unzip kubelogin_linux_amd64.zip
   sudo mv kubelogin /usr/local/bin/
   ```

2. Configure kubectl to use Okta:
   ```bash
   kubectl config set-credentials okta \
     --exec-api-version=client.authentication.k8s.io/v1beta1 \
     --exec-command=kubelogin \
     --exec-arg=get-token \
     --exec-arg=--oidc-issuer-url=https://YOUR_ORG.okta.com/oauth2/default \
     --exec-arg=--oidc-client-id=YOUR_CLIENT_ID
   ```

## Troubleshooting

### Error: "Invalid API token"
- Verify your API token is correct
- Check that the token hasn't expired
- Ensure you copied the entire token

### Error: "Org name not found"
- Verify your org name matches the URL (without `.okta.com`)
- Check that you have admin access to the Okta org

### Error: "Cannot create OIDC application"
- Ensure you have the necessary Okta admin permissions
- Check that OIDC applications are enabled in your Okta org

### EKS Authentication Not Working
- Verify the OIDC provider is configured correctly in AWS IAM
- Check that the Okta client ID is added to the OIDC provider's audience
- Ensure kubectl is configured with the correct Okta issuer URL and client ID

## Next Steps

After setup, you can:
1. Add users to the `k8s-cluster-admins` group in Okta
2. Users with `department = "Engineering"` will be auto-added via the group rule
3. Authenticate to EKS using Okta credentials

## Security Best Practices

1. **Rotate API tokens regularly**
2. **Use least privilege** - only grant admin access to necessary users
3. **Monitor Okta logs** for authentication attempts
4. **Keep `terraform.tfvars` in `.gitignore`** to avoid committing secrets

