# Terraform: AWS Environment with Windows Server 2019 & RHEL 9

## Youtube

https://www.youtube.com/watch?v=S3_gy96eVkE

---

## Overview

This document outlines the step-by-step process for building an AWS lab environment using Terraform. The environment consists of two EC2 instances:

- **Windows Server 2019** — configured as an Active Directory domain controller
- **RHEL 9.7** — a Linux client machine joined to the Active Directory domain

The goal is to provision this infrastructure automatically via Terraform, then authenticate the Linux client through Active Directory.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed
- An AWS account with IAM user access
- Visual Studio Code (recommended) with the Terraform extension
- A working directory (e.g., `~/terraform/`)

---

## Step 1: Configure the Terraform Provider (`main.tf`)

Create a `main.tf` file. Use the official [Terraform AWS Provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) to get the base configuration blocks.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"   # Update to the region closest to you
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
}
```

> **Security Warning:** Never share or commit your access keys to version control. Delete keys immediately after use or use environment variables / AWS profiles instead.

### Getting AWS Access Keys

1. Log in to the **AWS Console**
2. Navigate to **IAM → Users → Your User → Security Credentials**
3. Scroll to **Access Keys** and click **Create Access Key**
4. Select **Command Line Interface (CLI)**
5. Confirm the recommendation acknowledgment and click **Next → Create Access Key**
6. Copy the **Access Key** and **Secret Key** into your `main.tf`

> Choose the AWS region closest to you for better performance (e.g., `us-east-1` for US East - N. Virginia).

---

## Step 2: Find AMI IDs and Owner IDs (`ami.tf`)

Create a `notes.txt` file in your Terraform directory to track AMI IDs and owner IDs during setup.

### Finding AMI IDs via AWS Console

1. Go to **EC2 → AMI Catalog**
2. Search for **Windows Server 2019** — copy the AMI ID for `Microsoft Windows Server 2019 Base`
3. Search for **Red Hat** — copy the AMI ID for `RHEL 9 HVM SSD Volume Type`

### Finding Owner IDs via AWS CLI

First, log in to the AWS CLI:

```bash
aws login
```

Run the following command for **Windows Server 2019**:

```bash
aws ec2 describe-images \
  --image-ids <WINDOWS_AMI_ID> \
  --region us-east-1 \
  --query 'Images[0].OwnerId'
```

Run the same command for **RHEL 9**:

```bash
aws ec2 describe-images \
  --image-ids <RHEL_AMI_ID> \
  --region us-east-1 \
  --query 'Images[0].OwnerId'
```

> The owner ID ensures images come from legitimate, official vendors (e.g., Microsoft or Red Hat) rather than unknown third parties.

### Browsing Available Images by Owner

To see all Windows images available from a given owner:

```bash
aws ec2 describe-images \
  --owners <WINDOWS_OWNER_ID> \
  --region us-east-1 \
  --query 'Images[*].[ImageId,Name]' \
  --output table
```

To filter RHEL 9.7 images:

```bash
aws ec2 describe-images \
  --owners <RHEL_OWNER_ID> \
  --region us-east-1 \
  --filters "Name=name,Values=RHEL-9.7*HVM*x86_64*" \
  --query 'Images[*].[ImageId,Name]' \
  --output table
```

> Wildcards (`*`) are used in name filters to accommodate version numbers and dates that may change over time.

### `ami.tf` Configuration

```hcl
data "aws_ami" "win_serve_2019" {
  most_recent = true
  owners      = ["<WINDOWS_OWNER_ID>"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["<RHEL_OWNER_ID>"]

  filter {
    name   = "name"
    values = ["RHEL-9.7*HVM*x86_64*"]
  }
}
```

> `most_recent = true` tells Terraform to automatically select the latest available image — no manual selection needed.

---

## Step 3: Create EC2 Instances (`instances.tf`)

### Create a Key Pair in AWS Console

Before applying, create a key pair in AWS:

1. Go to **EC2 → Key Pairs → Create Key Pair**
2. Name it exactly: `terraform_key`
3. Select **RSA** and **.pem** format
4. Download and save the `.pem` file

> The key name in Terraform **must exactly match** the name created in AWS.

### `instances.tf` Configuration

```hcl
resource "aws_instance" "windows" {
  ami                    = data.aws_ami.win_serve_2019.id
  instance_type          = "t2.micro"
  key_name               = "terraform_key"
  subnet_id              = aws_subnet.shared_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_all.id]

  tags = {
    Name = "Windows Server 2019"
  }
}

resource "aws_instance" "rhel" {
  ami                    = data.aws_ami.rhel.id
  instance_type          = "t2.micro"
  key_name               = "terraform_key"
  subnet_id              = aws_subnet.shared_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_all.id]

  tags = {
    Name = "RHEL 9.7"
  }
}
```

> Instance types can be reviewed at **EC2 → Instance Types**. `t2.micro` costs approximately **$0.02/hr** for Windows and **$0.03/hr** for Linux.

---

## Step 4: Configure the VPC and Networking (`vpc.tf`)

The network architecture includes:

| Component | Purpose |
|-----------|---------|
| VPC | Isolated virtual network |
| Subnet | Sub-network where instances reside |
| Internet Gateway | Bridge between VPC and the internet |
| Route Table | Directs all traffic through the gateway |
| Route Table Association | Links the subnet to the route table |

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# Shared Subnet
resource "aws_subnet" "shared_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Route Table Association
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.shared_subnet.id
  route_table_id = aws_route_table.main.id
}
```

**Network breakdown:**
- VPC CIDR `10.0.0.0/16` — provides 65,536 private IP addresses (`10.0.0.0` – `10.0.255.255`)
- Subnet CIDR `10.0.1.0/24` — provides 256 private IP addresses (`10.0.1.0` – `10.0.1.255`)
- `map_public_ip_on_launch = true` — automatically assigns a public IP to every instance launched in this subnet
- `enable_dns_hostnames = true` — enables AWS-provided DNS hostnames (e.g., `ec2-xx-xx-xx-xx.compute.amazonaws.com`)

---

## Step 5: Configure Security Groups (`security.tf`)

> The following configuration opens **all ports and protocols** for lab/testing purposes. Do **not** use this in production.

```hcl
# Security Group
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.main.id
}

# Inbound Rules
resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Outbound Rules
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

---

## Step 6: Deploy the Infrastructure

### Initialize Terraform

```bash
terraform init
```

### Preview the Plan

```bash
terraform plan
```

Review the output for any errors. Common issues encountered and their fixes:

| Error | Fix |
|-------|-----|
| Hyphenated resource names (e.g., `aws-vpc`) | Use underscores: `aws_vpc` |
| `security_group_ids` not in brackets | Wrap in square brackets: `[aws_security_group.allow_all.id]` |
| AMI query returns no results | Verify owner ID matches the correct AMI |
| Invalid key pair name | Ensure key pair name in AWS matches exactly |

### Apply the Configuration

```bash
terraform apply --auto-approve
```

---

## Step 7: Verify the Instances

Once provisioned, navigate to **EC2 → Instances** in the AWS Console. You should see:

- `Windows Server 2019` — running
- `RHEL 9.7` — running

Both instances will be in the **same subnet**, confirming they can communicate with each other.

---

## Step 8: Connect to the Instances

### Connecting to RHEL 9.7 via SSH

1. Open a terminal and navigate to the directory containing the `.pem` file:

```bash
cd ~/Downloads
```

2. Connect via SSH:

```bash
ssh -i "terraform_key.pem" ec2-user@<RHEL_PUBLIC_IP>
```

> On Linux, you may need to set file permissions first: `chmod 400 terraform_key.pem`

3. Verify the OS:

```bash
cat /etc/redhat-release
```

Expected output includes: `Red Hat Enterprise Linux 9.7`

### Connecting to Windows Server 2019 via RDP

1. In the AWS Console, select the Windows instance and click **Connect**
2. Go to the **RDP Client** tab and click **Get Password**
3. Upload the `.pem` file and click **Decrypt Password**
4. Download **Remote Desktop Protocol (RDP)** file
5. Open **Remote Desktop Protocol (RDP)** file
6. Copy / paste the **username** and decrypted **password** from AWS
7. Accept the certificate prompts

You will be logged into the **Windows Server 2019 Datacenter** GUI with **Server Manager** available to use, confirming a successful connection.
---

## Summary

| Resource | Details |
|----------|---------|
| Provider | AWS (`us-east-1`) |
| Windows Instance | Windows Server 2019 Base, `t2.micro` |
| Linux Instance | RHEL 9.7, `t2.micro` |
| VPC CIDR | `10.0.0.0/16` |
| Subnet CIDR | `10.0.1.0/24` |
| Key Pair | `terraform_key` (RSA / .pem) |
| Security | All ports open (lab only) |

---

## File Structure

```
terraform/
├── main.tf          # Provider configuration
├── ami.tf           # AMI data sources
├── instances.tf     # EC2 instance definitions
├── vpc.tf           # VPC, subnet, gateway, routing
├── security.tf      # Security groups and rules
└── notes.txt        # AMI IDs and owner IDs reference
```

---

## Next Steps

- Install **Active Directory Domain Services (AD DS)** on the Windows Server instance
- Promote the server to a **Domain Controller**
- Join the RHEL 9.7 machine to the Active Directory domain using `realm join`
- Configure authentication via **SSSD** on RHEL for AD login
