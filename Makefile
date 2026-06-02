.PHONY: render validate

render:
	./scripts/render-charts.sh

validate:
	@for dir in infrastructure/*/overlays/dev; do \
		echo "kustomize build $$dir"; \
		kustomize build "$$dir" > /dev/null; \
	done
	@kustomize build infrastructure/namespaces > /dev/null
	@echo "OK"
