# Workshop Notebooks

This directory contains Jupyter notebooks for each lab in the Geospatial Studio Workshop.

## Available Notebooks

### Lab 1: Getting Started with IBM Geospatial Studio
**File:** `lab1-getting-started.ipynb`

Learn to:
- Install and configure the Geospatial Studio SDK
- Generate and use API keys
- Connect to your Studio instance
- List models and datasets
- Run basic SDK operations

**Estimated Time:** 10 minutes | **Difficulty:** Beginner

---

### Lab 2: Onboarding Pre-computed Examples
**File:** `lab2-onboarding-examples.ipynb`

Learn to:
- Upload geospatial files to temporary storage
- Configure layer styling (RGB, segmentation, regression)
- Onboard raster data (GeoTIFF, NetCDF)
- Onboard vector data (Shapefiles, GeoPackage)
- Visualize examples in the Studio UI

**Estimated Time:** 20 minutes | **Difficulty:** Beginner

---

### Lab 3: Upload Model Checkpoints and Run Inference
**File:** `lab3-running-inference.ipynb`

Learn to:
- Upload model checkpoints to Studio
- Select models for inference
- Define spatial domains (bounding boxes, URLs)
- Specify temporal domains for satellite data
- Submit and monitor inference requests
- Download and visualize results
- Run batch inference

**Estimated Time:** 30 minutes | **Difficulty:** Intermediate

---

### Lab 4: Training a Custom Model for Wildfire Burn Scar Detection
**File:** `lab4-burnscars-workflow.ipynb`

Complete an end-to-end workflow:
- Onboard a labeled training dataset
- Select foundation model and configure hyperparameters
- Submit and monitor model fine-tuning
- Test the fine-tuned model
- Run production inference on real wildfire events
- Generate analysis reports

**Estimated Time:** 60-90 minutes (includes model training) | **Difficulty:** Intermediate

**Note:** Requires GPU access for model training. Alternatives provided for non-GPU environments.

---

## How to Use These Notebooks

### Prerequisites

1. **Geospatial Studio Deployed:** Complete the [Pre-work](../prework/index.md) section
2. **Python Environment:** Python 3.11+ with Jupyter installed
3. **SDK Installed:** `pip install geostudio`
4. **API Key:** Generated from your Studio UI

### Getting the Notebooks

**Clone the Repository** (Required)

The notebooks require the full repository structure as they reference shared configuration files:

```bash
# Clone the repository
git clone https://github.com/terrastackai/geospatial-studio.git

# Navigate to the workshop notebooks directory
cd geospatial-studio/workshop/docs/notebooks

# Start Jupyter
jupyter notebook
```

**Why the full repository is required:**

- ✅ Notebooks reference JSON configs from `populate-studio/payloads/`
- ✅ Proper directory structure for all file paths
- ✅ Easy to update with `git pull`
- ✅ Access to all workshop materials and shared resources

### Running the Notebooks

1. **Open** the notebook for your current lab
2. **Follow** the instructions in each cell
3. **Execute** cells sequentially from top to bottom

### Configuration

Before running any notebook, you'll need to configure your credentials:

```bash
# Create a config file
echo "GEOSTUDIO_API_KEY=your-api-key-here" > ~/.geostudio_config
echo "BASE_STUDIO_UI_URL=your-studio-url-here" >> ~/.geostudio_config
```

Example:
```bash
echo "GEOSTUDIO_API_KEY=gs_1234567890abcdef" > ~/.geostudio_config
echo "BASE_STUDIO_UI_URL=https://localhost:4180" >> ~/.geostudio_config
```

---

## Notebook Sources

These notebooks are adapted from the official Geospatial Studio examples:

- **Lab 1:** Based on [`getting-started-notebook.ipynb`](https://github.com/terrastackai/geospatial-studio/blob/main/populate-studio/getting-started-notebook.ipynb)
- **Lab 2:** Based on [`002-Add-Precomputed-Examples.ipynb`](https://github.com/terrastackai/geospatial-studio-toolkit/blob/main/examples/inference/002-Add-Precomputed-Examples.ipynb)
- **Lab 3:** Based on [`001-Introduction-to-Inferencing.ipynb`](https://github.com/terrastackai/geospatial-studio-toolkit/blob/main/examples/inference/001-Introduction-to-Inferencing.ipynb)
- **Lab 4:** Based on [`GeospatialStudio-Walkthrough-BurnScars.ipynb`](https://github.com/terrastackai/geospatial-studio-toolkit/blob/main/examples/e2e-walkthroughs/GeospatialStudio-Walkthrough-BurnScars.ipynb)

---

## Additional Resources

- [Geospatial Studio Documentation](https://terrastackai.github.io/geospatial-studio/)
- [SDK Documentation](https://terrastackai.github.io/geospatial-studio-toolkit/)
- [More Example Notebooks](https://github.com/terrastackai/geospatial-studio-toolkit/tree/main/examples)
- [Workshop Documentation](../index.md)

---

## Troubleshooting

### Import Errors

If you get import errors:
```bash
pip install geostudio --upgrade
```

### Connection Issues

If you can't connect to Studio:
1. Verify Studio is running
2. Check port forwarding (for local deployments)
3. Verify your API key is correct
4. Check the base URL is accessible

### Notebook Kernel Issues

If the kernel crashes:
1. Restart the kernel: `Kernel` → `Restart`
2. Clear outputs: `Cell` → `All Output` → `Clear`
3. Run cells sequentially from the top

---

## Support

For issues or questions:
- Check the [Troubleshooting Guide](../resources/troubleshooting.md)
- Review the [FAQ](../resources/faq.md)
- Open an issue on [GitHub](https://github.com/terrastackai/geospatial-studio/issues)