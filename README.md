# Openshift Builds Release Tooling
This repository contains the required manifests and tooling to support release for Builds for Red Hat OpenShift.

## Konflux
Currently, Konflux is being used to building the container, running tests and releasing.

To manage multiple versions of an application, Konflux features a template to create the required components in the platform. 

### Prerequisite 
- kubectl
- kustomize
- yq

### Setup
This will create the `Project`, `ProjectDevelopmentStreamTemplate`.
```shell
make setup
```

### Release
This will create the release stream definition, `ProjectDevelopmentStream`.
```shell
export OPENSHIFT_BUILDS_VERSION="1.1"
make release
```
Set the release stream version accordingly.
This will create the `Application` with the following name.
- `openshift-builds-1-1`

and the  `Components` with the following names
- `openshift-builds-controller-1-1`
- `openshift-builds-operator-1-1`

The components will be mapped to the application.

### Update Pipelines
This process doesn't create the tekton pipelines under the z-stream branch of the repository. Hence konflux pipelines 
needs to be copied or created there.
If the pipelines are copied from another branch update the following fields to map then the correct application and components.

Update the labels to point to the correct application and component
```yaml
labels:
    appstudio.openshift.io/application: openshift-builds-1-1
    appstudio.openshift.io/component: openshift-builds-operator-1-1
```

Update the branch to the current release branch.
```yaml
metadata:
  annotations:
    pipelinesascode.tekton.dev/on-cel-expression: event == "push" && target_branch == "builds-1.1"
```


