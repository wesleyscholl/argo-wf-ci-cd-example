# Argo Workflows - CI/CD Example

## Table of Contents

 ### [Configuration](#configuration-1)
- [GitHub Webhooks Configuration](#gitHub-webhooks-configuration)
- [Two methods to trigger workflows using webhooks](#two-methods-to-trigger-workflows-using-webhooks)
  - [`WorkflowEventBinding`](#workfloweventbinding) 
  - [Argo Events](#argo-events)
- [Testing the configuration](#testing-the-configuration)

### [CI](#ci-1)
- [Cloning and Building the Argo CLI](#cloning-and-building-the-argo-cli)
- [Creating a build images and pushing to docker hub image registry](#creating-a-build-images-and-pushing-to-docker-hub-image-registry)
- [Running unit tests, coverage and collect test reports](#running-unit-tests-coverage-and-collect-test-reports)
- [Create cluster and deploy](#create-cluster-and-deploy)

### [CD](#cd-1)
- [Tag and push tag](#tag-and-push-tag)
- [Update deployment manifests using `kustomize edit set image`](#update-deployment-manifests-using-kustomize-edit-set-image)
- [Commit deployment manifests](#commit-deployment-manifests)
- [GitHub PAT commit/push secret configuration](#github-pat-commitpush-secret-configuration)
- [ArgoCD Configuration](#argocd-configuration)
- [Start Argo CD sync step](#start-argo-cd-sync-step)

<br>

# Configuration

## GitHub Webhooks Configuration

- Follow this guide: https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks
- GitHub Event Source Reference: https://argoproj.github.io/argo-events/eventsources/setup/github/

## Two methods to trigger workflows using webhooks

### `WorkflowEventBinding`

Uses the `/api/v1/events/{namespace}/{discriminator}` API endpoint and submits a `WorkflowTemplate` or `ClusterWorkflowTemplate`.

To setup `WorkflowEventBinding`: https://argo-workflows.readthedocs.io/en/latest/events/

Example `WorkflowEventBinding` - [WorkflowEventBinding.yaml](WorkflowEventBinding.yaml)


### `WorkflowEventBinding` Role

RBAC permissions required to submit workflows using the `WorkflowEventBinding`.

Example `WorkflowEventBinding` Role - [WorkflowEventBindingRole.yaml](WorkflowEventBindingRole.yaml)

### Argo Events

Uses a event source endpoint, sensor and trigger to submit a `WorkflowTemplate` or `ClusterWorkflowTemplate`.

To setup Argo Events: https://argoproj.github.io/argo-events/quick_start/


### Event source - GitHub push event

- Example `EventSource` - [EventSourceWebHook.yaml](EventSourceWebHook.yaml)


- Webhook Endpoint URL:
`https://<argo-workflows-url>/example:12000`

### Sensor and Trigger for `WorkflowTemplate`

- Example `Sensor` - [SensorTrigger.yaml](SensorTrigger.yaml)


## `ServiceAccount`, `Role` and `RoleBinding` Configuration

A service account is required to create workflows from the trigger and operate the CI/CD workflows. 

See the yaml configuration here: [ServiceAccountRoleBindingRole](ServiceAccountRoleBindingRole.yaml) 

## Testing the configuration

Both configurations can be tested using a curl command:

```bash
curl -d '{"message":"Trigger CI/CD"}' -H "Content-Type: application/json" -X POST http://<Deployed-Argo-Application-Url>:12000/example 
```

# CI

## Cloning and Building the Argo CLI

## Creating a build images and pushing to docker hub image registry

## Docker Configuration

> [!NOTE]  
> Publishing docker images requires a personal access token. For Docker Hub you can create one at https://hub.docker.com/settings/security
> This needs to be mounted as a secret `$DOCKER_CONFIG/config.json`. To create a secret:
```shell
# Add this to your .bash_profile, .zshrc or shell configuration
export DOCKER_USERNAME=****** 
export DOCKER_TOKEN=******

# Create the Kubernetes secret - add -n <namespace> for a specific namespace
kubectl create secret generic docker-config --from-literal="config.json={\"auths\": {\"https://index.docker.io/v1/\": {\"auth\": \"$(echo -n $DOCKER_USERNAME:$DOCKER_TOKEN|base64)\"}}}"
```

## Running unit tests, coverage and collect test reports

## Create cluster and deploy


# CD

## Tag and push tag

## Update deployment manifests using `kustomize edit set image`

## Commit deployment manifests

## GitHub PAT commit/push secret configuration

A GitHub Personal Access Token is required to add, commit and push the new Kustomize image tags to the remote repo.

```bash
kubectl create secret generic github-token --from-literal=token=<Your_GitHub_PAT> -n argo
```

The token will now be be passed as an evironment variable in the git commit/push step in the CD workflow.


 ## ArgoCD Configuration

 Configuration is required to connect to the ArgoCD server.

 If you don't have ArgoCD installed, install it: https://argo-cd.readthedocs.io/en/latest/getting_started/

 > NOTE
 > This example is insecure, ensure the intial password is changed and setup additional security and auth. For more info: https://argo-cd.readthedocs.io/en/latest/operator-manual/security/ 

Ensure to port forward the ArgoCD server and retrieve the admin login password.

```shell
kubectl port-forward svc/argocd-server -n argocd 8080:443

argocd admin initial-password -n argocd
abc..........xyz

This password must be only used for first time login. We strongly recommend you update the password using `argocd account update-password`.
```

## Start Argo CD sync step

---

docs: Add CI/CD example for building Argo Workflows. Closes #8591

This commit introduces a detailed example for implementing CI/CD pipelines to build Argo Workflows using Argo Workflows:

- **CI**: Includes steps for initializing builds via webhook, building the CLI, using Buildkit for image builds, running tests, collecting coverage reports, deploying to a cluster, and executing basic E2E tests.
- **CD**: Covers tagging, updating manifests with kustomize, committing updates, and initiating an Argo CD sync.
- **Pipeline**: Integrates CI and CD jobs with an approval step.

Signed-off-by: Wesley Scholl <wscholl@totalwine.com>
