include envfile

.DEFAULT_GOAL := help

.SUBSCRIPTION_ID := ${SUBSCRIPTION_ID}
.READ_TOKEN := ${READ_TOKEN}
.REGISTRY_NAME := hmctssandbox

.taskName := retag-task
.imageName := hmcts/hello-world
.imageTag := aat
.registryHost := $(.REGISTRY_NAME).azurecr.io

.PHONY: help ## Display help section
help:
	@echo ""
	@echo "  Available targets:"
	@echo ""
	@grep -E '^\.PHONY: [a-zA-Z_-]+ .*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "(: |##)"}; {printf "\033[36m\t%-30s\033[0m %s\n", $$2, $$3}'
	@echo ""

.PHONY: app-image ## Create new image with random content in ACR
app-image:
	# update Dockerfile content with random content
	echo "FROM alpine:3.9\nCMD echo $(shell ./bin/random 10)\n" > Dockerfile
	# (re)create image
	az acr build \
		--subscription $(.SUBSCRIPTION_ID) \
		--registry $(.REGISTRY_NAME) \
		-t $(.imageName):$(.imageTag) \
		.

.PHONY: re-tag ## Manually re-tag the app image
re-tag:
	az acr import \
		--subscription $(.SUBSCRIPTION_ID) \
		-n $(.REGISTRY_NAME) \
		--source $(.registryHost)/$(.imageName):$(.imageTag) \
		-t $(.imageName):$(.imageTag)_$(shell ./bin/random 64)	

.PHONY: list-tasks ## List tasks in the registry
list-tasks:
	az acr task list \
		--registry $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID)

.PHONY: task ## Create a re-tag task
task:
	az acr task create \
		--subscription $(.SUBSCRIPTION_ID) \
		--context https://github.com/slyg/azure-acr-retag-task \
		--git-access-token $(.READ_TOKEN) \
		--file retag.Dockerfile \
		--name $(.taskName) \
		--arg imageName=$(.imageName) \
		--arg registry=$(.registryHost) \
		--arg imageTag=$(.imageTag) \
		--registry $(.REGISTRY_NAME) \
		--base-image-trigger-enabled true \
		--base-image-trigger-name $(.registryHost)/$(.imageName):$(.imageTag) \
		--base-image-trigger-type All \
		-t $(.registryHost)/$(.imageName):$(.imageTag)_{{.Run.ID}}

.PHONY: task-remove ## Remove the re-tag task
task-remove:
	az acr task delete \
		--subscription $(.SUBSCRIPTION_ID) \
		--name $(.taskName)

.PHONY: task-trigger ## Manually trigger the task
task-trigger:
	az acr task run \
		-n $(.taskName) \
		--registry $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID)

.PHONY: task-logs ## Logs of the task
task-logs:
	az acr task logs \
		--subscription $(.SUBSCRIPTION_ID) \
		--name $(.taskName)

.PHONY: repository-clean ## Remove non-latest images from the registry
repository-clean:
	az acr repository show-manifests \
		--name $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID) \
		--repository $(.imageName) \
		--query "[?tags[0] != '$(.imageTag)'].digest" \
		-o tsv \
		| xargs -I% az acr repository delete \
			--name $(.REGISTRY_NAME) \
			--subscription $(.SUBSCRIPTION_ID) \
			--image $(.imageName)@% \
			--yes

.PHONY: repository-list ## List the available tags in the repository
repository-list:
	az acr repository show-tags \
		--name $(.REGISTRY_NAME) \
		--repository $(.imageName) \
		--subscription $(.SUBSCRIPTION_ID)

.PHONY: clean ## Clean all
clean: repository-clean task-remove
	az acr repository delete \
		--name $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID) \
		--repository $(.imageName) \
		--yes
