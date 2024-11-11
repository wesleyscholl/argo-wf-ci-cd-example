| CI                                           | Status |
|----------------------------------------------|--------|
| `WorkflowEventBinding`                       |-[x] Done |
| `WorkflowTemplate` - Build the CLI.          | [x]    |
| `WorkflowTemplate` - Build images using Buildkit - Pushes image to Docker Hub | [x] |
| `WorkflowTemplate` - Run unit tests and collect test report. | [x] |
| `WorkflowTemplate` - Run coverage and collect report. | [x] |
| `WorkflowTemplate` - Deploy to a cluster.    | [x]    |
| `WorkflowTemplate` - Run basic E2E tests and collect report. | [x] |
| CI Documentation                             | [x]    |

| CD                                           | Status |
|----------------------------------------------|--------|
| Tag and push tag.                            | [x]    |
| Update deployment manifests using `kustomize edit set image`. | [x] |
| Commit deployment manifests.                 | [x]    |
| Start Argo CD sync step.                     | [x]    |
| CD Documentation                             | [x]    |

| Pipeline                                     | Status |
|----------------------------------------------|--------|
| Combine CI and CD jobs with an approval step.| [x]    |
| Pipeline Documentation                       | [x]    |