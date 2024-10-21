# Argo Workflows - CI CD Example


## Table of Contents

- [GitHub Webhooks Configuration](#gitHub-webhooks-configuration)
- [Two methods to trigger workflows using webhooks](#two-methods-to-trigger-workflows-using-webhooks)
  - [`WorkflowEventBinding`](#workfloweventbinding) 
  - [Argo Events](#argo-events)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

This example is triggered using a curl command, but can be connected to GitHub Webhooks and other sources.


```bash
curl -d '{"message":"Trigger CI/CD"}' -H "Content-Type: application/json" -X POST http://<Deployed-Argo-Application-Url>:12000/example 
```



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
