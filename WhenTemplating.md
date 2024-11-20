The Argo Workflows when field will produce an error if `{{=` is used first in an evaluation expression. However, reversing the expression functions as expected.

For instance, this when expression will fail:

```yaml
when: "{{=jsonpath(tasks.getdata.outputs.parameters.output_info, '$.new' != []}} "
```

But this reversed expression will function:

```yaml
when: >-
  [] != "{{=jsonpath(tasks.getdata.outputs.parameters.output_info,
  $.new)}}"
```

See this Argo Workflows discussion for more information.

- https://github.com/argoproj/argo-workflows/discussions/7413

This is a basic functional workflow that successfully utilizes the reversed expression:

```yaml
metadata:
  name: data-processing
  namespace: argo
spec:
  templates:
    - name: data-pipeline
      inputs: {}
      outputs: {}
      metadata: {}
      dag:
        tasks:
          - name: getdata
            template: getdata-template
            arguments: {}
          - name: filter
            template: filter-template
            arguments:
              parameters:
                - name: getdata_output
                  value: "{{tasks.getdata.outputs.parameters.output_info}}"
            dependencies:
              - getdata
            when: >-
              [] != "{{=jsonpath(tasks.getdata.outputs.parameters.output_info,
              $.new)}}"
    - name: getdata-template
      inputs: {}
      outputs:
        parameters:
          - name: output_info
            valueFrom:
              path: /tmp/output.json
      metadata: {}
      container:
        name: ""
        image: python:3.9-slim
        command:
          - python
          - "-c"
        args:
          - |
            import json

            # Simulating data retrieval
            data = {
                "new": []  # Change this to [{"id": 1}] to test non-empty case
            }
            print(data)
            # Write output to a file for Argo to capture
            with open('/tmp/output.json', 'w') as f:
                json.dump(data, f)
        resources: {}
    - name: filter-template
      inputs:
        parameters:
          - name: getdata_output
      outputs: {}
      metadata: {}
      container:
        name: ""
        image: python:3.9-slim
        command:
          - python
          - "-c"
        args:
          - |
            import json
            import sys

            # Read input parameter
            input_data = json.loads('''{{inputs.parameters.getdata_output}}''')

            print("Filtering data:")
            print(json.dumps(input_data, indent=2))

            # Perform filtering logic here
            filtered_data = input_data['new']

            print(f"Filtered results: {filtered_data}")
        resources: {}
  entrypoint: data-pipeline
  arguments: {}
```
