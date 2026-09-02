# Linux/macOS에서 자주 쓰는 Terraform 명령을 단순화한다.
.PHONY: init fmt validate plan apply output destroy

init:
	terraform init

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan:
	terraform plan

apply:
	terraform apply

output:
	terraform output

destroy:
	terraform destroy
