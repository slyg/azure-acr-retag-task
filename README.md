# ACR retag task

This repo experiments with different ways of re-tagging an ACR image.

## Abstract

The purpose of re-tagging images is related to the use of [Flux](https://github.com/weaveworks/flux) to handle k8s deployments (via AKS in HMCTS) driven by events. In our case, any image published with a given tag pattern on an ACR registry will be automatically (re)deployed .

e.g. `<my-app>:latest_<whatever-hash>`

## Choices

Several approaches regarding the current state of our infrastructure can be made:

1. From the existing pipeline, re-tagging an existing images tagged as `:latest`, this is the push approach, triggered by Jenkins alongside other steps.

2. Create an ACR task that automatically creates a new tagged image each time a `:latest` image is published in ACR, this is the event-driven approach

Theses choices can be experimented with the targets provided in the `Makefile`.

Notice that you may need to create an `envfile` file to make those scripts run locally.

## Experiments

### Push approach (Jenkins)

##### Example

You can create an image representing an application image using the following command:

```shell
$ make app-image
```

Each time you run this command you actually create a new version of your application, bundled as an image tagged as `:latest`.

From this on, you can experiment the push approach by manually triggering a re-tagging:

```shell
$ make re-tag
```

##### Discussion

| Advantages                             | Disadvantages                 |
| -------------------------------------- | ----------------------------- |
| Visible in the pipeline (traceability) | Constrained to Jenkins builds |
| Ability to opt-in/out                  |                               |

### ACR Event approach

##### Example

ACR allows you to create _tasks_ where you define a given process to happen on a given event.

In our case, the following command creates a re-tagging procedure each time the application image is pushed with the `:latest` tag:

You can start by creating this task:

```shell
$ make task
```

Verify that you can see your task using the following make commands and other convenient interations:

```
Available targets:

app-image                       Create new image with random content in ACR
clean                           Clean all
help                            Display help section
list-tasks                      List tasks in the registry
re-tag                          Manually re-tag the app image
repository-clean                Remove non-latest images from the registry
repository-list                 List the available tags in the repository
task                            Create a re-tag task
task-logs                       Logs of the task
task-remove                     Remove the re-tag task
task-trigger                    Manually trigger the task
```

Now you can create you image using the following command:

```shell
$ make app-image
```

You should the notice that an additional tag will be autimatically created in the registry.

##### Discussion

| Advantages                                                | Disadvantages                                                      |
| --------------------------------------------------------- | ------------------------------------------------------------------ |
| Opened to any way the images are updated                  | Awareness: the tasks are not easily visible if not well documented |
| Event-based so not preemptive on the way images are built | Tasks lifecycle to be handled correctly                            |

---

Other comnmands allow you update/remove the ACR task and to cleanup the registry.
