include envfile

.SUBSCRIPTION_ID := ${SUBSCRIPTION_ID}
.READ_TOKEN := ${READ_TOKEN}
.REGISTRY_NAME := hmctssandbox

.taskName := retag-task
.imageName := hmcts/hello-world
.registryHost := $(.REGISTRY_NAME).azurecr.io

re-tag:
	az acr import \
		--subscription $(.SUBSCRIPTION_ID) \
		-n $(.REGISTRY_NAME) \
		--source $(.registryHost)/$(.imageName):latest \
		-t $(.imageName):latest_$(shell cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)

base-image:
	# update Dockerfile content
	echo "FROM alpine:3.9\nCMD echo $(shell cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)\n" > Dockerfile
	# (re)create image
	az acr build \
		--subscription $(.SUBSCRIPTION_ID) \
		--registry $(.REGISTRY_NAME) \
		-t $(.imageName):latest \
		.

.task_parameters := \
	--subscription $(.SUBSCRIPTION_ID) \
	--context https://github.com/hmcts/cnp-acr-retag-task \
	--git-access-token $(.READ_TOKEN) \
	--file retag.Dockerfile \
	--name $(.taskName) \
	--arg imageName=$(.imageName) \
	--arg registry=$(.registryHost) \
	--registry $(.REGISTRY_NAME) \
	--base-image-trigger-enabled true \
	--base-image-trigger-type All \
	-t $(.registryHost)/$(.imageName):latest_{{.Run.ID}}

task:
	az acr task create $(.task_parameters)

task-update:
	az acr task update $(.task_parameters)

task-list:
	az acr task list \
		--registry $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID)

task-remove:
	az acr task delete \
		--subscription $(.SUBSCRIPTION_ID) \
		--name $(.taskName)

task-trigger:
	az acr task run \
		-n $(.taskName) \
		--registry $(.REGISTRY_NAME) \
		--subscription $(.SUBSCRIPTION_ID)

.PHONY: re-tag base-image task task-update task-list task-remove task-trigger
