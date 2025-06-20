# Cortex Cloud License Helper

This project provides a web-based tool to help users estimate the number of Cortex Cloud licenses required for their cloud environment based on a set of defined asset categories. It also includes an optional AWS inventory script to automate the collection of asset data from an AWS account.

## Features

- **Simple Web Interface**: A clean, single-page UI to manually enter asset counts.
- **Real-Time Calculation**: License estimates update instantly as you type.
- **AWS Inventory Script**: A shell script to automatically gather asset counts from your AWS account.
- **GitHub Pages Ready**: The web tool is built with HTML, CSS, and vanilla JavaScript, ready for easy deployment.

---

## Web-Based License Estimator

The core of this project is a static web page that allows you to calculate your required Cortex Cloud workloads based on your asset inventory.

### How to Use

1.  **Open `index.html`**: Open the `index.html` file in any modern web browser.
2.  **Enter Asset Counts**: Fill in the input fields for each asset category based on your cloud environment.
3.  **View Results**: The "Estimated Workloads" will be calculated and displayed automatically at the bottom of the page.

The tool calculates workloads based on the following logic, rounding up to the nearest whole number for each category:
- **VMs**: 1 workload per VM.
- **CaaS**: 1 workload per 10 managed containers.
- **Serverless Functions**: 1 workload per 25 functions.
- **Container Images**: 1 workload per 10 scans beyond the free quota.
    - *Free Quota*: 10 free scans per deployed VM and CaaS workload.
- **Cloud Buckets**: 1 workload per 10 buckets.
- **PaaS Databases**: 1 workload per 2 PaaS databases.
- **DBaaS**: 1 workload per 1 TB of stored data.
- **SaaS Users**: 1 workload per 10 SaaS users.
- **Cloud ASM**: 1 workload per 4 unmanaged assets.

### Deployment

This tool is designed to be hosted on any static web hosting service, such as GitHub Pages. Simply commit the files (`index.html`, `styles/style.css`, `scripts/main.js`) to your repository and configure it to serve from the `main` branch.

---

## AWS Inventory Script (`aws_inventory.sh`)

To accelerate the data gathering process for AWS users, this repository includes a shell script (`aws_inventory.sh`) that queries your AWS environment and outputs the asset counts needed for the estimator.

### Prerequisites

Before running the script, you must have the following installed and configured:
1.  **AWS CLI**: [Installation Guide](https://aws.amazon.com/cli/)
2.  **jq**: [Installation Guide](https://stedolan.github.io/jq/download/) (A command-line JSON processor)

### How to Run

1.  **Make the script executable**:
    ```bash
    chmod +x aws_inventory.sh
    ```
2.  **Run the script**:
    ```bash
    ./aws_inventory.sh
    ```
The script will query all enabled AWS regions and print a summary of discoverable assets. You can then copy and paste these values into the web estimator.

### Important Notes
- The script cannot automatically distinguish between VMs running containers and those that are not. You must manually allocate the total EC2 count between the two categories.
- SaaS Users and Cloud ASM assets are not discoverable via the AWS API and must be entered manually.

### Required IAM Permissions

The script requires an IAM user or role with read-only permissions for the services it queries. You can either attach the AWS managed policy `ReadOnlyAccess` or create a custom, least-privilege policy with the following JSON:

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