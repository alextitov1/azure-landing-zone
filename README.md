
## About

This repository is a multi-cloud landing zone, modelled on a mid-size organization.

In a real company, cloud infrastructure is made of many connected parts. Different teams own different parts, and each comes with its own guardrails. Rebuilding even a small piece of this by hand is slow and hard.

I use this repository to prototype and test new ideas. The code is split the way a real organization splits ownership and duties, so experiments stay close to reality. The code lets me rebuild the environment quickly and with little effort.

Everything is written in Terraform. State lives in HCP Terraform, and its VCS integration deploys changes automatically.


## Links

- [HCP Terraform bootstrap](./bootstrap/HCP/README.md)

- [Azure tenant bootstrap](./bootstrap/Azure/README.md)
