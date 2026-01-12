# Sample Payloads

Here are a few example payloads you can use when testing out the studio and as a guide when Onboarding your own datasets to the studio, fine-tuning and running inference.

## Dataset onboarding

Click below to see example configurations for onboarding a new dataset to the studio:

<div class=datasets>
    <button onclick="showExample('burnScarsDataset')" class="button">Burn scars dataset</button>
    <button onclick="showExample('floodDatasetMultimodal')" class="button">Multimodal flooding dataset</button>
</div>

## Fine-tuning

### Tuning templates

Click below for sample configs for each of the tune templates we have in the studio:

<div class=tuning-templates>
    <button onclick="showExample('regression')" class="button">Regression</button>
    <button onclick="showExample('segmentation')" class="button">Segmentation</button>
    <button onclick="showExample('terramingSegmentation')" class="button">terramind: Segmentation</button>
    <button onclick="showExample('claySegmentation')" class="button">clay_v1 : Segmentation</button>
    <button onclick="showExample('resnetSegmentation')" class="button">timm_resnet : Segmentation</button>
    <button onclick="showExample('convnextSegmentation')" class="button">timm_convnext : Segmentation</button>
</div>

### Tunes

Click below for example payloads for running a fine-tuning job through the studio:

<div class=tunes>
    <button onclick="showExample('floodTuning')" class="button">Flooding tuning</button>
    <button onclick="showExample('burnScarsTuning')" class="button">Burn scars tuning</button>
</div>

## Inference

Click below for example payloads for submitting an inference request through the studio:

<div class=inference>
    <button onclick="showExample('karenInference')" class="button">Inference agb Karen</button>
    <button onclick="showExample('tryInInference')" class="button">Try tune in lab</button>
    <button onclick="showExample('addLayer')" class="button">Add layer example</button>    
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
      <button onclick="copyToClipboard(event, 'curlContent')" class="copy-btn">Copy cURL</button>
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

.tuning-templates, .datasets, .inference, .tunes {
  display: flex;
  gap: 15px;
  flex-wrap: wrap;
  margin: 30px 0;
}

.button {
    font-family: 'IBM Plex Sans', 'Helvetica Neue', Arial, sans-serif;
    font-size: 0.875rem;
    font-weight: 400;
    line-height: 1.125rem;
    letter-spacing: 0.16px;
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.875rem 3.9375rem 0.875rem 1rem;
    border: none;
    cursor: pointer;
    text-align: left;
    text-decoration: none;
    transition: background 70ms cubic-bezier(0, 0, 0.38, 0.9),
                box-shadow 70ms cubic-bezier(0, 0, 0.38, 0.9),
                border-color 70ms cubic-bezier(0, 0, 0.38, 0.9),
                outline 70ms cubic-bezier(0, 0, 0.38, 0.9);
    min-height: 3rem;
    max-width: 20rem;
    background-color: #0f62fe;
    color: #ffffff;
    border: 1px solid transparent;
}

.button:focus {
    outline: 2px solid #0f62fe;
    outline-offset: -2px;
}

.button:hover {
  background-color: #0353e9;
}

.button:active {
    background-color: #002d9c;
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
    jsonFile: "../populate-studio/payloads/datasets/dataset-burn_scars.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/datasets/onboard",
    method: "POST"
  },
  floodDatasetMultimodal: {
    title: "Multi-modal flood dataset",
    jsonFile: "../populate-studio/payloads/datasets/dataset-flooding_multimodal.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/datasets/onboard",
    method: "POST"
  },
  regression: {
    title: "Regression template",
    jsonFile: "../populate-studio/payloads/templates/template-reg.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  segmentation: {
    title: "Generic segmentation template",
    jsonFile: "../populate-studio/payloads/templates/template-seg.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  terramingSegmentation: {
    title: "Terramind segmentation template",
    jsonFile: "../populate-studio/payloads/templates/template-terramind_seg.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  claySegmentation: {
    title: "Clay backbone models segmentation template",
    jsonFile: "../populate-studio/payloads/templates/template-clay_v1_seg.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  resnetSegmentation: {
    title: "Resnet backbone models segmentation template",
    jsonFile: "../populate-studio/payloads/templates/template-timm_resnet_seg.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  convnextSegmentation: {
    title: "Convnext backbone models segmentation template",
    jsonFile: "../populate-studio/payloads/templates/template-timm_convnext_seg.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  floodTuning: {
    title: "Example configs for fine-tuning a flood model",
    jsonFile: "../populate-studio/payloads/tunes/tune-prithvi-eo-flood.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  burnScarsTuning: {
    title: "Example configs for fine-tuning a burn-scars model",
    jsonFile: "../populate-studio/payloads/tunes/tune-test-fire.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tune-templates",
    method: "POST"
  },
  karenInference: {
    title: "Example config for inference run",
    jsonFile: "../populate-studio/payloads/inferences/inference-agb-karen.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/inference",
    method: "POST"
  },
  tryInInference: {
    title: "Example config for trying out a tune",
    jsonFile: "../populate-studio/payloads/sandbox-models/model-try-in-lab.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/tunes/{tune-id}/try-out",
    method: "POST"
  },
  addLayer: {
    title: "Example config for adding pre-computed examples to the studio",
    jsonFile: "../populate-studio/payloads/sandbox-models/model-add-layer.json",
    endpoint: "https://gfm.res.ibm.com/studio-gateway/v2/inference",
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
    
    const curlCommand = `curl -X ${config.method} '${config.endpoint}' \\
  -H 'Content-Type: application/json' \\
  -H 'Authorization: Bearer YOUR_API_KEY' \\
  -d '${JSON.stringify(jsonData, null, 2)}'`;
    
    curlContent.textContent = curlCommand;
    
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