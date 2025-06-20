# Cortex Cloud Workload Estimator

!!!! NOT OFFICIALL !!!!

**[Live Demo](https://abuslang.github.io/cortex-cloud-license-helper/)**

## Overview

This tool provides an estimate of the Cortex Cloud licenses required for a given cloud environment. It consists of two components:

1.  An **Online Estimator**: A web-based interface for manually entering asset counts and calculating the total workload.
2.  An **AWS Inventory Script**: A shell script that automates the discovery of billable assets within an AWS account.

**Disclaimer**: This tool is intended for estimation purposes only. Please consult official Palo Alto Networks documentation or representatives for precise licensing information.

---

## Online Estimator Usage

The estimator provides a user-friendly interface to calculate license needs.

#### Running Locally
1.  Clone or download this repository.
2.  Open the `index.html` file in a web browser.
3.  Input the quantity for each asset category based on your environment's inventory.
4.  The **Estimated Workloads** total will update in real-time at the bottom of the page.

---

## License Calculation Logic

The total workload is the sum of workloads calculated for each asset category. The calculation logic is as follows:

| Asset Category                      | Billable Unit per 1 Workload                                |
| ----------------------------------- | ----------------------------------------------------------- |
| VMs (not running containers)        | 1 VM                                                        |
| VMs (running containers)            | 1 VM                                                        |
| CaaS (Container as a Service)       | 10 Managed Containers                                       |
| Serverless Functions                | 25 Serverless Functions                                     |
| Container Images in Registries      | 10 additional scans*                                        |
| Cloud Buckets                       | 10 Cloud Buckets                                            |
| Managed Cloud Database (PaaS)       | 2 PaaS Databases                                            |
| DBaaS (Database as a Service)       | 1 TB Stored                                                 |
| SaaS Users                          | 10 SaaS Users                                               |
| Cloud ASM - Unmanaged Services      | 4 Unmanaged Assets                                          |

*\*A free quota of 10 container image scans is provided for each deployed VM and CaaS workload.*

---

## AWS Asset Inventory Script (`aws_inventory.sh`)

To automate asset discovery in AWS, a dedicated shell script is provided. It queries the AWS API to count resources across all enabled regions.

### Prerequisites

- **AWS Command Line Interface (CLI)**: The script requires the AWS CLI to be installed and configured with valid credentials. See the [official installation guide](https://aws.amazon.com/cli/).

### Required IAM Permissions

The script requires an IAM principal (user or role) with read-only permissions for the services it queries. While the AWS-managed `ReadOnlyAccess` policy is sufficient, the recommended approach is to use a custom policy with least-privilege permissions.

Create a new IAM policy with the following JSON definition:
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
