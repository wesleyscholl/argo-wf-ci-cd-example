### Artifacts and Volumes: Core Differences

Volumes and artifacts serve different purposes within workflows:

**Volumes:**

Volumes act as shared storage mechanisms within the same pod or workflow, enabling immediate data exchange between containers. They are primarily suited for short-lived data sharing within a single workflow execution, also known as ephemeral storage. For a long-term data storage volume, configure a `PersistentVolumeClaim` (PVC) instead.

**Artifacts:**

Artifacts provide a more flexible mechanism for data transfer, supporting persistent storage and versioning. They can be used across workflow steps, even across pods or clusters, and are particularly useful for caching and transferring data. Artifacts are stored in a central repository, such as S3, Minio, or Google Cloud Storage (GCS), and can be shared across steps, tasks, pods, containers, workflows, namespaces or clusters.

### Detailed Comparison

#### Benefits

| **Volumes**                                              | **Artifacts**                                                                     |
| -------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Fast and efficient for immediate, localized data sharing | Ensures persistence and reliability for data transfer across complex workflows    |
| Minimal setup and configuration required                 | Supports versioning, tracking, and integration with external storage systems      |
| Lightweight and resource-efficient                       | Suitable for large-scale workflows with robust data transfer and management needs |

---

#### Challenges and Limitations

| **Volumes**                                                                                                                                                                     | **Artifacts**                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Data exists only during the pod or workflow lifecycle, unless using a `PersistentVolumeClaim` (PVC)                                                                             | Transfer latency: Large artifacts (i.e. multi-gigabyte datasets) must be fully transferred between steps  |
| Access Mode Constraints: Many volume types, such as `ReadWriteOnce`, are limited to a single node, which restricts their usage across multiple pods in distributed environments | Can increase workflow execution time, create bandwidth constraints, and risk timeouts for large files     |
| No built-in versioning or archiving                                                                                                                                             | Storage backend complexity: Relies on external systems like S3, Artifactory, GCS, Minio, Azure Blob, etc. |
| Disk space constraints: Limited by the node's storage capacity                                                                                                                  | Requires additional configuration, authentication, and infrastructure management                          |
| Scaling issues: Inefficient for workflows with high data transfer needs across steps                                                                                            | Performance may vary depending on storage provider                                                        |

---

#### Ideal Use Cases and Applications

| **Volumes**                                                                 | **Artifacts**                                                                               |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Sharing a filesystem between steps, tasks, or pods within the same workflow | Transferring data between steps, tasks, pods, containers, workflows, namespaces or clusters |
| Temporary file system needs, unless using a `PersistentVolumeClaim` (PVC)   | Persistent storage and retrieval                                                            |
| Lightweight, quick data exchange                                            | Caching build outputs                                                                       |
| Creating temporary working directories                                      | Passing large datasets between workflow steps                                               |
| Short-lived data exchange within a pod                                      | Storing build artifacts for later use                                                       |
| Sharing configuration files in a single container group                     | Implementing complex CI/CD pipelines                                                        |
|                                                                             | Data persistence across workflow executions                                                 |

#### Workflow Examples

```yaml
# This example demonstrates the ability to pass artifacts from one step to the next.
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-passing-
spec:
  entrypoint: artifact-example
  templates:
    - name: artifact-example
      steps:
        - - name: generate-artifact
            template: hello-world-to-file
        - - name: consume-artifact
            template: print-message-from-file
            arguments:
              artifacts: # Specifies the artifact argument
                - name: message # Artifact name
                  from: "{{steps.generate-artifact.outputs.artifacts.hello-art}}" # Path to the artifact, using the output artifact name from the previous step

    - name: hello-world-to-file
      container:
        image: busybox
        command: [sh, -c]
        args: ["sleep 1; echo hello world | tee /tmp/hello_world.txt"] # Writes hello world to /tmp/hello_world.txt
      outputs:
        artifacts: # Specifies the output artifact
          - name: hello-art # Artifact name
            path: /tmp/hello_world.txt # Path to the artifact

    - name: print-message-from-file
      inputs:
        artifacts: # Specifies the artifact input
          - name: message # Artifact name
            path: /tmp/message # Path to the artifact
      container:
        image: alpine:latest
        command: [sh, -c]
        args: ["cat /tmp/message"] # Reads and prints the message from the artifact
```

Source: https://github.com/argoproj/argo-workflows/blob/main/examples/artifact-passing.yaml
