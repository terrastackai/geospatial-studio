# What is Geospatial Studio?

The **IBM Geospatial Exploration and Orchestration Studio** (Geospatial Studio) is an integrated platform for **fine-tuning, inference, and orchestration of geospatial AI models**. It makes working with geospatial data and AI accessible to everyone, from researchers to developers.

## 🎯 Core Purpose

Geospatial Studio addresses a critical challenge: **making geospatial AI accessible and scalable**. While satellite imagery and Earth observation data are abundant, extracting insights requires specialized knowledge and infrastructure. Geospatial Studio bridges this gap.

## 🏗️ Platform Components

The platform combines three interaction modes:

### 1. No-Code UI
A web-based interface for visual interaction with the platform. Perfect for:
- Exploring datasets and models
- Running inference visually
- Monitoring training progress
- Visualizing results on interactive maps

### 2. Low-Code SDK
A Python SDK for programmatic access. Ideal for:
- Jupyter notebook workflows
- Automated pipelines
- Custom integrations
- Batch processing

### 3. RESTful APIs
Direct API access for:
- System integration
- Custom applications
- CI/CD pipelines
- Microservices architecture

## 🔧 What Can You Do?

### Dataset Management
- **Onboard** training datasets from various sources
- **Validate** data quality and format
- **Prepare** data for model training
- **Organize** datasets in a catalog

### Model Fine-Tuning
- **Customize** foundation models for specific tasks
- **Configure** training parameters
- **Monitor** training progress with MLflow
- **Evaluate** model performance

### Inference at Scale
- **Run** models on large geospatial datasets
- **Process** satellite imagery automatically
- **Visualize** results on interactive maps
- **Export** outputs for further analysis

### Orchestration
- **Automate** end-to-end workflows
- **Chain** multiple processing steps
- **Schedule** recurring tasks
- **Integrate** with existing systems

## 🌟 Key Features

### Built on Proven Technology

Geospatial Studio leverages the TerraStackAI ecosystem:

- **[TerraTorch](https://github.com/terrastackai/terratorch)** - Model fine-tuning and inference framework
- **[TerraKit](https://github.com/terrastackai/terrakit)** - Geospatial data search, query, and processing
- **[Iterate](https://github.com/terrastackai/iterate)** - Hyperparameter optimization

### Enterprise-Ready Deployment

- **On-premises or cloud** - Deploy on Red Hat OpenShift or Kubernetes
- **Flexible configuration** - Choose in-cluster or external cloud services
- **Scalable** - Handle large-scale processing workloads
- **Secure** - OAuth2 authentication and RBAC
- **Production-grade** - High availability and monitoring

#### Deployment Flexibility

**Local Deployment:**
- Fixed in-cluster services (PostgreSQL, MinIO, Keycloak)
- Ideal for learning, testing, and development
- Quick setup with Lima VM

**Cluster Deployment:**
- Choose between in-cluster or external cloud-managed services
- Database: In-cluster PostgreSQL OR IBM Cloud, AWS RDS, Azure, GCP
- Storage: In-cluster MinIO OR IBM COS, AWS S3, Azure Blob, GCP Storage
- Auth: In-cluster Keycloak OR IBM Verify, Okta, Azure AD
- Perfect for production and enterprise deployments

### Comprehensive Tooling

- **MLflow** - Experiment tracking and model registry
- **GeoServer** - Geospatial data visualization
- **PostgreSQL** - Metadata storage
- **MinIO** - S3-compatible object storage
- **Redis** - Caching and message queuing

## 🎓 Who Is It For?

### Data Scientists
- Fine-tune models for specific geospatial tasks
- Experiment with different architectures
- Track and compare model performance
- Deploy models for inference

### Researchers
- Process large satellite imagery datasets
- Analyze Earth observation data
- Publish reproducible results
- Collaborate on geospatial AI projects

### Developers
- Build geospatial applications
- Integrate AI capabilities via APIs
- Create custom workflows
- Automate data processing

### Domain Experts
- Use fine-tuned models without coding
- Visualize results on maps
- Extract insights from satellite data
- Monitor environmental changes

## 🌍 Real-World Applications

### Environmental Monitoring
- Track deforestation and reforestation
- Monitor water resources
- Assess ecosystem health
- Measure carbon sequestration

### Disaster Response
- Map flood extent
- Detect wildfire burn scars
- Assess infrastructure damage
- Support emergency planning

### Climate Analysis
- Downscale climate models
- Analyze land use changes
- Monitor glaciers and ice sheets
- Study urban heat islands

### Agriculture
- Crop health monitoring
- Yield prediction
- Irrigation optimization
- Pest detection

### Urban Planning
- Building detection
- Infrastructure mapping
- Population estimation
- Land use classification

## 🔄 Complete ML Lifecycle

Geospatial Studio supports the entire machine learning lifecycle:

```mermaid
graph LR
    A[Data Collection] --> B[Data Preparation]
    B --> C[Model Training]
    C --> D[Model Evaluation]
    D --> E[Model Deployment]
    E --> F[Inference]
    F --> G[Visualization]
    G --> H[Insights]
    H --> A
    
    style A fill:#0f62fe,stroke:#fff,stroke-width:2px,color:#fff
    style B fill:#8a3ffc,stroke:#fff,stroke-width:2px,color:#fff
    style C fill:#33b1ff,stroke:#fff,stroke-width:2px,color:#fff
    style D fill:#007d79,stroke:#fff,stroke-width:2px,color:#fff
    style E fill:#ff7eb6,stroke:#fff,stroke-width:2px,color:#fff
    style F fill:#fa4d56,stroke:#fff,stroke-width:2px,color:#fff
    style G fill:#42be65,stroke:#fff,stroke-width:2px,color:#fff
    style H fill:#f1c21b,stroke:#000,stroke-width:2px,color:#000
```

## 💡 Why Geospatial Studio?

### Accessibility
- **No specialized knowledge required** - Use fine-tuned models out of the box
- **Guided workflows** - Step-by-step processes for common tasks
- **Visual interface** - No coding required for basic operations

### Flexibility
- **Multiple interfaces** - UI, SDK, or API based on your needs
- **Customizable** - Fine-tune models for your specific use case
- **Extensible** - Integrate with existing tools and workflows

### Scalability
- **Cloud-native** - Kubernetes-based architecture
- **GPU acceleration** - Fast training and inference
- **Distributed processing** - Handle large datasets efficiently

### Reproducibility
- **Experiment tracking** - MLflow integration
- **Version control** - Track models and datasets
- **Documented workflows** - Share and reproduce results

## 🚀 Getting Started

Ready to start using Geospatial Studio? Here's what you'll learn in this workshop:

1. **Deploy** the platform in your environment
2. **Navigate** the UI and understand components
3. **Run** inference with fine-tuned models
4. **Onboard** datasets for training
5. **Fine-tune** models for specific tasks
6. **Execute** end-to-end workflows

## 📚 Learn More

- [Architecture Overview →](architecture.md) - Understand how components work together
- [Key Concepts →](key-concepts.md) - Learn essential terminology
- [Official Documentation](https://terrastackai.github.io/geospatial-studio/) - Comprehensive guides

---

[← Back to Welcome](welcome.md){ .md-button } [Next: Architecture →](architecture.md){ .md-button .md-button--primary }
