Azure DevOps & Platform Engineering Project

1. Project Overview

This repository demonstrates an end-to-end Azure Cloud Infrastructure and DevOps automation project using Terraform, GitHub Actions, Azure OIDC authentication and Infrastructure as Code (IaC).

The objective is to build a secure, scalable and modular Azure platform following Hub-Spoke network architecture and Azure Landing Zone principles.

Technology Stack

Category

Technologies

Cloud Platform

Microsoft Azure

Infrastructure as Code

Terraform

Source Control

Git, GitHub

CI/CD

GitHub Actions

Authentication

Azure OIDC / Workload Identity Federation

Container Platform

Azure Kubernetes Service (AKS)

Container Registry

Azure Container Registry (ACR)

Networking

Azure VNet, Subnets, NSG, Route Tables, VNet Peering

Security

Azure Firewall, Bastion, Key Vault, RBAC

Monitoring

Azure Monitor, Log Analytics

GitOps

ArgoCD

2. Project Architecture

The infrastructure follows a Hub-Spoke network architecture.

Hub Network

Resource Group: rg-network-dev

Virtual Network: vnet-hub-dev

Address Space: 10.0.0.0/16

AzureBastionSubnet: 10.0.2.0/26

AzureFirewallSubnet: 10.0.1.0/26

Spoke Network

Resource Group: rg-platform-dev

Virtual Network: vnet-spoke-dev

Address Space: 10.1.0.0/16

Spoke Subnets

Subnet

Address Range

Purpose

snet-aks

10.1.0.0/22

AKS workloads

snet-appgw

10.1.4.0/24

Application Gateway

snet-private

10.1.5.0/24

Private Endpoints

snet-workloads

10.1.6.0/24

Application workloads

Network Connectivity

Hub-to-Spoke VNet Peering

Spoke-to-Hub VNet Peering

Network Security Group association

Route Table association

3. Successfully Deployed Infrastructure

Deployment Status: Successful

Terraform Apply completed successfully through GitHub Actions.

Resource

Azure Resource Name

Status

Hub Resource Group

rg-network-dev

Created

Spoke Resource Group

rg-platform-dev

Created

Hub VNet

vnet-hub-dev

Created

Spoke VNet

vnet-spoke-dev

Created

Hub Subnets

AzureBastionSubnet, AzureFirewallSubnet

Created

Spoke Subnets

AKS, App Gateway, Private, Workloads

Created

Network Security Group

nsg-workloads-dev

Created

Route Table

rt-workloads-dev

Created

Hub-to-Spoke Peering

peer-hub-to-spoke

Created

Spoke-to-Hub Peering

peer-spoke-to-hub

Created

NSG Association

Workloads subnet

Created

Route Table Association

Workloads subnet

Created

Terraform Apply Result

Apply complete!

Resources: 16 added, 0 changed, 0 destroyed.

Terraform Plan Result

Plan: 16 to add, 0 to change, 0 to destroy.

4. Terraform Remote State Management

Terraform remote state is maintained in Azure Storage Account.

Configuration

Value

Resource Group

rg-tfstate-devops

Storage Account

stmakrdevops001

Container

tfstate

State File

dev.terraform.tfstate

Backend authentication uses Azure AD and OIDC.

The GitHub Actions identity requires appropriate Storage Blob Data Contributor permissions on the state storage account.

5. GitHub Actions CI/CD

Two separate workflows are used to validate and deploy infrastructure.

Terraform Plan Workflow

File: .github/workflows/terraform-plan.yml

Responsibilities:

Checkout GitHub repository.

Authenticate to Azure using OIDC.

Set up Terraform.

Check Terraform formatting.

Initialize Terraform backend.

Validate Terraform configuration.

Generate Terraform execution plan.

Triggers:

Pull requests affecting Terraform files.

Manual workflow dispatch.

Terraform Apply Workflow

File: .github/workflows/terraform-apply.yml

Responsibilities:

Checkout repository.

Authenticate to Azure using OIDC.

Initialize remote Terraform backend.

Validate Terraform configuration.

Generate Terraform execution plan.

Apply the saved execution plan.

Update Azure infrastructure.

Trigger:

Manual workflow dispatch.

GitHub Actions concurrency control prevents overlapping Terraform operations against the same Dev state.

6. Azure OIDC Authentication

GitHub Actions connects to Azure through Microsoft Entra ID Workload Identity Federation.

No client secret is required for this authentication method.

GitHub Repository Variables:

Variable

Description

ARM_CLIENT_ID

Azure application client ID

ARM_TENANT_ID

Microsoft Entra tenant ID

ARM_SUBSCRIPTION_ID

Azure subscription ID

TF_BACKEND_RESOURCE_GROUP

Terraform state resource group

TF_BACKEND_STORAGE_ACCOUNT

Terraform state storage account

TF_BACKEND_CONTAINER

Terraform state container

TF_BACKEND_KEY

Terraform state file key

Terraform receives the subscription ID through:

TF_VAR_subscription_id

Federated credentials are configured for the GitHub repository and the dev deployment environment.

7. Repository Structure

devops-project/
│
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
│
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── backend.tf
│   │       ├── backend.hcl
│   │       ├── providers.tf
│   │       ├── versions.tf
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── terraform.tfvars.example
│   │
│   └── modules/
│       ├── resource-group/
│       ├── network/
│       ├── nsg/
│       ├── route-table/
│       └── vnet-peering/
│
├── README.md
└── .gitignore

8. Planned Infrastructure Enhancements

The following services are planned for subsequent implementation stages.

Phase

Azure Service

Purpose

Phase 1

Hub-Spoke Networking

Completed

Phase 2

Azure Bastion

Secure administrative access

Phase 3

Azure Firewall

Network traffic inspection

Phase 4

Azure Container Registry

Container image management

Phase 5

Azure Kubernetes Service

Container orchestration

Phase 6

Azure Key Vault

Secrets and certificate management

Phase 7

Managed Identity

Passwordless Azure service authentication

Phase 8

Private Endpoints

Private service connectivity

Phase 9

Application Gateway

Application ingress and load balancing

Phase 10

Azure Monitor

Infrastructure monitoring

Phase 11

Log Analytics

Centralized log management

Phase 12

ArgoCD

Kubernetes GitOps deployment

9. Security and Best Practices

Use Azure OIDC instead of long-lived client secrets.

Maintain Terraform state in Azure Storage.

Apply least-privilege RBAC permissions.

Separate infrastructure by environment.

Use modular Terraform code.

Enable workflow concurrency to avoid state conflicts.

Keep passwords and credentials outside source control.

Review Terraform plans before applying infrastructure.

Use GitHub Environment approvals for deployments.

10. Project Outcome

Successfully established an Azure Hub-Spoke network foundation using Terraform and GitHub Actions.

The deployment demonstrates:

Infrastructure as Code implementation.

Azure resource provisioning through CI/CD.

GitHub-to-Azure OIDC authentication.

Terraform remote state management.

Modular infrastructure architecture.

Automated Plan and Apply workflows.

Azure networking and resource management.

Next Objective: Extend the existing network foundation into a complete Azure Platform Engineering environment with AKS, ACR, Azure Firewall, Bastion, Key Vault, private networking, monitoring and GitOps.

Project: Azure DevOps & Platform Engineering

Cloud: Microsoft Azure

IaC: Terraform

CI/CD: GitHub Actions

Repository: makrsoftitsolutions/devops-project
