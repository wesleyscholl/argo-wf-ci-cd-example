# Argo Workflows - CI/CD Example


## Table of Contents

- [GitHub Webhooks Configuration](#gitHub-webhooks-configuration)
- [Two methods to trigger workflows using webhooks](#two-methods-to-trigger-workflows-using-webhooks)
  - [`WorkflowEventBinding`](#workfloweventbinding) 
  - [Argo Events](#argo-events)
- [Testing the configuration](#testing-the-configuration)
- [Cloning and Building the Argo CLI](#cloning-and-building-the-argo-cli)
- [Creating a build images and pushing to docker hub image registry](#creating-a-build-images-and-pushing-to-docker-hub-image-registry)
- [Running unit tests, coverage and collect test reports](#running-unit-tests-coverage-and-collect-test-reports)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)


## GitHub Webhooks Configuration

Follow this guide: https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks
GitHub Event Source Reference: https://argoproj.github.io/argo-events/eventsources/setup/github/

## Two methods to trigger workflows using webhooks

### `WorkflowEventBinding`

Uses the `/api/v1/events/{namespace}/{discriminator}` API endpoint and submits a `WorkflowTemplate` or `ClusterWorkflowTemplate`.

To setup `WorkflowEventBinding`: https://argo-workflows.readthedocs.io/en/latest/events/

Example `WorkflowEventBinding`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowEventBinding
metadata:
  name: event-consumer
  namespace: argo-events
spec:
  event:
    selector: payload.repo != "" && payload.branch != "" # To evaluate properties and values within the payload
  submit:
    workflowTemplateRef:
      name: buildkit # Name of the WorkflowTemplate to trigger
    arguments:
      parameters: # Parameters to pass to the WorkflowTemplate
        - name: repo
          valueFrom:
            event: payload.repository.html_url # GitHub url
        - name: branch
          valueFrom:
            event: payload.ref # GitHub ref branch
```





### Argo Events

Uses a event source endpoint, sensor and trigger to submit a `WorkflowTemplate` or `ClusterWorkflowTemplate`.

To setup Argo Events: https://argoproj.github.io/argo-events/quick_start/


### Event source - GitHub push event

- Example `EventSource`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook 
  namespace: argo-events 
spec:
  service: 
    ports:
      - port: 12000 # Configuring the service port to 12000
        targetPort: 12000 # Configuring the service target port to 12000
  webhook:
    example: # Name of webhook event
      endpoint: /example # Endpoint url suffix
      method: POST # HTTP Method - POST to send request data 
      port: "12000" # Assigning the port for the webhook
```




- Webhook Endpoint URL:
`https://<argo-workflows-url>/example:12000`

### Sensor and Trigger for `WorkflowTemplate`

- Example `Sensor`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook
  namespace: argo-events # Ensure namespaces match
spec:
  dependencies:
    - name: test-dep # Dependency for the sensor
      eventSourceName: webhook # Event Source
      eventName: example # Name of the webhook event
  triggers:
    - template:
        name: webhook-workflow-trigger # Trigger Name
        k8s:
          source:
            resource: # Specifying the resource
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ci-workflow-
              spec:
                arguments:
                  parameters:
                    - name: repo # Parameters to pass to pass to the WorkflowTemplate
                    - name: branch
                workflowTemplateRef:
                  name: ci-workflow # Name of the WorkflowTemplate
          operation: create # Creates the workflow when triggered
          parameters:
            - src:
                dependencyName: test-dep # Dependency name
                dataKey: body.repository.html_url # Selector for request body data
              dest: spec.arguments.parameters.0.value # Destination for data selection
            - src:
                dependencyName: test-dep
                dataKey: body.ref
              dest: spec.arguments.parameters.1.value
  template:
    serviceAccountName: operate-workflow-sa # Service account to use - Required to submit workflows
```

## Testing the configuration

Both configurations can be tested using a curl command:

```bash
curl -d '{"message":"Trigger CI/CD"}' -H "Content-Type: application/json" -X POST http://<Deployed-Argo-Application-Url>:12000/example 
```

## Cloning and Building the Argo CLI

Within the CI workflow we start by cloning the Argo Workflows repo then build the Argo CLI. 

```yaml
    - name: clone-repo
      inputs:
        parameters:
          - name: repo
          - name: branch
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: alpine/git:v2.26.2
        args:
          - clone
          - '--depth'
          - '1'
          - '--branch'
          - '{{=sprig.trimPrefix("refs/heads/",inputs.parameters.branch)}}' # Trims 'refs/heads/main' from the webhook payload to the 'main' branch 
          - '--single-branch'
          - '{{inputs.parameters.repo}}' # https://github.com/argoproj/argo-workflows
          - .
        workingDir: /work
        resources: {}
        volumeMounts: # Sharing the volume between steps, where the repo is cloned
          - name: work
            mountPath: /work

    - name: build-cli
      inputs:
        parameters:
          - name: path
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: golang:1.23
        command:
          - sh
          - '-c'
        args: 
          - |
            echo 'Building Argo CLI...'
            apt-get update 
            # Installs curl, node and yarn dependencies
            apt-get install -y curl
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs 
            npm install -g yarn@latest
            cd /work
            # Build the Argo CLI
            make cli STATIC_FILES=false
            if [ -f /work/dist/argo ]; then
              echo 'Argo CLI build successful.'
            else
              echo 'Argo CLI build failed.'
              exit 1
            fi
            # Echo filepath of the CLI binary
            echo /work/dist/argo
            echo 'Argo CLI build complete'
        workingDir: /work/
        env:
          - name: GO111MODULE # Build fails if set to 'off'
            value: 'on'
        resources:
          requests: # Adjust as needed
            cpu: '4'
            memory: 4Gi
        volumeMounts: # Shared volume
          - name: work
            mountPath: /work
```

## Creating a build images and pushing to docker hub image registry

```yaml
    - name: create-image
      inputs:
        parameters:
          - name: path
          - name: image
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: moby/buildkit:v0.9.3-rootless
        command:
          - buildctl-daemonless.sh
        args:
          - build
          - '--frontend'
          - dockerfile.v0
          - '--local'
          - context=.
          - '--local'
          - dockerfile=.
          - '--output'
          - type=image,name=docker.io/{{inputs.parameters.image}},push=true # Creates an image and pushes
        workingDir: /work/
        env:
          - name: BUILDKITD_FLAGS
            value: '--oci-worker-no-process-sandbox'
          - name: DOCKER_CONFIG # Pass in the docker config as an environment variable
            value: /.docker
        resources: # Adjust as needed
          requests:
            cpu: '3'
            memory: 6Gi
        volumeMounts:
          - name: work # Shared volume
            mountPath: /work
          - name: docker-config # Ensure to mount this volume
            mountPath: /.docker # Using this mount path
        readinessProbe:
          exec:
            command:
              - sh
              - '-c'
              - buildctl debug workers
      volumes:
        - name: docker-config # Ensure this volume is configured
          secret:
            secretName: docker-config # This secret holds the API key to your Docker registry
```

Publishing docker images requires a personal access token. For Docker Hub you can create one at https://hub.docker.com/settings/security
This needs to be mounted as a secret `$DOCKER_CONFIG/config.json`. To create a secret:
```shell
# Add this to your .bash_profile, .zshrc or shell configuration
export DOCKER_USERNAME=****** 
export DOCKER_TOKEN=******

# Create the Kubernetes secret - add -n <namespace> for a specific namespace
kubectl create secret generic docker-config --from-literal="config.json={\"auths\": {\"https://index.docker.io/v1/\": {\"auth\": \"$(echo -n $DOCKER_USERNAME:$DOCKER_TOKEN|base64)\"}}}"
```

## Running unit tests, coverage and collect test reports

```yaml
    - name: run-tests
      inputs:
        parameters:
          - name: path
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: golang:1.23
        command:
          - sh
          - '-c'
        args:
          - >
            # Run unit tests with and collect report
            echo 'Running unit tests...' 
            make test STATIC_FILES=false GOTEST='go test -p 20 -covermode=atomic -coverprofile=coverage.out'
            if [ -f /work/coverage.out ]; then
              echo 'Unit tests passed.'
            else
              echo 'Unit tests failed.'
              exit 1
            fi echo 'Unit tests completed.'
        workingDir: /work/
        resources:
          requests: # Adjust as needed
            cpu: '3'
            memory: 6Gi
        volumeMounts:
          - name: work # Shared volume
            mountPath: /work
    - name: run-coverage
      inputs:
        parameters:
          - name: path
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: golang:1.23
        command:
          - sh
          - '-c'
        args:
          - |
            # Run coverage and collect test coverage
            echo 'Collecting code coverage...'
            make coverage STATIC_FILES=false go tool cover -func=coverage.out
            if [ -f /work/coverage.out ]; then
              echo 'Coverage report collected.'
            else
              echo 'Coverage report failed.'
              exit 1
            fi
            echo 'Coverage report collected.'
        workingDir: /work/
        resources: # Adjust as needed
          requests:
            cpu: '3'
            memory: 6Gi
        volumeMounts:
          - name: work # Shared volume
            mountPath: /work
```