# Identity Module

Creates Okta identity integration for EKS cluster access, including groups, rules, and OIDC application configuration.

## Features

- Okta group for Kubernetes cluster administrators
- Automatic user assignment rule based on department attribute
- OIDC application for EKS cluster authentication
- Group-to-application assignment for access control
- Integration with EKS OIDC provider for seamless authentication

## Usage

```hcl
module "identity" {
  source = "./modules/identity"

  eks_oidc_url = module.eks.cluster_oidc_issuer_url
}
```

## Requirements

- Okta provider >= 4.0
- Okta organization with API token access
- EKS cluster with OIDC provider enabled (from eks module)
- Users with `department="Engineering"` attribute for auto-assignment

## Prerequisites

Before using this module, ensure you have:

1. **Okta Organization**: Access to an Okta organization
2. **API Token**: Create an API token in Okta Admin > Security > API > Tokens
3. **User Attributes**: Users should have a `department` attribute set to "Engineering" for auto-assignment
4. **EKS OIDC URL**: The OIDC issuer URL from your EKS cluster (provided by eks module)

## Configuration

The module creates:

1. **Okta Group**: `k8s-cluster-admins`
   - Grants cluster-admin (system:masters) access to EKS
   - Users in this group can authenticate to the cluster

2. **Group Rule**: Auto-assigns users with `department="Engineering"` to the admin group
   - Expression: `user.department eq "Engineering"`
   - Automatically assigns users when they match the criteria

3. **OIDC Application**: Native OAuth application for EKS access
   - Type: Native application
   - Grant types: authorization_code, refresh_token
   - Redirect URIs: `http://localhost:8000/callback`, `http://localhost:18000/callback`

4. **Group Assignment**: Links the admin group to the OIDC application
   - Ensures only group members can use the application

## Cost Considerations

- No AWS costs (Okta resources only)
- Okta API calls may be subject to rate limits
- Consider Okta licensing for user management features

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| eks_oidc_url | OIDC issuer URL from the EKS control plane, used for future trust automation | string | no | "" |

## Outputs

| Name | Description |
|------|-------------|
| admin_group_id | Okta group ID that maps to Kubernetes cluster-admin |
| okta_client_id | Client ID of the Okta OIDC application provisioned for EKS access |
| oidc_placeholder | Echoes the supplied EKS OIDC issuer URL for documentation/runbook purposes |

## Authentication Flow

1. User authenticates with Okta
2. Okta validates user is in `k8s-cluster-admins` group
3. User receives authorization code from Okta OIDC app
4. User exchanges code for tokens
5. User uses tokens to authenticate to EKS cluster
6. EKS validates tokens with Okta OIDC provider

## Customization

To modify the auto-assignment rule, edit the `okta_group_rule.engineering_rule` resource:

```hcl
expression_value = "user.department eq \"Engineering\""
```

Change the expression to match your organization's user attributes and requirements.

## Post-Deployment

After the module is applied:

1. Verify the Okta group exists:
   - Check Okta Admin Console > Directory > Groups
   - Look for `k8s-cluster-admins`

2. Verify the OIDC application:
   - Check Okta Admin Console > Applications > Applications
   - Look for "EKS Cluster Access"

3. Test user assignment:
   - Ensure test users have `department="Engineering"` attribute
   - Verify they are automatically added to the admin group

4. Configure kubectl with Okta authentication:
   - Use tools like `kubelogin` or `aws-iam-authenticator` with Okta
   - Follow Okta OIDC integration guides for EKS

## Troubleshooting

- **Users not auto-assigned**: Check user attributes match the rule expression
- **OIDC app not working**: Verify redirect URIs match your authentication tool configuration
- **Group assignment missing**: Ensure the group is assigned to the OIDC application in Okta

