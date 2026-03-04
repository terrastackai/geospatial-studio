# Sample Payloads

Example payloads for testing and integrating with the Geospatial Studio API.

---

##  Datasets

<div class="payload-grid">
    <button onclick="showExample('burnScarsDataset')" class="payload-card">
        <span class="card-title">Burn Scars Dataset</span>
        <span class="card-desc">Wildfire detection training data</span>
    </button>
    <button onclick="showExample('floodDatasetMultimodal')" class="payload-card">
        <span class="card-title">Multimodal Flood Dataset</span>
        <span class="card-desc">Multi-sensor flood mapping data</span>
    </button>
</div>

---

##  Fine-Tuning Templates

<div class="payload-grid">
    <button onclick="showExample('segmentation')" class="payload-card">
        <span class="card-title">Segmentation</span>
        <span class="card-desc">Generic segmentation template</span>
    </button>
    <button onclick="showExample('regression')" class="payload-card">
        <span class="card-title">Regression</span>
        <span class="card-desc">Regression task template</span>
    </button>
    <button onclick="showExample('terramingSegmentation')" class="payload-card">
        <span class="card-title">Terramind</span>
        <span class="card-desc">Terramind segmentation</span>
    </button>
    <button onclick="showExample('claySegmentation')" class="payload-card">
        <span class="card-title">Clay v1</span>
        <span class="card-desc">Clay backbone segmentation</span>
    </button>
    <button onclick="showExample('resnetSegmentation')" class="payload-card">
        <span class="card-title">ResNet</span>
        <span class="card-desc">ResNet backbone segmentation</span>
    </button>
    <button onclick="showExample('convnextSegmentation')" class="payload-card">
        <span class="card-title">ConvNeXt</span>
        <span class="card-desc">ConvNeXt backbone segmentation</span>
    </button>
    <button onclick="showExample('terratorchIterate')" class="payload-card">
        <span class="card-title">HPO Iterate</span>
        <span class="card-desc">Hyperparameter optimization</span>
    </button>
    <button onclick="showExample('userDefinedtuneTemplate')" class="payload-card">
        <span class="card-title">Custom Template</span>
        <span class="card-desc">User-defined tune template</span>
    </button>
</div>

**Additional Resources:**
- [Download HPO config](../sample_files/burnscars-iterate-hpo.yaml) - Terratorch-iterate fine-tuning
- [View ConvNeXT template](../reference/sample-files.md#convnext-template) - User-defined tuning

---

##  Training Jobs

<div class="payload-grid">
    <button onclick="showExample('floodTuning')" class="payload-card">
        <span class="card-title">Flood Detection</span>
        <span class="card-desc">Fine-tune flood detection model</span>
    </button>
    <button onclick="showExample('burnScarsTuning')" class="payload-card">
        <span class="card-title">Burn Scars</span>
        <span class="card-desc">Fine-tune wildfire model</span>
    </button>
    <button onclick="showExample('completeTune')" class="payload-card">
        <span class="card-title">Upload Complete Tune</span>
        <span class="card-desc">Register existing trained model</span>
    </button>
</div>

**For complete tune upload:**
- `config_url`: [Sample config](../sample_files/prithvi-eo-flood-config.yaml) | [View details](../reference/sample-files.md#floods-finetuning-config-file)
- `checkpoint_url`: [Sample checkpoint](https://geospatial-studio-example-data.s3.us-east.cloud-object-storage.appdomain.cloud/prithvi-eo-flood/prithvi-eo-flood-bestEpoch_Fixed_updated.ckpt)

---

##  Inference

<div class="payload-grid">
    <button onclick="showExample('tryInInference')" class="payload-card">
        <span class="card-title">Try Tune</span>
        <span class="card-desc">Test your trained model</span>
    </button>
    <button onclick="showExample('karenInference')" class="payload-card">
        <span class="card-title">AGB Karen</span>
        <span class="card-desc">Above-ground biomass inference</span>
    </button>
    <button onclick="showExample('californiaInference')" class="payload-card">
        <span class="card-title">California Wildfire</span>
        <span class="card-desc">Park Fire detection example</span>
    </button>
    <button onclick="showExample('addLayer')" class="payload-card">
        <span class="card-title">Add Layer</span>
        <span class="card-desc">Import pre-computed results</span>
    </button>
</div>



<div id="popupTab" class="popup">
  <div class="popup-content">
    <span class="close" onclick="closePopup()">&times;</span>
    <h2 id="popupTitle">Example</h2>
    
    <div class="tab-buttons">
      <button class="tab-btn active" onclick="showTab('json')">JSON</button>
      <button class="tab-btn" onclick="showTab('curl')">cURL Command</button>
    </div>
    
    <div id="jsonTab" class="tab-content active">
      <button onclick="copyToClipboard(event, 'jsonContent')" class="copy-btn">Copy JSON</button>
      <pre><code id="jsonContent" class="language-json"></code></pre>
    </div>
    
    <div id="curlTab" class="tab-content">
      <p>Ensure you export your Studio API key and base API endpoint to your environment variables:</p>
      <button id="envCopy" onclick="copyToClipboard(event, 'envContent')" class="copy-btn">Copy commands</button>
      <pre><code id="envContent" class="language-bash"></code></pre>
      <button id="curlCopy" onclick="copyToClipboard(event, 'curlContent')" class="copy-btn">Copy cURL</button>
      <pre><code id="curlContent" class="language-bash"></code></pre>
    </div>
    
    <div id="loadingMessage" style="text-align: center; padding: 20px; display: none;">
      Loading example...
    </div>
    <div id="errorMessage" style="text-align: center; padding: 20px; color: #f44336; display: none;">
      Failed to load example. Please try again.
    </div>
  </div>
</div>

<style>
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600&display=swap');

.payload-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
  margin: 24px 0;
}

.payload-card {
  font-family: 'IBM Plex Sans', sans-serif;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  padding: 20px;
  background: #ffffff;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  cursor: pointer;
  text-align: left;
  transition: all 0.2s ease;
  min-height: 100px;
}

.payload-card:hover {
  border-color: #0f62fe;
  box-shadow: 0 2px 8px rgba(15, 98, 254, 0.1);
  transform: translateY(-2px);
}

.payload-card:active {
  transform: translateY(0);
}

.card-title {
  font-size: 16px;
  font-weight: 600;
  color: #161616;
  margin-bottom: 8px;
  display: block;
}

.card-desc {
  font-size: 14px;
  color: #525252;
  line-height: 1.4;
  display: block;
}

.popup {
  display: none;
  position: fixed;
  z-index: 1000;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  overflow: auto;
  background-color: rgba(0,0,0,0.5);
}

.popup-content {
  background-color: #fefefe;
  margin: 5% auto;
  padding: 30px;
  border: 1px solid #888;
  border-radius: 10px;
  width: 80%;
  max-width: 800px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.close {
  color: #aaa;
  float: right;
  font-size: 28px;
  font-weight: bold;
  cursor: pointer;
  line-height: 20px;
}

.close:hover,
.close:focus {
  color: #000;
}

.tab-buttons {
  display: flex;
  gap: 10px;
  margin: 20px 0;
  border-bottom: 2px solid #ddd;
}

.tab-btn {
  padding: 10px 20px;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 16px;
  color: #666;
  border-bottom: 3px solid transparent;
  transition: all 0.3s;
}

.tab-btn.active {
  color: #4CAF50;
  border-bottom-color: #4CAF50;
}

.tab-btn:hover {
  color: #4CAF50;
}

.tab-content {
  display: none;
  position: relative;
}

.tab-content.active {
  display: block;
}

.copy-btn {
  position: absolute;
  right: 10px;
  top: 10px;
  padding: 8px 16px;
  background-color: #0f62fe;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  z-index: 10;
}

#envCopy {
    position: absolute;
    right: 10px;
    top: 50px;
}
#curlCopy {
    position: absolute;
    right: 10px;
    top: 130px;
}

.copy-btn:hover {
  background-color: #0b7dda;
}

.tab-content pre {
  background-color: #f5f5f5;
  padding: 20px;
  border-radius: 5px;
  overflow-x: auto;
  margin-top: 10px;
  position: relative;
}

.tab-content code {
  font-family: 'IBM Plex Sans', 'Helvetica Neue', Arial, sans-serif;
  font-size: 14px;
}

.popup {
  display: none;
  position: fixed;
  z-index: 1000;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  overflow: auto;
  background-color: rgba(0,0,0,0.5);
}

.popup-content {
  background-color: #fefefe;
  margin: 5% auto;
  padding: 30px;
  border: 1px solid #888;
  border-radius: 10px;
  width: 80%;
  max-width: 800px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.close {
  color: #aaa;
  float: right;
  font-size: 28px;
  font-weight: bold;
  cursor: pointer;
  line-height: 20px;
}

.close:hover,
.close:focus {
  color: #000;
}

.tab-buttons {
  display: flex;
  gap: 10px;
  margin: 20px 0;
  border-bottom: 2px solid #ddd;
}

.tab-btn {
  padding: 10px 20px;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 16px;
  color: #666;
  border-bottom: 3px solid transparent;
  transition: all 0.3s;
}

.tab-btn.active {
  color: #4CAF50;
  border-bottom-color: #4CAF50;
}

.tab-btn:hover {
  color: #4CAF50;
}

.tab-content {
  display: none;
  position: relative;
}

.tab-content.active {
  display: block;
}

.copy-btn {
  position: absolute;
  right: 10px;
  top: 10px;
  padding: 8px 16px;
  background-color: #0f62fe;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  z-index: 10;
}

#envCopy {
    position: absolute;
    right: 10px;
    top: 50px;
}
#curlCopy {
    position: absolute;
    right: 10px;
    top: 130px;
}

.copy-btn:hover {
  background-color: #0b7dda;
}

.tab-content pre {
  background-color: #f5f5f5;
  padding: 20px;
  border-radius: 5px;
  overflow-x: auto;
  margin-top: 10px;
  position: relative;
}

.tab-content code {
  font-family: 'IBM Plex Sans', 'Helvetica Neue', Arial, sans-serif;
  font-size: 14px;
}
</style>

<script>
const exampleConfigs = {
  burnScarsDataset: {
    title: "Burn scars Dataset",
    jsonFile: "/payloads/datasets/dataset-burn_scars.json",
    endpoint: "/v2/datasets/onboard",
    method: "POST"
  },
  floodDatasetMultimodal: {
    title: "Multi-modal flood dataset",
    jsonFile: "/payloads/datasets/dataset-flooding_multimodal.json",
    endpoint: "/v2/datasets/onboard",
    method: "POST"
  },
  regression: {
    title: "Regression template",
    jsonFile: "/payloads/templates/template-reg.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  segmentation: {
    title: "Generic segmentation template",
    jsonFile: "/payloads/templates/template-seg.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  terramingSegmentation: {
    title: "Terramind segmentation template",
    jsonFile: "/payloads/templates/template-terramind_seg.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  claySegmentation: {
    title: "Clay backbone models segmentation template",
    jsonFile: "/payloads/templates/template-clay_v1_seg.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  resnetSegmentation: {
    title: "Resnet backbone models segmentation template",
    jsonFile: "/payloads/templates/template-timm_resnet_seg.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  convnextSegmentation: {
    title: "Convnext backbone models segmentation template",
    jsonFile: "/payloads/templates/template-timm_convnext_seg.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  terratorchIterate:{
    title:"terratorch-iterate",
    jsonFile:"/payloads/finetuning/terratorch-iterate-hpo.json",
    endpoint:"/v2/submit-hpo-tune",
    method:"POST"
  },
  userDefinedtuneTemplate:{
    title:"terratorch-iterate",
    jsonFile:"/payloads/finetuning/create-user-defined-template.json",
    endpoint:"/v2/tune-templates",
    method:"POST"
  },
  floodTuning: {
    title: "Example configs for fine-tuning a flood model",
    jsonFile: "/payloads/tunes/tune-prithvi-eo-flood.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  burnScarsTuning: {
    title: "Example configs for fine-tuning a burn-scars model",
    jsonFile: "/payloads/tunes/tune-test-fire.json",
    endpoint: "/v2/tune-templates",
    method: "POST"
  },
  completeTune:{
    title: "Register your tune to the studio platform ",
    jsonFile: "/payloads/finetuning/complete-tune.json",
    endpoint:"/v2/submit-hpo-tune",
    method:"POST",
  },
  karenInference: {
    title: "Example config for inference run",
    jsonFile: "/payloads/inferences/inference-agb-karen.json",
    endpoint: "/v2/inference",
    method: "POST"
  },
  tryInInference: {
    title: "Example config for trying out a tune",
    jsonFile: "/payloads/sandbox-models/model-try-in-lab.json",
    endpoint: "/v2/tunes/{tune-id}/try-out",
    method: "POST"
  },
   californiaInference: {
    title: "Example config for trying out a tune",
    jsonFile: "/payloads/inferences/california-fire-park.json",
    endpoint: "/v2/tunes/{tune-id}/try-out",
    method: "POST"
  },
  addLayer: {
    title: "Example config for adding pre-computed examples to the studio",
    jsonFile: "/payloads/sandbox-models/model-add-layer.json",
    endpoint: "/v2/inference",
    method: "POST"
  }
};

async function loadJsonFile(filePath) {
  try {
    const response = await fetch(filePath);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Error loading JSON file:', error);
    throw error;
  }
}

async function showExample(exampleKey) {
  const config = exampleConfigs[exampleKey];
  const modal = document.getElementById('popupTab');
  const popupTitle = document.getElementById('popupTitle');
  const jsonContent = document.getElementById('jsonContent');
  const curlContent = document.getElementById('curlContent');
  const envContent = document.getElementById('envContent');
  const loadingMessage = document.getElementById('loadingMessage');
  const errorMessage = document.getElementById('errorMessage');
  const tabContents = document.querySelectorAll('.tab-content');
  
  modal.style.display = 'block';
  popupTitle.textContent = config.title;
  loadingMessage.style.display = 'block';
  errorMessage.style.display = 'none';
  
  try {
    const jsonData = await loadJsonFile(config.jsonFile);
    console.log(JSON.stringify(jsonData))
    
    loadingMessage.style.display = 'none';
    
    jsonContent.textContent = JSON.stringify(jsonData, null, 2);
    
    const curlCommand = `curl -X ${config.method} "\${STUDIO_API_URL}${config.endpoint}" \
  -H 'Content-Type: application/json' \
  -H "X-API-Key: \$API_KEY" \
  --insecure \
  -d '${JSON.stringify(jsonData, null, 2)}'`;
    
    curlContent.textContent = curlCommand;

    const exportVariable = `export STUDIO_API_URL=https://gfm.res.ibm.com/studio-gateway \\
export API_KEY=YOUR_API_KEY`;

    envContent.textContent = exportVariable;

    
    showTab('json');
    
  } catch (error) {
    loadingMessage.style.display = 'none';
    errorMessage.style.display = 'block';
    errorMessage.textContent = `Failed to load example: ${error.message}`;
  }
}

function closePopup() {
  document.getElementById('popupTab').style.display = 'none';
}

function showTab(tabName) {
  document.querySelectorAll('.tab-content').forEach(tab => {
    tab.classList.remove('active');
  });
  
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.classList.remove('active');
  });
  
  if (tabName === 'json') {
    document.getElementById('jsonTab').classList.add('active');
    document.querySelectorAll('.tab-btn')[0].classList.add('active');
  } else {
    document.getElementById('curlTab').classList.add('active');
    document.querySelectorAll('.tab-btn')[1].classList.add('active');
  }
}

function copyToClipboard(event, elementId) {
  const element = document.getElementById(elementId);
  const text = element.textContent;
  const button = event.currentTarget;
  
  navigator.clipboard.writeText(text).then(() => {
    const originalText = button.textContent;
    
    button.textContent = 'Copied!';
    button.style.backgroundColor = '#4CAF50';
    
    setTimeout(() => {
      button.textContent = originalText;
      button.style.backgroundColor = '#2196F3';
    }, 2000);
  }).catch(err => {
    console.error('Failed to copy:', err);
    alert('Failed to copy to clipboard');
  });
}

window.onclick = function(event) {
  const modal = document.getElementById('popupTab');
  if (event.target === modal) {
    closePopup();
  }
}
</script>