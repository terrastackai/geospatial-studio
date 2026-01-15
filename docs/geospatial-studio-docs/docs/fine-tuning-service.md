# Geospatial Studio Fine-tuning APIs

The Geospatial Tuning Studio provides users with a no-code way to create fine-tuned models for specific applications.  The user will select the *type of task* they wish to carry out, the *tuning dataset* and the *backbone model* they wish to start from.

## Workflow

The fine-tuning process involves the following key steps:

1. Select or create a Fine-Tuning dataset in the Dataset Factory service: choose or upload geospatial data with corresponding labels that will be used for training.
2. Select a tuning task type (e.g Regression or Segmentation) from a template and configure model parameters if need be or use defaults.
3. Specify the base-model, downstrean task and tuning parameters: configure parameters related to the foundation model and the fine-tuning process.
4. Submit a tuning job: Launch a tuning job that will adapt the model to your specified downstream task.
5. Monitor training and performance: Track the progress of the fine-tuning process by monitor training metrics.
6. Deploy model for inferencing: After fine-tuning, the output is a model checkpoint and configuration files. With these files, the model can be deployed to an inference service for real-world applications.

## Dataset Options

To fine-tune a model for a downstream task, you need a labeled fine-tuning dataset. The Geospatial Tuning Studio provides multiple ways to acquire or upload a dataset through the dataset-factory.

[Dataset Factory Docs :fontawesome-solid-book:](dataset-factory-service.md){ .md-button }

## Fine-Tuning Components

The fine-tuning process involves four essential components:

- **Base Models / Foundation Models:** Pre-trained models that serve as the starting point for fine-tuning. These models have been trained on large geospatial datasets and are adaptable to specific tasks.

- **Downstream Tasks:** These are specific tasks for which the base model is fine-tuned. Examples include tasks like flooding, fire-scars, land classification and other geospatial analyses.

- **Datasets:** A Curated set of geospatial data with corresponding labels required for fine-tuning.

- **Tunes:** Tunes represent the fine-tuning process itself, where the model is trained on the specified dataset and task parameters. Each tune results in a fine-tuned version of the model.

## API Overview

These APIs allow users to programmatically interact with the Geospatial Tuning Studio for a variety of tasks.

![plot](./assets/fine-tuning-service/api-page.png)
![plot](./assets/fine-tuning-service/api-page2.png)


### Tunes

Tuning geospatial models

#### List Tunes

`GET /v2/tunes`

Lists all fine tuning jobs available to the logged in user.

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tunes \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

        > 200 Response

        ```json
        {
        "total_records": 0,
        "page_count": 0,
        "results": [
            {
            "id": "string",
            "active": true,
            "created_by": "",
            "created_at": "2025-08-27T07:18:25.834Z",
            "updated_at": "2025-08-27T07:18:25.834Z",
            "name": "string",
            "description": "string",
            "task": {
                "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                "name": "string"
            },
            "dataset_id": "string",
            "base_model": {
                "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                "name": "string"
            },
            "mcad_id": "",
            "status": "",
            "latest_chkpt": "",
            "logs": "",
            "metrics": ""
            }
        ]
        }
        ```

    === "Query Parameters"

        |Name|In|Type|Required|Description|
        |---|---|---|---|---|
        |name|query|any|false|Filter by the name of the tune.|
        |status|query|any|false|Filter by the status of the tune.|
        |limit|query|any|false|The maximum number of items to retrieve.|
        |skip|query|any|false|The number of items to skip.|

#### Retrieve Tune

`GET /v2/tunes/{tune_id}`

Retrieves a single fine-tuning job by the `tune_id`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tunes/{tune_id} \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

        > 200 Response

        ```json
        {
        "id": "string",
        "active": true,
        "created_by": "",
        "created_at": "2025-08-27T07:20:03.484Z",
        "updated_at": "2025-08-27T07:20:03.484Z",
        "name": "string",
        "description": "string",
        "task": {
            "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            "name": "string"
        },
        "dataset_id": "string",
        "base_model": {
            "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            "name": "string"
        },
        "mcad_id": "",
        "status": "",
        "latest_chkpt": "",
        "logs": "string",
        "metrics": [],
        "config_json": {},
        "progress": {
            "additionalProp1": {}
        },
        "logs_presigned_url": "string",
        "tuning_config": "string",
        "tuning_config_presigned_url": "string",
        "train_options": {}
        }
        ```

#### Submit Tune

`POST /v2/submit-tune`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X POST /v2/submit-tune \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}' \
        -d '{
        "name": "string",
        "description": "string",
        "dataset_id": "string",
        "base_model_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "tune_template_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "model_parameters": {},
        "train_options": {}
        }'
        ```

??? "Parameters and Responses"

    === "Success Response"

        > 201 Response

        ```json
        {
        "tune_id": "string",
        "mcad_id": "string",
        "status": "Pending",
        "message": {
            "additionalProp1": {}
            }
        }
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |201|[Created](https://tools.ietf.org/html/rfc7231#section-6.3.2)|Successful Response|[TuneSubmitOut](#schematunesubmitout)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Update Tune

`PATCH /v2/tunes/{tune_id}`

Updates tune metadata fields.

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X PATCH /v2/tunes/{tune_id} \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'
        -d '{
            "name": "segmentation-test-1",
            "description": "Segmentation demo example"
        }
        ```

??? "Parameters and Responses"

    > 200 Response

    === "Success Response"

        ```json
        {
            "message": "Tune successfully updated."
        }
        ```

    === "Query Parameters"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|Inline|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Delete Tune

`DELETE /v2/tunes/{tune_id}`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X DELETE /v2/tunes/{tune_id} \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    |Status|Meaning|Description|Schema|
    |---|---|---|---|
    |204|[No Content](https://tools.ietf.org/html/rfc7231#section-6.3.5)|Successful Response|None|
    |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Try out Tuned Model

`POST /v2/tunes/{tune_id}/try-out`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X POST /v2/tunes/{tune_id}/try-out \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}' \
        -d '
        {
        "model_display_name": "",
        "description": "try-out",
        "location": "string",
        "geoserver_layers": {
            "additionalProp1": {}
        },
        "spatial_domain": {
            "bbox": [
            [
                0
            ]
            ],
            "polygons": [
            "string"
            ],
            "tiles": [
            "string"
            ],
            "urls": [
            "string"
            ]
        },
        "temporal_domain": [
            "string"
        ],
        "model_input_data_spec": [
            {
            "additionalProp1": {}
            }
        ],
        "data_connector_config": [
            {
            "connector": "string",
            "collection": "string",
            "bands": [
                {
                "additionalProp1": {}
                }
            ],
            "scaling_factor": [
                0
            ],
            "additionalProp1": {}
            }
        ],
        "geoserver_push": [
            {
            "workspace": "string",
            "layer_name": "string",
            "display_name": "string",
            "filepath_key": "string",
            "file_suffix": "string",
            "geoserver_style": "string",
            "additionalProp1": {}
            }
        ]
        }'
        ```

??? "Parameters and Responses"

    === "Success Response"

        > 201 Response

        ```json
        {
        "spatial_domain": {
            "bbox": [
            [
                0
            ]
            ],
            "polygons": [
            "string"
            ],
            "tiles": [
            "string"
            ],
            "urls": [
            "string"
            ]
        },
        "temporal_domain": [
            "string"
        ],
        "fine_tuning_id": "string",
        "model_display_name": "string",
        "description": "string",
        "location": "string",
        "geoserver_layers": {
            "additionalProp1": {}
        },
        "demo": {
            "additionalProp1": {}
        },
        "model_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "inference_output": {
            "additionalProp1": {}
        },
        "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "active": true,
        "created_by": "",
        "created_at": "2025-08-27T07:24:07.317Z",
        "updated_at": "2025-08-27T07:24:07.317Z",
        "status": "string",
        "tasks_count_total": 0,
        "tasks_count_success": 0,
        "tasks_count_failed": 0
        }
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|Inline|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Download Tunes

`GET /v2/tunes/{tune_id}/download`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tunes/{tune_id}/download \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'
        ```

??? "Parameters and Responses"

    === "Success Response"

        > 200 Response

        ```json
        {
            "id": "string",
            "name": "string",
            "description": "string",
            "config_url": "string",
            "checkpoint_url": "string"
        }
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|[TuneDownloadOut](#schematunedownloadout)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Get Tune Metrics

`GET /v2/tunes/{tune_id}/metrics`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tunes/{tune_id}/metrics \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

    > 200 Response

    ```json
    {
        "id": "string",
        "status": "FINISHED",
        "epochs": "string",
        "metrics": [
            {}
        ],
        "details": "string"
    }
    ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|[TunedModelMlflowMetrics](#schematunedmodelmlflowmetrics)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

### Templates

Managing available tuning tasks (i.e. experiment templates)

#### List Templates

`GET /v2/tune-templates`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tune-templates \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

        > 200 Response

        ```json
                {
        "total_records": 0,
        "page_count": 0,
        "results": [
            {
            "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            "active": true,
            "created_by": "",
            "created_at": "2025-08-27T07:26:11.139Z",
            "updated_at": "2025-08-27T07:26:11.139Z",
            "name": "string",
            "description": "string",
            "purpose": "string",
            "extra_info": {
                "additionalProp1": {}
            }
            }
        ]
        }
        ```

    === "Query Parameters"

        |Name|In|Type|Required|Description|
        |---|---|---|---|---|
        |name|query|any|false|Filter by the name of the tune.|
        |limit|query|any|false|The maximum number of items to retrieve.|
        |skip|query|any|false|The number of items to skip.|

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|[TasksOut](#schematasksout)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Create Tune Template

`POST /v2/tune-templates`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X POST /v2/tune-templates \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}' \
        -d '{
            "name": "string",
            "description": "string",
            "content": "string",
            "model_params": {},
            "extra_info": {
                "runtime_image": ""
            },
            "dataset_id": "string"
        }
        ```

??? "Parameters and Responses"

    === "Success Response"

        > 200 Response

        ```json
        {
            "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08"
        }
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |201|[Created](https://tools.ietf.org/html/rfc7231#section-6.3.2)|Successful Response|Inline|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Retrieve Task

`GET /v2/tune-templates/{task_id}`

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tune-templates/{task_id} \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

        ```json
        {
            "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
            "active": true,
            "created_by": "",
            "created_at": "2019-08-24T14:15:22Z",
            "updated_at": "2019-08-24T14:15:22Z",
            "name": "string",
            "description": "string",
            "model_params": {},
            "extra_info": {
            "additionalProp1": {}
            }
        }
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|[TaskOut](#schemataskout)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Render Tuning Template

`GET /v2/tune-templates/{task_id}/test-render`

Check Task Content Rendered With Defaults

!!! example

    === "Curl :material-powershell:"

        ```shell
        curl -X GET /v2/tune-templates/{task_id}/test-render \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

        ```json
        "string"
        ```
    
    === "Query Parameters"

        |Name|In|Type|Required|Description|
        |---|---|---|---|---|
        |task_id|path|any|true|none|
        |dataset_id|query|any|true|none|
        |base_model|query|any|true|none|

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|Inline|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

### Base models

Available foundation model bases

#### List Base Models

`GET /v2/base-models`

!!! example

    === "Shell :material-powershell:"

        ```shell
        # You can also use wget
        curl -X GET /v2/base-models \
        -H 'Accept: application/json' \
        -H 'Authorization: Bearer {access-token}'

        ```

??? "Parameters and Responses"

    === "Success Response"

        ```json
        {
            "total_records": 0,
            "page_count": 0,
            "results": [
                {
                    "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
                    "active": true,
                    "created_by": "",
                    "created_at": "2019-08-24T14:15:22Z",
                    "updated_at": "2019-08-24T14:15:22Z",
                    "name": "string",
                    "description": "string",
                    "checkpoint_filename": "string",
                    "model_params": {}
                    }
                ]
            }
        ```
    === "Query Parameters"

        |Name|In|Type|Required|Description|
        |---|---|---|---|---|
        |name|query|any|false|Filter by the name of the tune.|
        |limit|query|any|false|The maximum number of items to retrieve.|
        |skip|query|any|false|The number of items to skip.|

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|[BaseModelsOut](#schemabasemodelsout)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Create Base Model

`POST /v2/base-models`

!!! example

    === "Shell :material-powershell:"

    ```shell
    # You can also use wget
    curl -X POST /v2/base-models \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -H 'Authorization: Bearer {access-token}'
    -d '
    {
    "name": "string",
    "description": "string",
    "checkpoint_filename": "",
    "model_params": {
        "backbone": "",
        "patch_size": 16,
        "num_layers": 12,
        "embed_dim": 768,
        "num_heads": 12,
        "tile_size": 1,
        "tubelet_size": 1,
        "model_category": "prithvi"
    }
    }'
    ```

??? "Parameters and Responses"

    === "Success Response"

        ```json
        "string"
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |201|[Created](https://tools.ietf.org/html/rfc7231#section-6.3.2)|Successful Response|Inline|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|

#### Retrieve Base Model

`GET /v2/base-models/{base_id}`

!!! example

    === "Curl :material-powershell:"

    ```shell
    # You can also use wget
    curl -X GET /v2/base-models/{base_id} \
    -H 'Accept: application/json' \
    -H 'Authorization: Bearer {access-token}'

    ```

??? "Parameters and Responses"

    === "Success Response"

        ```json
        {
            "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
            "active": true,
            "created_by": "",
            "created_at": "2019-08-24T14:15:22Z",
            "updated_at": "2019-08-24T14:15:22Z",
            "name": "string",
            "description": "string",
            "checkpoint_filename": "string",
            "model_params": {}
        }
        ```

    === "Other Responses"

        |Status|Meaning|Description|Schema|
        |---|---|---|---|
        |200|[OK](https://tools.ietf.org/html/rfc7231#section-6.3.1)|Successful Response|[BaseModelOut](#schemabasemodelout)|
        |422|[Unprocessable Entity](https://tools.ietf.org/html/rfc2518#section-10.3)|Validation Error|[HTTPValidationError](#schemahttpvalidationerror)|
