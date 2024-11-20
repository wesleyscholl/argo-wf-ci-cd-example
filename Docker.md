Here is the official Argo Workflows Buildkit example configuration:

- https://github.com/argoproj/argo-workflows/blob/main/examples/buildkit-template.yaml

Ensure that `test-secret-secret` contains the following:

```json
{"auths":
  {"https://index.docker.io/v1/":
    {"auth": "$DOCKER_USERNAME:$DOCKER_TOKEN" # Base64 encoded
    }
  }
}
```

Docker Configuration

- Access Token for Docker Hub: Generate a personal access token at https://hub.docker.com/settings/security to publish Docker images.

- Secret Creation:

  - Shell, bash or zsh: Add the following to your shell profile (e.g. ~/.bashrc, ~/.bash_profile, ~/.zshrc, ~/.profile).

  ```shell
   export DOCKER_USERNAME=******
   export DOCKER_TOKEN=******
  ```

  - Kubernetes Secret Creation: Add `-n <namespace>` for specific namespaces.

  ```shell
   kubectl create secret generic docker-config --from-literal="config.json={\"auths\": {\"https://index.docker.io/v1/\": {\"auth\": \"$(echo -n $DOCKER_USERNAME:$DOCKER_TOKEN|base64)\"}}}"
  ```

---
