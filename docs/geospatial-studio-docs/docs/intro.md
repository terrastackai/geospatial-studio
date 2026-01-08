# Intro to the studio

## Dataset Facrory
The Geospatial Exploration and Orchestration Studio allows users to onboard their curated data for fine-tuning. The Studio Uses [Terrakit](https://terrastackai.github.io/terrakit/), a Python package for finding, retrieving and processing geospatial information, to find and fetch data  from a range of data connectors. Data connectors in Terrakit are different platforms(data sources) that provide access to geospacial data.

Currently, Terrakit supports the following data connectors:
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

Check out the [Dataset factory user guide]() for a full list and description of what you need to define when onboarding a dataset to the GEOStudio.

The Geospatial Studio allows users to onboard either multi-modal data or uni-modal data. For the multi-modal data, users shall provide, as a list, a different data source for each input modality of the dataset. The Studio allows users to define a modality tag parameter for each collection that ***. The table below shows the modality tags associated with each collection across the different data connectors:

| Modality tag | Sentinel hub collections | NASA Earthdata collections | Sentinel AWS collections | IBM Research STAC collections | The Weather Company collections |
| :--- | :---: | ---: | :---: | ---: | ---: |
| S2L1C | s2_l1c | | | | |
| DEM | dem | | | | |
| S1GRD | s1_grd | | | | |
| HLS_L30 | hls_l30 | HLSL30_2.0 | | | weathercompany-daily-forecast |
| HLS_S30 | hls_s30 | HLSS30_2.0 | | | |
| S2L2A | s2_l2a | | sentinel-2-l2a | | |




## Fine-tuning

## Inference