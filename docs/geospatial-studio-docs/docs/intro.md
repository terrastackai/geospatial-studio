# Intro to the studio

## Dataset Facrory
The Geospatial Exploration and Orchestration Studio allows users to onboard their curated data for fine-tuning. The Studio Uses [Terrakit](https://terrastackai.github.io/terrakit/), a Python package for finding, retrieving and processing geospatial information, to find and fetch data  from a range of data connectors. Data connectors are 

Currently, Terrakit supports the following data connectors:
- Sentinel Hub
- NASA Earthdata
- Sentinel AWS
- The Weather Company
- IBM Research STAC

Each data connector has a different access requirements.
When onboarding your dataset to the Studio, you need to define the data connector to use and the specific collection as well as other configurations like bands. 

Please check out the [Terrakit documentation](https://terrastackai.github.io/terrakit/download_data/#data-connectors:~:text=get_data()-,Available%20data%20connectors,-The%20following%20data) for the specific access requirements and configuration combinations for each data connector.

## Fine-tuning

## Inference