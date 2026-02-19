# Frequently Asked Questions (FAQ)

Common questions about IBM Geospatial Studio and this workshop.

## 🎯 General Questions

### What is IBM Geospatial Studio?

IBM Geospatial Studio is an open-source platform for training, fine-tuning, and deploying geospatial AI models. It provides:

- Pre-trained foundation models (Prithvi, Clay, etc.) as starting points
- Tools for dataset onboarding and management
- Model fine-tuning capabilities
- Inference pipeline for running models at scale
- Web UI and Python SDK for easy interaction

### Who is this workshop for?

This workshop is designed for:

- **Data scientists** interested in geospatial AI
- **Remote sensing professionals** wanting to apply ML
- **Developers** building geospatial applications
- **Researchers** working with satellite imagery
- **Anyone** curious about geospatial foundation models

No prior geospatial experience required, but basic Python knowledge is helpful.

### What will I learn in this workshop?

By completing this workshop, you will:

- Deploy Geospatial Studio locally or on a cluster
- Understand geospatial AI concepts and workflows
- Use the Python SDK to interact with the platform
- Onboard and manage geospatial datasets
- Run inference with fine-tuned models
- Fine-tune foundation models for custom tasks
- Visualize and analyze results

### How long does the workshop take?

**Total time:** 3-4 hours

- **Pre-work (deployment):** 1-1.5 hours
- **Introduction:** 15 minutes
- **Lab 1 (Getting Started with IBM Geospatial Studio):** 10 minutes
- **Lab 2 (Onboarding Pre-computed Examples):** 20 minutes
- **Lab 3 (Upload Model Checkpoints and Run Inference):** 30 minutes
- **Lab 4 (Training a Custom Model for Wildfire Burn Scar Detection):** 60-90 minutes

You can complete labs at your own pace and take breaks as needed.

## 💻 Technical Questions

### What are the system requirements?

**Minimum requirements:**
- **CPU:** 8 cores
- **RAM:** 16GB
- **Storage:** 100GB free space
- **GPU:** Optional but recommended (8GB+ VRAM)
- **OS:** Linux, macOS, or Windows with WSL2

**Recommended for production:**
- **CPU:** 16+ cores
- **RAM:** 32GB+
- **Storage:** 100GB+ SSD
- **GPU:** NVIDIA GPU with 16GB+ VRAM
- **OS:** Linux (Ubuntu 20.04+)

### Do I need a GPU?

**For this workshop:** No, GPU is optional. You can complete all labs using CPU-only mode.

**For production use:** Yes, GPU is highly recommended for:
- Model training (fine-tuning)
- Large-scale inference
- Faster processing times

CPU-only mode works but is significantly slower for training and inference.

### What programming languages are supported?

**Primary:** Python 3.9+

The Geospatial Studio SDK is Python-based. You can also interact with the platform via:
- REST API (any language)
- Web UI (no coding required)

### Can I use my own data?

**Yes!** You can onboard your own datasets in several ways:

1. **Upload ZIP files** containing imagery and labels
2. **Provide URLs** to cloud-stored data
3. **Use Sentinel Hub** for on-demand data access
4. **Connect to S3** or other object storage

Supported formats:
- GeoTIFF (.tif, .tiff)
- Cloud Optimized GeoTIFF (COG)
- HDF5 (.h5, .hdf5)

### What satellite data sources are supported?

**Built-in support:**
- NASA Harmonized Landsat Sentinel-2 (HLS)
- Sentinel-2 (via Sentinel Hub)
- Landsat 8/9 (via Sentinel Hub)
- Custom data sources via URL

**Data connectors:**
- Sentinel Hub API
- Direct file URLs
- S3-compatible storage
- Local file system

## 🤖 Model Questions

### What foundation models are available?

**Pre-loaded models:**
- **Prithvi EO V1 (100M)** - NASA/IBM geospatial foundation model
- **Prithvi EO V2 (300M)** - Larger, more capable version
- **Clay V1** - Self-supervised geospatial model
- **Custom models** - You can add your own

**Model capabilities:**
- Segmentation (pixel-level classification)
- Regression (continuous value prediction)
- Classification (image-level labels)

### Can I use my own models?

**Yes!** You can:

1. **Upload custom base models** to use as foundation models
2. **Import fine-tuned checkpoints** from external training
3. **Export trained models** for use elsewhere
4. **Register models** with the inference service

Models must be compatible with the Terratorch framework (PyTorch-based).

### How long does model training take?

**Training time depends on:**
- Dataset size (number of samples)
- Model size (100M vs 300M parameters)
- Hardware (GPU vs CPU)
- Training parameters (epochs, batch size)

**Typical times:**
- **Small dataset (100 samples):** 10-30 minutes (GPU)
- **Medium dataset (1000 samples):** 1-3 hours (GPU)
- **Large dataset (10000 samples):** 6-12 hours (GPU)

CPU training is 10-50x slower than GPU.

### What tasks can I train models for?

**Supported tasks:**
- **Segmentation:** Flood mapping, burn scar detection, land cover classification
- **Regression:** Biomass estimation, crop yield prediction, temperature mapping
- **Classification:** Land use type, cloud detection, change detection

**Custom tasks:** You can create custom task templates for specialized applications.

## 📊 Data Questions

### What format should my training data be in?

**Required structure:**
```
dataset.zip
├── image_001_merged.tif    # Input imagery (multi-band)
├── image_001_mask.tif      # Labels/ground truth
├── image_002_merged.tif
├── image_002_mask.tif
└── ...
```

**Requirements:**
- Matching pairs of data and labels
- Same spatial extent and resolution
- Consistent band configuration
- GeoTIFF format with proper georeferencing

### How many training samples do I need?

**Minimum:** 50-100 samples for basic fine-tuning

**Recommended:**
- **Simple tasks:** 200-500 samples
- **Complex tasks:** 1000+ samples
- **Production models:** 5000+ samples

Foundation models require less data than training from scratch due to transfer learning.

### What image resolution is supported?

**Flexible resolution support:**
- Models work with various resolutions (10m, 30m, etc.)
- Input images are automatically tiled if too large
- Recommended: 224x224 to 512x512 pixel tiles

**HLS data:** 30m resolution (Landsat) or 10m (Sentinel-2)

### Can I use multi-temporal data?

**Yes!** The platform supports:
- Single-date imagery
- Multi-date time series
- Before/after comparisons
- Seasonal analysis

Specify multiple dates in the temporal domain:
```python
"temporal_domain": [
    "2024-01-01_2024-01-15",
    "2024-06-01_2024-06-15"
]
```

## 🔄 Workflow Questions

### What's the typical workflow?

**Standard workflow:**

1. **Deploy Studio** - Set up the platform
2. **Onboard data** - Upload or connect to datasets
3. **Explore data** - Visualize in UI or SDK
4. **Select model** - Choose foundation model
5. **Configure training** - Set hyperparameters
6. **Fine-tune** - Train model on your data
7. **Validate** - Check metrics and visualizations
8. **Deploy** - Register model for inference
9. **Run inference** - Process new imagery
10. **Analyze results** - Visualize and export outputs

### Can I skip model training?

**Yes!** You can use existing fine-tuned models directly:

- Use models already in the catalog
- Run inference without additional training
- Test models on your area of interest
- Evaluate if further fine-tuning is needed

Fine-tuned models in the catalog work well for common tasks (floods, fires, etc.) but may need additional fine-tuning for specialized applications.

### How do I choose hyperparameters?

**Start with defaults:**
- The platform provides sensible defaults
- Works well for most use cases

**Tune if needed:**
- Learning rate: 1e-5 to 1e-4
- Batch size: 2-8 (depends on GPU memory)
- Epochs: 10-50 (monitor validation loss)

**Use HPO (Hyperparameter Optimization):**
- Automated tuning with Ray Tune
- Finds optimal parameters
- Requires more compute time

### Can I pause and resume training?

**Yes!** Training can be:
- Paused and resumed from checkpoints
- Stopped early if validation loss plateaus
- Restarted with different parameters

Checkpoints are saved automatically during training.

## 🌐 Deployment Questions

### Can I deploy in the cloud?

**Yes!** Deployment options:

1. **Local development** - Docker Compose on laptop
2. **Single server** - VM or bare metal
3. **Kubernetes cluster** - Scalable cloud deployment
4. **IBM Cloud** - Managed deployment (coming soon)

See [Deployment Options](../prework/deployment-options.md) for details.

### Is it production-ready?

**Current status:** Beta/Research preview

**Production considerations:**
- Core functionality is stable
- Active development and improvements
- Community support available
- Enterprise support coming soon

**Recommended for:**
- Research projects
- Proof of concepts
- Development environments
- Small-scale production (with testing)

### How do I scale for production?

**Scaling strategies:**

1. **Horizontal scaling** - Add more inference workers
2. **GPU acceleration** - Use multiple GPUs
3. **Distributed training** - Multi-node training
4. **Caching** - Cache frequently accessed data
5. **Load balancing** - Distribute requests

Kubernetes deployment supports auto-scaling.

### What about data privacy?

**Data handling:**
- All data stays in your environment
- No data sent to external services (except Sentinel Hub if used)
- You control storage and access
- Can run fully air-gapped

**Security features:**
- OAuth2 authentication
- API key management
- Role-based access control (RBAC)
- SSL/TLS encryption

## 🔧 Integration Questions

### Can I integrate with existing tools?

**Yes!** Integration options:

**APIs:**
- REST API for all operations
- Python SDK for programmatic access
- OpenAPI/Swagger documentation

**Data formats:**
- GeoTIFF output (standard format)
- GeoJSON for vector data
- COG (Cloud Optimized GeoTIFF)

**Visualization:**
- GeoServer for map services
- WMS/WFS standards
- Compatible with QGIS, ArcGIS, etc.

### Does it work with Jupyter notebooks?

**Yes!** Full Jupyter support:

- SDK designed for notebooks
- Interactive widgets for visualization
- Example notebooks provided
- Works with JupyterLab and Jupyter Notebook

### Can I export trained models?

**Yes!** Export options:

- PyTorch checkpoints (.ckpt)
- ONNX format (for deployment)
- TorchScript (for production)
- MLflow model registry

Models can be used outside Geospatial Studio.

### Is there a REST API?

**Yes!** Full REST API available:

- All UI features accessible via API
- OpenAPI/Swagger documentation
- Authentication via API keys
- Rate limiting and quotas

API docs: `https://your-studio-url/api/docs`

## 💰 Cost Questions

### Is Geospatial Studio free?

**Yes!** Geospatial Studio is:
- Open source (Apache 2.0 license)
- Free to use
- Free to modify
- Free to distribute

### What about infrastructure costs?

**You pay for:**
- Compute resources (VMs, GPUs)
- Storage (disk space, object storage)
- Network bandwidth
- Satellite data access (if using commercial sources)

**Cost optimization:**
- Use spot instances for training
- Scale down when not in use
- Use CPU for development, GPU for production
- Cache frequently accessed data

### Are there any usage limits?

**No built-in limits** in the open-source version.

**Practical limits:**
- Hardware capacity
- Storage space
- Network bandwidth
- Satellite data quotas (Sentinel Hub)

You control all resources and limits.

## 📚 Learning Questions

### I'm new to geospatial AI. Where do I start?

**Recommended path:**

1. **Complete this workshop** - Hands-on introduction
2. **Read Key Concepts** - Understand terminology
3. **Explore examples** - Pre-computed datasets
4. **Try simple tasks** - Flood or fire detection
5. **Read documentation** - Deep dive into features

**Additional resources:**
- [Geospatial Studio Docs](https://terrastackai.github.io/geospatial-studio/)
- [Terratorch Tutorials](https://ibm.github.io/terratorch/tutorials/)
- [Additional Resources](additional-resources.md)

### What if I get stuck?

**Help resources:**

1. **Troubleshooting Guide** - Common issues and solutions
2. **Documentation** - Comprehensive guides
3. **GitHub Issues** - Search existing problems
4. **Community** - Ask questions, share experiences

See [Troubleshooting](troubleshooting.md) for detailed help.

### Can I contribute to the project?

**Yes! Contributions welcome:**

- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation
- Share use cases and examples

See [Contributing Guidelines](https://github.com/terrastackai/geospatial-studio/blob/main/CONTRIBUTING.md)

## 🎓 Next Steps

### What should I do after the workshop?

**Immediate next steps:**
1. Try with your own data
2. Experiment with different models
3. Fine-tune for your use case
4. Share results with community

**Long-term:**
1. Deploy in production
2. Integrate with existing workflows
3. Contribute improvements
4. Build custom applications

See [Next Steps](next-steps.md) for detailed guidance.

### Where can I find more examples?

**Example sources:**
- Workshop notebooks (this repository)
- [Geospatial Studio Examples](https://github.com/terrastackai/geospatial-studio/tree/main/examples)
- [Terratorch Examples](https://github.com/IBM/terratorch/tree/main/examples)
- [Hugging Face Models](https://huggingface.co/ibm-nasa-geospatial)

### How do I stay updated?

**Stay informed:**
- Watch GitHub repositories
- Follow IBM Research blog
- Join community discussions
- Subscribe to release notes

**Key repositories:**
- [Geospatial Studio](https://github.com/terrastackai/geospatial-studio)
- [Geospatial Studio Toolkit](https://github.com/terrastackai/geospatial-studio-toolkit)
- [Terratorch](https://github.com/IBM/terratorch)

---

**Still have questions?** 

- Check [Troubleshooting](troubleshooting.md) for technical issues
- Review [Additional Resources](additional-resources.md) for more documentation
- Open an issue on [GitHub](https://github.com/terrastackai/geospatial-studio/issues)

---

[← Back: Troubleshooting](troubleshooting.md){ .md-button } [Next: Next Steps →](next-steps.md){ .md-button .md-button--primary }
