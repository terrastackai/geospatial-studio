# # Geospatial Studio Dataset Factory APIs

## What?
The Dataset Factory allows users to bring their curated geospatial datasets to the Studio to fine-tune their models.  The dataset-factory endpoints allow users to onboard and delete datasets.  In addition, some endpoints allow users to view their datasets' metadata.  The front-end also uses the dataset-factory API to provide users with a preview of their datasets.

## Where?
We recommend that users utilize the Geospatial Studio UI instead for the more user-friendly and appealing interface.

![plot](./assets/dataset-factory-service/api-page.png)

## How?
To onboard a dataset to the Dataset Factory, the user needs to provide the following:

| Field | Data Type | Example | Requirements |
| ----- | ------ | ------| -------|
| `dataset_name` | String (space characters allowed) | `UK 2013-2019 Flood Data` | A descriptive name which helps the user recognize the dataset would suffice |
|`data_sources`| List | `[{"bands": [{"index":"0", "band_name": "VV (Gray)", "description": ""},{"index":"1", "band_name": "VH", "description": ""}],"connector": "sentinelhub","collection": "s1_grd","modality_tag": "S1GRD","align_dates": "true","file_suffix": "_S1Hand.tif","scaling_factor": [1, 1]}]`| A list containing information about each data source for the dataset. Including the data connector (e.g sentinelhib or nasa_earthdata), and information about the collections (collection name, bands, scaling factor, etc) |
| `label_categories` | List of dictionaries |`[{ "id": "0", "name": "Floods", "description": "Flooding assets" }]` | Each dictionary in the list contains `id`, `name`, and `description`, where `id` and `label` are required fields, and `description` is not required |
| `dataset_url` | String | `https://ibm.box.com/shared/static/t682cwbcc5np6db9c6uj35lu2559ij26.zip` | Any link which would allow direct download of a **zip** file.
| `description` | String (space characters allowed) | `2013-2019 Image from Sentinel Hub. The tiff files are 512 x 512 and containing 6 bands` | Something descriptive would suffice |
| `training_data_suffix` | List of strings (no space allowed) | `_imageHand.tif` | This is the suffix which the training image files have.  This allows the onboarding pipeline to correctly find all images from all directories. |
| `label_suffix` | String (no space allowed) | `_labelHand.tif` | This is the suffix which all the label files have.  This allows the onboarding pipeline to correctly find all labels from all directories. The `training_data_suffix` and `label_suffix` much be distinct. |
| `purpose` | String | `Regression` | The available options are `Regression`, `Segmentation`, `Generate`, `NER`, `Classify`, `Other`
| `training_params`| Dictionary | | Configure training parameters for the model |

An example payload could look like the following:
```
{
    "dataset_name": "Sentinel Flood Multimodal",
    "data_sources": [
        {
            "bands": [
                {"index":"0", "band_name": "Coastal_aerosol", "description": ""},
                {"index":"1", "band_name": "Blue", "RGB_band": "B", "description": ""},
                {"index":"2", "band_name": "Green", "RGB_band": "G", "description": ""},
                {"index":"3", "band_name": "Red", "RGB_band": "R", "description": ""},
                {"index":"4", "band_name": "05_-_Vegetation_Red_Edge", "description": ""},
                {"index":"5", "band_name": "06_-_Vegetation_Red_Edge", "description": ""},
                {"index":"6", "band_name": "07_-_Vegetation_Red_Edge", "description": ""},
                {"index":"7", "band_name": "08_-_NIR", "description": ""},
                {"index":"8", "band_name": "08A_-_Vegetation_Red_Edge", "description": ""},
                {"index":"9", "band_name": "09_-_Water_vapour", "description": ""},
                {"index":"10", "band_name": "11_-_SWIR", "description": ""},
                {"index":"11", "band_name": "12_-_SWIR", "description": ""},
                {"index":"12", "band_name": "Cloud_Probability", "description": ""}
            ],
            "connector": "sentinelhub",
            "collection": "s2_l2a",
            "modality_tag": "S2L1C",
            "file_suffix": "_S2Hand.tif",
            "scaling_factor": [1, 1, 1, 1, 1, 1]
        },
        {
            "bands": [
                {"index":"0", "band_name": "VV (Gray)", "description": ""},
                {"index":"1", "band_name": "VH", "description": ""}
            ],
            "connector": "sentinelhub",
            "collection": "s1_grd",
            "modality_tag": "S1GRD",
            "align_dates": "true",
            "file_suffix": "_S1Hand.tif",
            "scaling_factor": [1, 1]
        }
    ],
    "label_categories": [
        {"id": "0", "name": "No Floods", "description": "Flooding assets"},
        {"id": "1", "name": "Floods", "description": "Flooding assets"}
    ],
    "dataset_url": "https://s3.us-east.cloud-object-storage.appdomain.cloud/geospatial-studio-example-data/sen1floods11_v1.1.tar.gz",
    "description": "Flood data from places",
    "label_suffix": "_LabelHand.tif",
    "purpose": "Segmentation"
}
```

### Dataset Requirements
To successfully onboard a curated dataset, the dataset should meet the following requirements:

1. The dataset if contained in a `.zip` files, and a direct download link is available and correctly enterd in the onboarding payload
   
2. The corresponding image and label files should have the same filesname, excluding the suffixes.  As an example, 
   `subsetted_512x512_HLS.S30.T10SEH.2018190.v1.4_merged.tif` and `subsetted_512x512_HLS.S30.T10SEH.2018190.v1.4.mask.tif` are a corresponding pair, where `subsetted_512x512_HLS.S30.T10SEH.2018190.v1.4` is the matching filename body, and `_merged.tif` and `.mask.tif` are the suffixes.  If the names don't match, onboarding won't proceed.
   
3. For any dataset for `Segmentation` purpose, please make sure 2 categories are included in the `label_categories` field in the onboarding payload.