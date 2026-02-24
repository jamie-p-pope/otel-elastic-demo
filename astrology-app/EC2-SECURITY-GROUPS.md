# Check EC2 security groups from the CLI

You need **port 8080** (frontend) and **port 8089** (Locust) open for inbound traffic from your IP (or 0.0.0.0/0 for demos).

## 1. Install AWS CLI (if needed)

On your laptop or the EC2 host:

```bash
# macOS
brew install awscli

# Or use the installer: https://aws.amazon.com/cli/
```

Configure credentials if you haven’t: `aws configure` (Access Key, Secret Key, region).

## 2. Find the instance and its security groups

From your **laptop** (with AWS CLI and credentials):

```bash
# List instances and their security groups (use your region)
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name,SecurityGroups[0].GroupId]' \
  --output table

# Or by public IP (replace with your EC2 public IP). Table-safe: one SG per row.
aws ec2 describe-instances \
  --filters "Name=ip-address,Values=54.152.41.176" \
  --query 'Reservations[*].Instances[*].[InstanceId,SecurityGroups[0].GroupId,SecurityGroups[0].GroupName]' \
  --output table
```

If the instance has **multiple** security groups, use this to see all (output is text, not table):
```bash
aws ec2 describe-instances \
  --filters "Name=ip-address,Values=54.152.41.176" \
  --query 'Reservations[*].Instances[*].SecurityGroups[*].[GroupId,GroupName]' \
  --output text
```

Note the **GroupId** (e.g. `sg-0abc123`).

## 3. Show inbound rules for that security group

```bash
# Replace sg-xxxxxxxx with your group ID
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx \
  --query 'SecurityGroups[*].IpPermissions' --output table
```

Or human‑friendly:

```bash
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx \
  --query 'SecurityGroups[*].IpPermissions[*].{FromPort:FromPort,ToPort:ToPort,Source:IpRanges[*].CidrIp}' \
  --output table
```

Check that you have rules allowing **TCP 8080** and **TCP 8089** from your IP (e.g. `MyIP/32`) or `0.0.0.0/0` for demos.

## 4. Open ports 8080 and 8089 (if missing)

```bash
# Replace sg-xxxxxxxx with your security group ID
# This allows 8080 and 8089 from any IP (use for demos; restrict in production)
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8089 --cidr 0.0.0.0/0
```

To allow only your current IP (replace with your public IP or use a script that resolves it):

```bash
MYIP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8080 --cidr ${MYIP}/32
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8089 --cidr ${MYIP}/32
```

## 5. Confirm from the host

On the EC2 host, confirm the app is listening on 0.0.0.0 (not only 127.0.0.1):

```bash
sudo ss -tlnp | grep -E '8080|8089'
```

You should see Docker (or the process) bound to `0.0.0.0:8080` and `0.0.0.0:8089`. If it’s only `127.0.0.1`, the app won’t be reachable from outside; with Docker published ports it’s usually 0.0.0.0.
