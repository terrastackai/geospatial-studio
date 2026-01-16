# IBM Geospatial Exploration and Orchestration Studio

The **Geospatial Exploration and Orchestration Studio** is an integrated platform for **fine-tuning, inference, and orchestration of geospatial AI models**.  It combines a **no-code UI**, **low-code SDK**, and APIs to make working with geospatial data and AI accessible to everyone, from researchers to developers.  

The platform supports **on-prem or cloud deployment** using **Red Hat OpenShift** or **Kubernetes**, enabling scalable pipelines for data preparation, model training, and inference.

By leveraging tools like **TerraTorch**, **TerraKit**, and **Iterate**, the Geospatial Studio accelerates insights from complex geospatial datasets for a diverse range of applications. 🌱

The studio is builds upon the broader ecosystem utilising [TerraTorch](https://github.com/terrastackai/terratorch) for model fine-tuning and inference, and leveraging [TerraKit](https://github.com/terrastackai/terrakit) for geospatial data search, query and processing.

![Geospatial Studio UI Screenshots](./assets/ui-screenshots.png)

## Geospatial Studio Capabilities

The Geospatial Studio supports users in creating new models and using trained models (either pre-loaded, shared or user-tuned).  Below explain the steps involved for each, with explanation of how the Studio enables users with current and future functionality.

![Geospatial Foundation Model workflow](./assets/gfm-block-diagram.png)

### Creating a new model (aka Fine-tuning)
As a user, when you want to train a new model for a specific application, there are a number of steps you need to go through to prepare for the training, then train and monitor, before assessment and deployment of any new model.  The main stages in that process are described in the chevron diagram below.  The Studio provides support at each step.  

![Fine-tuning steps chevron diagram](./assets/fine-tuning-chevrons.png)

0. (Optional) **Dataset onboarding or creation**
1. **Choosing a training dataset**
2. **Configuring a tuning task**
3. **Running model training**
4. **Validating model performance**
5. **Model deployment**

If an appropriate tuning dataset does not already exist in the platform, a user can onboard one with the dataset factory.  This allows a user to onboard a training dataset (data+labels) they have prepared, and in future will provide tools to support creation of a dataset with support for data discovery and annotation.

### Using a trained model (aka Inference)
If a model already exists for the given application (either one which was pre-existing, or one you have tuned and deployed), we can drive the model using the inference service.  This handles data preparation and passing, as well as post-processing of model outputs and visualization.  As with fine-tuning, there are a few steps involved and the Studio is designed to support users and simplify access to such models.

![Inference steps chevron diagram](./assets/inference-chevrons.png)

1. **Inference configuration**
2. **Inference execution**
3. **Insight extraction**

## Use-case examples

### Environmental monitoring
Monitoring Kenya’s Water Towers and government efforts to protect and reforest large areas.  Including potential for carbon sequestration and carbon markets.
<p align="center"><iframe width="560" height="315" src="https://www.youtube.com/embed/CTv2sOYOQyc?si=6k9v0UEWlZ8NPAcv" title="YouTube video player" frameborder="0" allow="autoplay; encrypted-media;" allowfullscreen></iframe></p>

### Disaster monitoring
AI automation for monitoring floods and translation into affected assets, shown here for the floods in Kenya earlier this year.

<p align="center"><iframe width="560" height="315" src="https://www.youtube.com/embed/P01VIRJ7n_k?si=4TXMQqqywl2Wggi_" title="YouTube video player" frameborder="0" allow="autoplay; encrypted-media;" allowfullscreen></iframe></p>


### Climate model downscaling
Improving the spatial resolution of outputs from computationally intensive weather and climate simulation models to provide the required detail for carrying out climate risk assessment.  Similar can be used to improve short term renewables forecasting.

<p align="center"><iframe width="560" height="315" src="https://www.youtube.com/embed/K6jhFWwBqfo?si=J1ESfgpWrpFdBmf3" title="YouTube video player" frameborder="0" allow="autoplay; encrypted-media;" allowfullscreen></iframe></p>




## Provide feedback

If you’d like to provide feedback, [submit a new feature request here or report an issue](https://github.com/terrastackai/geospatial-studio).

