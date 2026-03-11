# AWS RDS Configuration - Terraform

This section covers the AWS RDS database setup using Terraform.

## RDS Configuration

### Specifications

- **Type:** Dev/Test (Non-production)
- **Engine:** PostgreSQL 16.1 (configurable)
- **Instance Class:** db.t3.micro
- **Deployment:** Single-AZ
- **Storage:** 20GB gp2
- **Public Access:** Yes
- **Performance Insights:** Disabled
- **Enhanced Monitoring:** Disabled
- **Credentials:** AWS Secrets Manager

### Files

- `rds.tf` - Main RDS instance, security group, subnet group
- `rds-secrets.tf` - Secrets Manager integration for credentials
- `rds-variables.tf` - RDS-specific variables

## Quick Start

### 1. Initialize and Apply

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Get Database Credentials

Retrieve credentials from Secrets Manager:

```bash
# Get full secret
aws secretsmanager get-secret-value \
  --secret-id hrms-cluster-rds-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .

# Get specific values
aws secretsmanager get-secret-value \
  --secret-id hrms-cluster-rds-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password'
```

### 3. Connect to Database

#### Using psql (PostgreSQL)

```bash
# Get connection details
export DB_HOST=$(terraform output -raw rds_address)
export DB_PORT=$(terraform output -raw rds_port)
export DB_NAME=$(terraform output -raw rds_database_name)
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id hrms-cluster-rds-credentials --region us-east-1 --query SecretString --output text | jq -r '.password')

# Connect
psql -h $DB_HOST -p $DB_PORT -U admin -d hrmsdb
```

#### Using MySQL Client

```bash
# If using MySQL engine
mysql -h $DB_HOST -P $DB_PORT -u admin -p$DB_PASSWORD hrmsdb
```

## Configuration Details

### Network Configuration

- **VPC:** Same VPC as EKS cluster
- **Subnets:** Public subnets for accessibility
- **Security Group:** Allows connections from:
  - Anywhere (0.0.0.0/0) on port 5432 (PostgreSQL) and 3306 (MySQL)
  - EKS cluster security group

### Storage Configuration

```hcl
allocated_storage     = 20      # 20GB
storage_type          = "gp2"   # General Purpose SSD
storage_encrypted     = false   # No encryption for dev/test
max_allocated_storage = 0       # No autoscaling
```

### Backup Configuration

```hcl
backup_retention_period = 7           # 7 days retention
backup_window          = "03:00-04:00" # 3-4 AM UTC
maintenance_window     = "mon:04:00-mon:05:00"
skip_final_snapshot    = true         # No snapshot on delete
```

### Monitoring Configuration

```hcl
performance_insights_enabled    = false # Disabled
monitoring_interval             = 0     # Enhanced monitoring disabled
enabled_cloudwatch_logs_exports = []    # No log exports
```

## Database Engines

### PostgreSQL (Default)

```hcl
db_engine         = "postgres"
db_engine_version = "16.1"
```

Supported versions: 16.x, 15.x, 14.x, 13.x

### MySQL

```hcl
db_engine         = "mysql"
db_engine_version = "8.0.35"
```

## Management Commands

### View RDS Information

```bash
# Get all RDS outputs
terraform output

# Get specific output
terraform output rds_endpoint
terraform output rds_secret_arn

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier hrms-cluster-db \
  --region us-east-1
```

### Update RDS Configuration

Edit `terraform.tfvars` and apply:

```hcl
# Scale up instance
db_instance_class = "db.t3.small"

# Increase storage
db_allocated_storage = 30
```

Then apply:
```bash
terraform apply
```

### Enable Multi-AZ

```hcl
db_multi_az = true
```

**Warning:** This will cause downtime during the conversion.

### Modify Backup Retention

```hcl
db_backup_retention_period = 14  # Increase to 14 days
```

### Change Database Engine

To switch from PostgreSQL to MySQL:

1. Create snapshot of current database
2. Update variables:
   ```hcl
   db_engine         = "mysql"
   db_engine_version = "8.0.35"
   ```
3. Run `terraform destroy -target=aws_db_instance.main`
4. Run `terraform apply`

## Secrets Management

### Create Kubernetes Secret from AWS Secrets Manager

```bash
# Retrieve credentials
DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id hrms-cluster-rds-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text)

# Create Kubernetes secret
kubectl create secret generic db-credentials \
  --from-literal=host=$(echo $DB_SECRET | jq -r '.host') \
  --from-literal=port=$(echo $DB_SECRET | jq -r '.port') \
  --from-literal=database=$(echo $DB_SECRET | jq -r '.dbname') \
  --from-literal=username=$(echo $DB_SECRET | jq -r '.username') \
  --from-literal=password=$(echo $DB_SECRET | jq -r '.password') \
  --namespace hrms
```

### Use in Kubernetes Deployment

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DB_HOST
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: host
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
```

### Rotate Password

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 16)

# Update RDS password
aws rds modify-db-instance \
  --db-instance-identifier hrms-cluster-db \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately \
  --region us-east-1

# Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id hrms-cluster-rds-credentials \
  --secret-string "$(aws secretsmanager get-secret-value --secret-id hrms-cluster-rds-credentials --query SecretString --output text | jq --arg pwd "$NEW_PASSWORD" '.password = $pwd')" \
  --region us-east-1
```

## Security Best Practices

### For Production

Update these settings in `terraform.tfvars`:

```hcl
db_publicly_accessible      = false  # No public access
db_multi_az                 = true   # Enable Multi-AZ
db_deletion_protection      = true   # Prevent accidental deletion
db_skip_final_snapshot      = false  # Create final snapshot
storage_encrypted           = true   # Enable encryption
```

Update `rds.tf`:
```hcl
# Enable monitoring
performance_insights_enabled = true
monitoring_interval          = 60

# Enable CloudWatch logs
enabled_cloudwatch_logs_exports = ["postgresql"]  # or ["error", "general", "slowquery"] for MySQL
```

### Restrict Security Group

Edit `rds.tf` to allow only EKS cluster access:

```hcl
# Remove public access rule
# Keep only this:
ingress {
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [aws_security_group.eks_cluster.id]
  description     = "PostgreSQL from EKS cluster only"
}
```

## Troubleshooting

### Cannot Connect to Database

**Issue:** Connection timeout or refused.

**Solution:**
1. Check security group rules:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id> --region us-east-1
   ```
2. Verify public accessibility:
   ```bash
   aws rds describe-db-instances --db-instance-identifier hrms-cluster-db --region us-east-1 --query 'DBInstances[0].PubliclyAccessible'
   ```
3. Check VPC and subnet configuration

### Secret Not Found

**Issue:** Secrets Manager secret doesn't exist.

**Solution:**
```bash
# List secrets
aws secretsmanager list-secrets --region us-east-1

# Verify secret exists
aws secretsmanager describe-secret --secret-id hrms-cluster-rds-credentials --region us-east-1
```

### Database Creation Failed

**Issue:** RDS instance failed to create.

**Solution:**
```bash
# Check CloudWatch events
aws rds describe-events \
  --source-identifier hrms-cluster-db \
  --source-type db-instance \
  --region us-east-1

# Check parameter group
aws rds describe-db-parameter-groups --region us-east-1
```

## Cost Optimization

### Estimated Monthly Cost (us-east-1)

- **db.t3.micro:** ~$12.41/month
- **20GB gp2 storage:** ~$2.30/month
- **Backup storage (7 days):** ~$0.95/month (100% of database size)
- **Total:** ~$15.66/month

### Cost Saving Tips

1. **Stop when not in use:**
   ```bash
   aws rds stop-db-instance --db-instance-identifier hrms-cluster-db --region us-east-1
   ```
   Note: Automatically starts after 7 days

2. **Delete and recreate:**
   ```bash
   terraform destroy -target=aws_db_instance.main
   # Recreate when needed
   terraform apply
   ```

3. **Reduce backup retention:**
   ```hcl
   db_backup_retention_period = 1  # Minimum
   ```

4. **Use Aurora Serverless (for production):**
   - Only pay when database is active
   - Auto-scales based on load

## Backup and Restore

### Manual Snapshot

```bash
aws rds create-db-snapshot \
  --db-instance-identifier hrms-cluster-db \
  --db-snapshot-identifier hrms-cluster-db-snapshot-$(date +%Y%m%d) \
  --region us-east-1
```

### Restore from Snapshot

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier hrms-cluster-db-restored \
  --db-snapshot-identifier hrms-cluster-db-snapshot-20260223 \
  --region us-east-1
```

### Export to S3

```bash
aws rds start-export-task \
  --export-task-identifier hrms-export-$(date +%Y%m%d) \
  --source-arn arn:aws:rds:us-east-1:ACCOUNT:snapshot:hrms-cluster-db-snapshot-20260223 \
  --s3-bucket-name my-backup-bucket \
  --iam-role-arn arn:aws:iam::ACCOUNT:role/RDSExportRole \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID \
  --region us-east-1
```

## Monitoring

### Check Database Metrics

```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=hrms-cluster-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1

# Database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=hrms-cluster-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1
```

## Additional Resources

- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
- [Terraform AWS RDS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
