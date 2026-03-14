# ─── Multi-Cloud SOC Terraform — Makefile ────────────────────────────────────
# Usage:
#   make init    target=azure
#   make plan    target=azure
#   make deploy  target=azure
#   make destroy target=azure
#
#   make init    target=aws
#   make plan    target=aws
#   make deploy  target=aws
#   make destroy target=aws
#
# Prerequisites:
#   Azure: az login && set subscription_id in environments/azure/terraform.tfvars
#   AWS:   aws configure && set admin_ssh_public_key in environments/aws/terraform.tfvars

VALID_TARGETS := azure aws

# Validate that target is provided and is one of the valid options.
guard-target:
ifndef target
	$(error target is required. Usage: make <command> target=azure|aws)
endif
ifeq ($(filter $(target),$(VALID_TARGETS)),)
	$(error target must be one of: $(VALID_TARGETS))
endif

init: guard-target
	cd environments/$(target) && terraform init

validate: guard-target
	cd environments/$(target) && terraform validate

plan: guard-target
	cd environments/$(target) && terraform plan

deploy: guard-target
	cd environments/$(target) && terraform init && terraform apply

destroy: guard-target
	cd environments/$(target) && terraform destroy

fmt:
	terraform fmt -recursive

.PHONY: guard-target init validate plan deploy destroy fmt
