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
# For creating Konflux resources for OpenShift Builds Operator
export OPENSHIFT_BUILDS_VERSION="1.1"
make operator-release 

# For creating Konflux resources for OpenShift Builds Catalog
export OPENSHIFT_VERSION="4.15"
make catalog-release 
```
Set the release stream version accordingly.
This will create the `Application` with the following name.
- `openshift-builds-1-1`

and `Component` with the following names
- `openshift-builds-controller-1-1`
- `openshift-builds-operator-1-1`

and `ImageRepository` with the following names
- `openshift-builds-operator-1-1`
having URL `quay.io/redhat-user-workloads/rh-openshift-builds-tenant/openshift-builds-operator-1-1`

The components will be mapped to the application.

### Update Pipelines
This process doesn't create the tekton pipelines under the z-stream branch of the repository. Hence, konflux pipelines need to be copied or created there.
If the pipelines are copied from another branch update the following fields to map the correct application and components.

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

Update the `output-image` accordingly
quay.io/redhat-user-workloads/rh-openshift-builds-tenant/openshift-builds-fbc-4-12:on-pr-{{revision}}
```yaml
- name: output-image
  value: quay.io/redhat-user-workloads/rh-openshift-builds-tenant/openshift-builds-operator-1-1:on-pr-{{revision}}
```


