# Intro to the studio

## Dataset Facrory
The Geospatial Exploration and Orchestration Studio allows users to onboard their curated data for fine-tuning. The Studio Uses [Terrakit](https://terrastackai.github.io/terrakit/), a Python package for finding, retrieving and processing geospatial information, to find and fetch data  from a range of data connectors. Data connectors in Terrakit are different platforms(data sources) that provide access to geospacial data.

Terrakit currently supports the following data connectors:

- Sentinel Hub
- NASA Earthdata
- Sentinel AWS
- IBM Research STAC
- The Weather Company

Each data connector has a different access requirements. Please check out the [Terrakit documentation](https://terrastackai.github.io/terrakit/download_data/#available-data-connectors:~:text=weathercompany%2Ddaily%2Dforecast-,Data%20connector%20access,-Each%20data%20connector) for the specific access requirements of each data connector.

When onboarding your curated dataset to the Studio, you need to define:

-  The data connectors to use and information about the data sources like specific collection, and bands.
-  Information about your dataset like name, description, data and label file suffixes, etc.
-  Specific configurations that aid in the data onboarding and data fetching processes in the Studio.

Check out the [Dataset factory API reference page](dataset-factory-service.md) for a full list and description of what you need to define when onboarding a dataset to the GEOStudio..

The Geospatial Studio allows users to onboard either multi-modal data or uni-modal data. For the multi-modal data, users shall provide, as a list, a different data source for each input modality of the dataset. The Studio allows users to define a modality tag parameter for each collection that are used in the Terramind model to identify the specific collection to use.

The table below shows the modality tags associated with each collection across the different data connectors:

| Modality tag | Sentinel hub collections | NASA Earthdata collections | Sentinel AWS collections | IBM Research STAC collections | The Weather Company collections |
| :--- | :---: | ---: | :---: | ---: | ---: |
| S2L1C | s2_l1c | | | | |
| DEM | dem | | | | |
| S1GRD | s1_grd | | | | |
| HLS_L30 | hls_l30 | HLSL30_2.0 | | | weathercompany-daily-forecast |
| HLS_S30 | hls_s30 | HLSS30_2.0 | | | |
| S2L2A | s2_l2a | | sentinel-2-l2a | | |

Check out these [example payloads](sample-payloads.md#dataset-onboarding) that defines most of the values you will need to onboard different sample datasets we have in the Studio.


## Fine-tuning

In order to run a fine-tuning task in the studio, you need to select the following items:

* **tuning task type** - The type of learning task you are attempting. Based on the task selected, the studio provides a configuration template(tuning template) that will be used when fine-tuning. The GEOstudio currently defines the following options to select for fine-tuning task/template:

| Tuning task type | Description|
| :--- | :---: |
| Segmentation | Generic template v1 and v2 models: Segmentation |
| Regression | Generic template for v1 & v2 models: Regression |
| terramind: Segmentation | Terramind multimodal task for Segmantation |
| clay_v1 : Segmentation | Segmentation of the clay backbone models |
| timm_resnet : Segmentation | Segmentation of the resnet backbone models |
| timm_convnext : Segmentation | Segmentation of the convnext backbone models |

You can also create and manage your own tuning template. Check out the [SDK guide](geospatial-studio-toolkit/examples/fine-tuning/004-Create-User-Defined-Tuning-Templates.ipynb) on the parameters you will need to define to create your own template as well as example payloads.

* **fine-tuning dataset** - The dataset you will use to train the model for your particular application.
* **base foundation model(Backbone model)** - The geospatial foundation model you will use as the starting point for your tuning task.

In the Studio, specific tuning templates are compatible with specific backbone models. Below is a current list of the available templates and compatible backbone models.  Fine-tuning in the GEOStudio leverages [TerraTorch](https://terrastackai.github.io/terratorch/stable/), a flexible fine-tuning framework for Geospatial Foundation Models (GFMs) based on TorchGeo and Lightning. So in theory any model available in TerraTorch can be supported with an appropriate config/template, more will be made available in future.

<table>
<tr>
  <th>Model family</th>
  <th>Backbone model</th>
  <th>Tuning template</th>
</tr>
<tr>
  <td>Prithvi</td>
  <td>
    <ul>
        <li> Prithvi_EO_V1_100M
        <li> Prithvi_EO_V2_300M
        <li> Prithvi_EO_V2_600M
        <li> Prithvi_EO_V2_600M_TL
        <li> <it>Prithvi tiny (coming soon)</it>
    </ul>     
  </td>
  <td>
    <ul>
     <li> Segmentation
     <li> Regression
    </ul>  
  </td>
</tr>
<tr>
  <td>Terramind</td>
  <td>
    <ul>
        <li> terramind_v1_large
        <li> terramind_v1_base
    </ul>     
  </td>
  <td>
    <ul>
     <li> terramind: Segmentation
    </ul>  
  </td>
</tr>
<tr>
  <td>Clay</td>
  <td>
    <ul>
        <li> clay_v1_base
    </ul>     
  </td>
  <td>
    <ul>
     <li> clay_v1: Segmentation
    </ul>  
  </td>
</tr>
<tr>
  <td>ResNet</td>
  <td>
    <ul>
        <li> timm_resnet152
        <li> timm_resnet : Segmentation
        <li> timm_resnet101
        <li> timm_resnet50
        <li> timm_resnet18
        <li> timm_resnet34
    </ul>
  </td>
  <td>
    <ul>
     <li> clay_v1: Segmentation
    </ul>  
  </td>
</tr>
<tr>
  <td>Convnext</td>
  <td>
    <ul>
        <li> timm_convnext_xlarge.fb_in22k
        <li> timm_convnext_large.fb_in22k
    </ul>
  </td>
  <td>
    <ul>
     <li> timm_convnext : Segmentation
    </ul>  
  </td>
</tr>

</table>

Check out these [example template configs](sample-payloads.md#tuning-templates) for sample json configs for each of these tune templates, as well as these [fine-tuning configs](sample-payloads.md#tunes) for the datasets we have in the studio.

## Inference
The GEOStudio platform provides a no-code portal for running inference with different fine-tuned models, and visualize the results. A user can select a model, a spatial domain and temporal range, and the studio backend will do the rest. Check out the deatiled [UI](inference-lab.md) and [SDK](geospatial-studio-toolkit/examples/inference/001-Introduction-to-Inferencing.ipynb) user guide on how to run inference on the studio.

You can use these [inference payload examples](sample-payloads.md#inference) for testing inference in the studio.

