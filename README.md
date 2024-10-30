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
        - name: name
          valueFrom:
            event: payload.pusher.name # GitHub user name
        - name: email
          valueFrom:
            event: payload.pusher.email # GitHub user email
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
                    - name: name
                    - name: email
                workflowTemplateRef:
                  name: ci-workflow # Name of the WorkflowTemplate
          operation: create # Creates the workflow when triggered
          parameters:
            - src:
                dependencyName: test-dep # Dependency name
                dataKey: body.repository.html_url # Selector for request body data (Repo url)
              dest: spec.arguments.parameters.0.value # Destination for data selection
            - src:
                dependencyName: test-dep
                dataKey: body.ref # (Branch)
              dest: spec.arguments.parameters.1.value
            - src:
                dependencyName: test-dep
                dataKey: body.pusher.name # (User name)
              dest: spec.arguments.parameters.2.value
            - src:
                dependencyName: test-dep
                dataKey: body.pusher.email # (User email)
              dest: spec.arguments.parameters.3.value
  template:
    serviceAccountName: operate-workflow-sa # Service account to use - Required to submit workflows
```

## Testing the configuration

Both configurations can be tested using a curl command:

```bash
curl -d '{"message":"Trigger CI/CD"}' -H "Content-Type: application/json" -X POST http://<Deployed-Argo-Application-Url>:12000/example 
```

# CI

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
          - '{{=sprig.trimPrefix("refs/heads/",inputs.parameters.branch)}}' # Trims 'refs/heads/' from the webhook payload to the 'main' branch 
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

## Create cluster and deploy

```yaml
    - name: prepare-deploy-to-cluster
      inputs:
        parameters:
          - name: cli-image
          - name: exec-image
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: ubuntu:latest
        command:
          - sh
          - '-c'
        args:
          - >
            DEBIAN_FRONTEND=noninteractive 

            apt-get update

            # Install dependencies

            echo "Installing dependencies..."

            apt-get install -y curl apt-transport-https ca-certificates gnupg
            lsb-release sudo golang make socat

            echo "export PATH=$PATH:/usr/local/go/bin" | tee -a

            sudo apt-get install -y lsof

            # Test make command

            make --version

            # Install k3d

            echo "Installing k3d..."

            curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh
            | bash

            # Install kubectl

            echo "Installing kubectl..."

            curl -LO "https://dl.k8s.io/release/$(curl -L -s
            https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

            chmod +x kubectl

            mv kubectl /usr/local/bin/

            # Download and configure Docker

            echo "Downloading and configuring Docker..."

            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg
            --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

            echo "deb [arch=amd64
            signed-by=/usr/share/keyrings/docker-archive-keyring.gpg]
            https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
            | tee /etc/apt/sources.list.d/docker.list > /dev/null

            apt-get update && apt-get install -y docker-ce docker-ce-cli
            containerd.io

            # Wait for Docker 

            echo "Waiting for Docker daemon to be ready..."

            until docker info; do sleep 3; done

            echo "Docker daemon is ready. Running commands..."

            # Configure and increase docker ufile limits -
            /etc/docker/daemon.json

            echo "Configuring and increasing docker file limits..."

            echo '{ "default-ulimits": { "nofile": { "Name": "nofile", "Hard":
            1048576, "Soft": 1048576 } } }' | sudo tee /etc/docker/daemon.json

            # Confirm the docker ufile changes

            echo "Confirming the docker file limit changes..."

            cat /etc/docker/daemon.json

            # Restart Docker

            echo "Restarting Docker..."

            sudo systemctl restart docker 

            # Wait for Docker to be ready

            echo "Waiting for Docker daemon to be ready..."

            until docker info; do sleep 3; done

            # Pull the images from docker hub

            echo "Pulling images from docker hub..."

            docker pull {{inputs.parameters.exec-image}}

            docker pull {{inputs.parameters.cli-image}}

            docker images

            # Create k3d cluster

            echo "Creating k3d cluster..."

            k3d cluster create argocluster --kubeconfig-switch-context

            # Wait for k3d cluster to be ready

            echo "Waiting for k3d cluster to be ready..."

            until kubectl cluster-info; do sleep 3; done

            echo "k3d is ready. Running commands..."

            # Merge kubeconfig - set context to k3d cluster

            echo "Merging kubeconfig and switching context to k3d cluster..."

            k3d kubeconfig merge argocluster --kubeconfig-switch-context

            kubectl cluster-info

            kubectl version

            # Load the images into the k3d cluster

            echo "Loading images into k3d cluster..."

            docker save {{inputs.parameters.exec-image}} -o /tmp/argoexec.tar

            docker save {{inputs.parameters.cli-image}} -o /tmp/argocli.tar

            docker load < /tmp/argoexec.tar

            docker load < /tmp/argocli.tar

            # Set up the hosts file

            echo "Setting up the hosts file..."

            echo '127.0.0.1 dex'      | sudo tee -a /etc/hosts

            echo '127.0.0.1 minio'    | sudo tee -a /etc/hosts

            echo '127.0.0.1 postgres' | sudo tee -a /etc/hosts

            echo '127.0.0.1 mysql'    | sudo tee -a /etc/hosts

            echo '127.0.0.1 azurite'  | sudo tee -a /etc/hosts

            # Install manifests

            echo "Installing manifests..."

            make install PROFILE=minimal STATIC_FILES=false

            # Build workflow controller

            echo "Building workflow controller..."

            make controller kit STATIC_FILES=false

            # Ensure that pods are running

            echo "Checking that pods are running..."

            kubectl get pods -n argo

            # Build argo workflow CLI

            echo "Building argo workflow CLI..."

            make cli STATIC_FILES=false

            # Start argo workflow controller & API

            echo "Starting argo workflow controller & API..."

            make start PROFILE=mysql AUTH_MODE=client STATIC_FILES=false
            LOG_LEVEL=info API=true UI=false POD_STATUS_CAPTURE_FINALIZER=true >
            /tmp/argo.log 2>&1 &

            # Wait for argo workflow controller to be ready

            make wait PROFILE=mysql API=true  

            # Run E2E tests for CLI

            echo "Running E2E tests for CLI..."

            make test-cli E2E_SUITE_TIMEOUT=20m STATIC_FILES=false
        workingDir: /work/
        env: # env to connect to the docker sidecar
          - name: DOCKER_HOST
            value: tcp://localhost:2375
        resources: # Adjust as needed
          requests:
            cpu: '3'
            memory: 6Gi
        volumeMounts: # Shared volume
          - name: work
            mountPath: /work
      sidecars: # Docker dind sidecar
        - name: dind
          image: docker:20.10-dind
          env:
            - name: DOCKER_TLS_CERTDIR
          resources: {}
          securityContext:
            privileged: true # Required
          mirrorVolumeMounts: true
```

# CD

## Tag and push tag

## Update deployment manifests using `kustomize edit set image`

## Commit deployment manifests



## GitHub PAT commit/push secret configuration

A GitHub Personal Access Token is required to add, commit and push the new Kustomize image tags to the remote repo.

```bash
kubectl create secret generic github-token --from-literal=token=<Your_GitHub_PAT> -n argo
```

Then pass the token as an environment variable:

```yaml
      container:
        name: ''
        image: alpine/git:v2.26.2
        command:
          - sh
          - '-c'
        args:
          - >
            # Add git email and name
            git config --global user.email "128409641+wesleyscholl@users.noreply.github.com" 
            git config --global user.name "Wesley Scholl" 
            # Stage all files
            git add -A 
            # Commit staged files with commit-message parameter
            git commit -m "{{inputs.parameters.commit-message}}" 
            # Push to remote using GITHUB_TOKEN, repo and branch
            git push https://${GITHUB_TOKEN}@{{=sprig.trimPrefix("https://",workflow.parameters.repo)}}.git HEAD:{{=sprig.trimPrefix("refs/heads/",workflow.parameters.branch)}} 
        workingDir: /work
        env:
          - name: GITHUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: github-token
                key: token
```

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

```yaml
# ArgoCD Secret - server, username, password
apiVersion: v1
kind: Secret
metadata:
  name: argocd-env-secret # Name of secret
  namespace: argo # namespace
type: Opaque
stringData:
  server: <ArgoCD-Server-Deployment-Url> # Deployment URL
  username: admin # Admin username
  password: abc..........xyz # Admin password          
---
# NetworkPolicy for ArgoCD - Connects argo and argocd namespaces via Ingress for argocd-server
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-argocd-sync # Name of the NetworkPolicy
  namespace: argocd # Apply the NetworkPolicy to the ArgoCD namespace
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server # Select the ArgoCD server pod
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: argo # Allow traffic from the Argo namespace
  policyTypes:
  - Ingress # Only allow ingress traffic
---
# ArgoCD Service - Creates a service for the ArgoCD server to be accessed by the ArgoCD CLI
apiVersion: v1
kind: Service
metadata:
  name: argocd-server # Name of the service
  namespace: argocd # Apply the service to the argocd namespace
spec:
  ports:
  - name: http # Name of the port
    port: 80 # Port to expose
    targetPort: 8080 # Port to forward traffic to
  - name: https # Name of the port
    port: 443 # Port to expose
    targetPort: 8080 # Port to forward traffic to
  selector:
    app.kubernetes.io/name: argocd-server # Select the ArgoCD server pod
```
 

 


 ```yaml
 - name: start-argocd-sync
      inputs:
        parameters:
          - name: app-name
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: ubuntu:latest
        command:
          - sh
          - '-c'
        args:
          - >
            apt-get update && apt-get install -y curl sudo

            curl -sSL -o argocd-linux-amd64
            https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

            sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

            rm argocd-linux-amd64

            argocd login $ARGOCD_SERVER --username $ARGOCD_USERNAME --password
            $ARGOCD_PASSWORD --insecure

            argocd app sync {{inputs.parameters.app-name}}
        env:
          - name: ARGOCD_SERVER
            valueFrom:
              secretKeyRef:
                name: argocd-env-secret
                key: server
          - name: ARGOCD_USERNAME
            valueFrom:
              secretKeyRef:
                name: argocd-env-secret
                key: username
          - name: ARGOCD_PASSWORD
            valueFrom:
              secretKeyRef:
                name: argocd-env-secret
                key: password
        resources: {}
 ```