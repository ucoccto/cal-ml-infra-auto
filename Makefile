TF = terraform -chdir=infra

.PHONY: init fmt validate plan apply output destroy deploy verify

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

plan:
	$(TF) plan

apply:
	$(TF) apply

output:
	$(TF) output

destroy:
	$(TF) destroy

deploy:
	./deploy.sh

verify:
	./local-tools/verify-environment.sh
