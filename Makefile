include envfile

.SUBSCRIPTION_ID := ${SUBSCRIPTION_ID}
.READ_TOKEN := ${READ_TOKEN}
.REGISTRY_NAME := hmctssandbox

.taskName := retag-task
.imageName := hmcts/hello-world
.imageTag := aat
.registryHost := $(.REGISTRY_NAME).azurecr.io

app-image:
	# update Dockerfile content with random content
	echo "FROM alpine:3.9\nCMD echo $(shell ./bin/random 10)\n" > Dockerfile
	# (re)create image
	az acr build \
		--subscription $(.SUBSCRIPTION_ID) \
		--registry $(.REGISTRY_NAME) \
		-t $(.imageName):$(.imageTag) \
		.

re-tag:
	az acr import \
		--subscription $(.SUBSCRIPTION_ID) \
		-n $(.REGISTRY_NAME) \
		--source $(.registryHost)/$(.imageName):$(.imageTag) \
		-t $(.imageName):$(.imageTag)_$(shell ./bin/random 64)	

list-tasks:
	az acr task list \
		--registry $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID)

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

task-remove:
	az acr task delete \
		--subscription $(.SUBSCRIPTION_ID) \
		--name $(.taskName)

task-trigger:
	az acr task run \
		-n $(.taskName) \
		--registry $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID)

task-logs:
	az acr task logs \
		--subscription $(.SUBSCRIPTION_ID) \
		--name $(.taskName)

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

repository-list:
	az acr repository show-tags \
		--name $(.REGISTRY_NAME) \
		--repository $(.imageName) \
		--subscription $(.SUBSCRIPTION_ID)

clean: repository-clean task-remove
	az acr repository delete \
		--name $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID) \
		--repository $(.imageName) \
		--yes

.PHONY: re-tag app-image task task-update task-list task-remove task-trigger clean-registry show-logs
