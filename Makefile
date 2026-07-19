# Usage:
#   make init ENV=dev
#   make plan ENV=dev
#   make apply ENV=dev
#   make destroy ENV=dev

ENV ?= dev
TFVARS = environments/$(ENV)/terraform.tfvars
TFSTATE_KEY = nginx-frontend/$(ENV)/terraform.tfstate

.PHONY: init plan apply destroy fmt validate

init:
	terraform init \
	  -backend-config="key=$(TFSTATE_KEY)"

plan:
	terraform plan -var-file=$(TFVARS) -out=tfplan.$(ENV)

apply:
	terraform apply tfplan.$(ENV)

destroy:
	terraform destroy -var-file=$(TFVARS)

fmt:
	terraform fmt -recursive

validate:
	terraform validate
