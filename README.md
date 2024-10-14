# Argo Workflows - CI CD Example

## Setup and Configuration

### Argo Workflows and Argo Events

https://argoproj.github.io/argo-events/quick_start/

This example is triggered using a curl command, but can be connected to GitHub Webhooks and other sources.


```bash
curl -d '{"message":"Trigger CI/CD"}' -H "Content-Type: application/json" -X POST http://<Deployed-Argo-Application-Url>:12000/example 
```