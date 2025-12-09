IMAGE ?= lukaszbielinski/leader-election-demo-go
TAG ?= latest
CONTAINER_ENGINE ?= $(shell command -v podman 2>/dev/null || echo docker)

.PHONY: build push deploy logs status failover cleanup

build:
	$(CONTAINER_ENGINE) build -t $(IMAGE):$(TAG) .

push: build
	$(CONTAINER_ENGINE) push $(IMAGE):$(TAG)

deploy:
	kubectl apply -f manifests.yaml

logs:
	kubectl logs -n leader-election-go -l app=leader-election-go -f --prefix

status:
	@echo "=== Lease ==="
	@kubectl get lease -n leader-election-go 2>/dev/null || echo "No lease"
	@echo "\n=== Pods ==="
	@kubectl get pods -n leader-election-go -l app=leader-election-go

failover:
	@LEADER=$$(kubectl get lease leader-election-demo -n leader-election-go -o jsonpath='{.spec.holderIdentity}' 2>/dev/null); \
	if [ -n "$$LEADER" ]; then \
		echo "Killing leader: $$LEADER"; \
		kubectl delete pod -n leader-election-go "$$LEADER" --force --grace-period=0; \
	else \
		echo "No leader found"; \
	fi

cleanup:
	kubectl delete namespace leader-election-go --ignore-not-found

