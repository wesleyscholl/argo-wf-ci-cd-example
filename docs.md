| Webhook/Event Binding                                      | Resource                      | Status |
|------------------------------------------------------------|-------------------------------|--------|
| Configuration                                              |                               |        |
| GitHub Webhooks Configuration                              |                               |        |
| • Follow this guide: [GitHub Webhooks Guide](https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks) | | |
| • GitHub Event Source Reference: [Argo Events GitHub Setup](https://argoproj.github.io/argo-events/eventsources/setup/github/) | | |
| Two methods to trigger workflows using webhooks            |                               |        |
| WorkflowEventBinding                                       |                               |        |
| Uses the `/api/v1/events/{namespace}/{discriminator}` API endpoint and submits a `WorkflowTemplate` or `ClusterWorkflowTemplate`. | | |
| To setup `WorkflowEventBinding`: [WorkflowEventBinding Setup](https://argo-workflows.readthedocs.io/en/latest/events/) | | |
| Example WorkflowEventBinding - `WorkflowEventBinding.yaml` |                               |        |
| WorkflowEventBinding Role                                  |                               |        |
| RBAC permissions required to submit workflows using the WorkflowEventBinding. | | |
| Example WorkflowEventBinding Role - `WorkflowEventBindingRole.yaml` | | |
| Argo Events                                                |                               |        |
| Uses an event source endpoint, sensor, and trigger to submit a `WorkflowTemplate` or `ClusterWorkflowTemplate`. | | |
| To setup Argo Events: [Argo Events Quick Start](https://argoproj.github.io/argo-events/quick_start/) | | |
| Event source - GitHub push event                           |                               |        |
| • Example EventSource - `EventSourceWebHook.yaml`          |                               |        |
| • Webhook Endpoint URL: `https://<argo-workflows-url>/example:12000` | | |
| Sensor and Trigger for WorkflowTemplate                    |                               |        |
| • Example Sensor - `SensorTrigger.yaml`                    |                               |        |
| ServiceAccount, Role and RoleBinding Configuration         |                               |        |
| A service account is required to create workflows from the trigger and operate the CI/CD workflows. | | |
| See the yaml configuration here: `ServiceAccountRoleBindingRole` | | |
| Testing the configuration                                  |                               |        |
| Both configurations can be tested using a curl command:    |                               |        |
| `curl -d '{"message":"Trigger CI/CD"}' -H "Content-Type: application/json" -X POST http://<Deployed-Argo-Application-Url>:12000/example` | | |

| CI                                           | Resource                | Status |
|----------------------------------------------|-------------------------|--------|
| Build the CLI.                               | `WorkflowTemplate`      | ☑️     |
| Build images using Buildkit - Pushes image to Docker Hub | `WorkflowTemplate` | ☑️     |
| Run unit tests and collect test report.      | `WorkflowTemplate`      | ☑️     |
| Run coverage and collect report.             | `WorkflowTemplate`      | ☑️     |
| Deploy to a cluster.                         | `WorkflowTemplate`      | ☑️     |
| Run basic E2E tests and collect report.      | `WorkflowTemplate`      | ☑️     |
| CI Documentation                             |                         | ☑️     |

| CD                                           | Resource                | Status |
|----------------------------------------------|-------------------------|--------|
| Tag and push tag.                            | `WorkflowTemplate`      | ☑️     |
| Update deployment manifests using `kustomize edit set image`. | `WorkflowTemplate` | ☑️     |
| Commit deployment manifests.                 | `WorkflowTemplate`      | ☑️     |
| Start Argo CD sync step.                     | `WorkflowTemplate`      | ☑️     |
| CD Documentation                             |                         | ☑️     |

| Pipeline                                     | Resource                | Status |
|----------------------------------------------|-------------------------|--------|
| Combine CI and CD jobs with an approval step.| `WorkflowTemplate`      | ☑️     |
| Pipeline Documentation                       |                         | ☑️     |