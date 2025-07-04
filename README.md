# Cortex Cloud Workload Estimator

!!!! NOT OFFICIALL !!!!

**[Link to Workload Calculator](https://abuslang.github.io/cortex-cloud-license-helper/)**

## Overview

This tool provides an estimate of the Cortex Cloud licenses required for a given cloud environment. It consists of two components:

1.  An **Online Estimator**: A web-based interface for manually entering asset counts and calculating the total workload.
2.  An **AWS Inventory Script**: A shell script that automates the discovery of billable assets within an AWS account.

**Disclaimer**: This tool is intended for estimation purposes only. Please consult official Palo Alto Networks documentation or representatives for precise licensing information.

---

## AWS Asset Inventory Script (`aws_inventory.sh`)

Shell script to query the AWS and Azure APIs to count resources across all enabled regions. Download the .sh file and run in your cloudshell.

### Prerequisites

- **AWS Command Line Interface (CLI)**: The script requires the AWS CLI to be installed and configured with valid credentials. See the [official installation guide](https://aws.amazon.com/cli/).

### Required IAM Permissions

Permissions used:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "ec2:DescribeRegions",
                "ec2:DescribeInstances",
                "ecs:ListClusters",
                "ecs:ListTasks",
                "lambda:ListFunctions",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "rds:DescribeDBInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

### Usage

1.  **Set Executable Permissions**:
    ```bash
    chmod +x aws_inventory.sh
    ```
2.  **Run the Script**:
    ```bash
    ./aws_inventory.sh
    ```
The script will output a summary of discoverable assets. Copy these values into the web estimator.

### Cost

Running the `aws_inventory.sh` script does not incur any direct costs. The script exclusively uses read-only API calls (`describe-*`, `list-*`) that are included within the AWS Free Tier and are not billable for standard usage. The script does not create, modify, or enable any billable AWS resources.

### Script Limitations
- The script cannot automatically distinguish between VMs running containers and those that are not. You must manually allocate the total EC2 instance count between the two relevant categories in the estimator.
- **SaaS Users** and **Cloud ASM - Unmanaged Services** are not automatically discoverable and must be entered manually based on your organization's data.
- The script reports **DBaaS** storage in Gigabytes (GB). Divide this number by 1024 to convert it to Terabytes (TB) before entering it into the estimator.

---

## Self-Hosting

The web estimator is a static application built with HTML, CSS, and vanilla JavaScript. To host it yourself, serve the `index.html`, `styles/style.css`, and `scripts/main.js` files from any static web hosting provider, such as GitHub Pages, AWS S3, or Netlify.
