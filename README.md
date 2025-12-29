This repository contains examples and PoCs for configuring Azure and other cloud environments using Infrastructure as Code (IaC) tools such as Bicep, Terraform and Ansible.


- [Azure tenant bootstraps](./bootstrap/Azure/README.md)

### TBD

Create a resourceGroup and deployes two ACRs

```sh
az deployment sub create --template-file main.bicep --location "Australia East"
```

Create service principals

```sh
az ad app create --display-name sp-lz-terraform-01
```

Deployment stacks

```sh
az stack sub create --name lz-sa-terraform-state --template-file main.bicep -l australiaeast --dm None --subscription b63ed8a5-399c-4375-9365-9c5edb7deab7
```

# Known issue

* role assignment isn't working


* command below throwns an error
```
az stack sub create --name lz-sa-terraform-state --template-file main.bicep -l australiaeast --dm denyDelete --subscription b63ed8a5-399c-4375-9365-9c5edb7deab7
```
probles with 
```
--dm denyDelete
--action-on-unmanage deleteAll
```