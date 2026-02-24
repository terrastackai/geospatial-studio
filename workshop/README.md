# IBM Geospatial Studio Workshop

A comprehensive, hands-on workshop for learning IBM Geospatial Studio - from deployment to running geospatial AI models.

## 📚 Overview

This workshop provides a complete learning path for IBM Geospatial Studio, designed for beginners who have never heard of the platform before. It covers:

- **Pre-work**: Deployment guides with compute requirements and prerequisites
- **Introduction**: Understanding Geospatial Studio architecture and key concepts
- **Hands-on Labs**: Four progressive labs with Jupyter notebooks
- **Resources**: Troubleshooting guides, FAQs, and next steps

## 🎯 Workshop Structure

### Pre-work (60-90 minutes)
- System prerequisites and compute requirements
- Deployment options (local Lima VM or Kubernetes cluster)
- Environment verification

### Introduction (30 minutes)
- What is Geospatial Studio
- Architecture overview
- Key concepts and terminology

### Labs

1. **Lab 1: Getting Started with SDK** (30 minutes)
   - SDK installation and configuration
   - API key management
   - Basic client operations

2. **Lab 2: Onboarding Pre-computed Examples** (45 minutes)
   - Layer onboarding with various data formats
   - Working with GeoTIFF, COG, and STAC catalogs
   - Dataset management

3. **Lab 3: Running Inference** (60 minutes)
   - Running models on new geographic areas
   - Understanding model inputs and outputs
   - Visualizing results

4. **Lab 4: End-to-End Burn Scars Workflow** (90-120 minutes)
   - Complete ML workflow from dataset to production
   - Fine-tuning models
   - Deploying and monitoring

**Total Workshop Time**: 4.5 - 6 hours

## 🚀 Quick Start

### Prerequisites

- **Operating System**: macOS, Linux, or Windows with WSL2
- **Memory**: 16GB RAM minimum, 32GB recommended
- **Storage**: 50GB free disk space
- **Python**: 3.11 or higher
- **Tools**: Docker, Helm v3.19+, kubectl (for cluster deployment)

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/terrastackai/geospatial-studio.git
   cd geospatial-studio/workshop
   ```

2. **Install dependencies** (from repository root):
   ```bash
   cd ..
   pip install hatch
   hatch env create
   ```

3. **Serve the documentation locally**:
   ```bash
   # From repository root
   hatch run serve-workshop
   ```
   
   The workshop will be available at `http://127.0.0.1:8001`

4. **Build the documentation**:
   ```bash
   # From repository root
   hatch run build-workshop
   ```
   
   The static site will be generated in the `workshop/site/` directory.

## 📓 Jupyter Notebooks

All lab notebooks are maintained in a **single location**:

- **`notebooks/`**: Single source of truth for all workshop notebooks

The MkDocs build hook automatically copies notebooks from `notebooks/` to `site/notebooks/` during build. This ensures:
- ✅ No duplication
- ✅ Easy maintenance (edit once)
- ✅ Automatic synchronization

Each lab page includes a download button to get the notebook for local execution.

## 🛠️ Development

### Project Structure

```
workshop/
├── docs/                      # Documentation source
│   ├── index.md              # Home page
│   ├── prework/              # Pre-work guides
│   ├── introduction/         # Introduction content
│   ├── notebooks/            # Jupyter notebooks
│   ├── resources/            # Additional resources
│   ├── assets/               # Images and static files
│   └── stylesheets/          # Custom CSS
├── mkdocs.yml                # MkDocs configuration
├── hooks.py                  # Custom MkDocs hooks
└── README.md                 # This file
```

**Note**: This workshop is part of the main geospatial-studio repository. Dependencies are managed in the root `pyproject.toml` using hatch.

### Build System

The workshop uses **hatch** for dependency management and building:

- **Dependencies**: Defined in root `pyproject.toml`
- **Build commands**: `hatch run build-workshop`
- **Serve commands**: `hatch run serve-workshop` (runs on port 8001)
- **Configuration**: `mkdocs.yml` with site_url set to `/workshop` subdirectory

### Adding New Content

1. **Add a new lab notebook**:
   - Create the notebook in `docs/notebooks/`
   - Add it to the `nav` section in `mkdocs.yml`
   - Notebooks are automatically rendered by the `mkdocs-jupyter` plugin

2. **Update existing content**:
   - Edit the markdown files in `docs/`
   - Test locally with `hatch run serve-workshop`

3. **Add images**:
   - Place images in `docs/assets/`
   - Reference them in markdown: `![Alt text](../assets/image.png)`

## 🎨 Theme and Styling

The workshop uses the Material for MkDocs theme with:

- **Dark mode**: IBM Carbon color palette for diagrams
- **Syntax highlighting**: Monokai theme for code blocks
- **Custom CSS**: IBM Plex Sans font family
- **Icons**: Material Design icons with emoji support

## 🔧 Technical Details

### MkDocs Plugins

- **mkdocs-jupyter**: Renders Jupyter notebooks as pages
- **git-revision-date-localized**: Shows last update dates
- **glightbox**: Image lightbox functionality
- **search**: Full-text search

### Markdown Extensions

- **Admonitions**: Note, warning, tip boxes
- **Code highlighting**: Syntax highlighting for 100+ languages
- **Mermaid diagrams**: Architecture and flow diagrams
- **Tables**: GitHub-flavored markdown tables
- **Math**: LaTeX math rendering with MathJax

## 📖 Documentation

- **Published Workshop**: https://terrastackai.github.io/geospatial-studio/workshop/
- **Geospatial Studio Docs**: https://terrastackai.github.io/geospatial-studio/
- **Toolkit Docs**: https://terrastackai.github.io/geospatial-studio-toolkit/

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `hatch run serve-workshop`
5. Submit a pull request to the main geospatial-studio repository

## 📝 License

This workshop is part of the IBM Geospatial Studio project. See individual repository licenses for details.

## 🆘 Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Join the community discussions
- **Documentation**: Check the official Geospatial Studio documentation

## 🙏 Acknowledgments

This workshop is based on the excellent examples from:
- [IBM Granite Workshop](https://ibm.github.io/granite-workshop/)
- [Docling Workshop](https://ibm-granite-community.github.io/docling-workshop/)

Built with ❤️ by the IBM Research team and the TerraStackAI community.

---