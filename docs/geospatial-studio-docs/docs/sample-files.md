=== "Burnscars iterate HPO"
## Terratorch HPO Segmentation Config {#burnscars-iterate-hpo}

??? note "burnscars-iterate-hpo"
    ```yaml
        --8<-- "sample_files/burnscars-iterate-hpo.yaml"
    ```


=== "Finetuning Config file"
## Finetuning Config file {#floods-finetuning-config-file}

??? note "floods-finetuning-config-file with prithvi"
    ```yaml
        --8<-- "sample_files/prithvi-eo-flood-config.yaml"
    ```


=== "ConvNeXT Template"
## Sample file to create user defined tuning templates {#convnext-template}
This sample file demonstrates how to create a user-defined tuning template. To use this template when submitting a task:

1. Download or copy the YAML configuration below.
2. Encode the file content using Base64.
3. Insert the encoded content into the `"content"` field of your task JSON payload.

??? note "sample-convnext-config"
    ```yaml
        --8<-- "sample_files/sample-convnext-config.yaml"
    ```

**Example usage:**
```javascript
{
    "name": "user-new-task",
    "description": "Custom ConvNeXT tuning task",
    "purpose": "Other", // Do not change
    "content": "<BASE64_ENCODED_YAML_HERE>", // Paste your Base64-encoded YAML here
    "extra_info": {
        "runtime_image": "us.icr.io/gfmaas/geostudio-ft-deploy:feat-update_tt_version-142",
        "model_framework": "terratorch-v2"
    },
    "model_params": {},
    "dataset_id": "selected_dataset"
}
```

??? note "How to encode the YAML file to Base64"
    **Using command line:**
    ```bash
        base64 sample-convnext-config.yaml
    ```
    **Using Python:**
    ```python
        import base64

        def encode_file_to_base64(file_path):
            with open(file_path, "rb") as file:
                # Read the file in binary mode
                file_content = file.read()
                
                # Encode the content to base64
                base64_encoded = base64.b64encode(file_content)
                
                # Decode the Base64 bytes into a string (if needed)
                base64_string = base64_encoded.decode('utf-8')
                
            return base64_string

        encoded_content = encode_file_to_base64("../sample_files/sample-convnext-config.yaml")
        print(encoded_content)
    ```
    **Using online tools:**

    Visit [base64encode.org](https://www.base64encode.org/) and paste your YAML content.
