# Getting started with the Geospatial Studio SDK

*NB: This SDK leverages a deployed instance of the Geospatial Studio through the studio APIs.  As a result, you will require access to an instance.  If you do not, see the previous page.*

In order to support users to interface with the Geospatial Studio through the APIs in a more natural manner, we have created a python SDK.

You can view the SDK documentation [here](https://terrastackai.github.io/geospatial-studio-toolkit)

## Prerequisites
1. Access to an instance of Geospatial Studio platform
2. Ability to run and edit a copy of our jupyter notebooks
 
## Installation
1. Prepare a python 3.11+ environment, however you normally do that (e.g. conda, pyenv, poetry, etc.) and activate this new environment.

2. Install Jupyter into that environment: 
   ```bash
   python -m pip install --upgrade pip
   pip install jupyterlab
   ```

2. Install the SDK:
      ```bash
      pip install geostudio
      ```

## Authentication

Authentication to the Geospatial Studio is handled by a redirect in the UI, but for programmatic access (form the SDK, for example), the user will need to create an API key.  This is can be easily done through the UI.

1. Go to the Geospatial Studio UI page and navigate to the `Manage your API keys` link.
![Location of API key link](./assets/main-screen-api-key-link.png){style="display: block; margin: 0 auto" }

1. This should pop-up a window where you can generate, access and delete your api keys.  NB: every user is limited to a maximum of two activate api keys at any one time.
![Window for managing user API keys](./assets/api-key-modal.png){style="display: block; margin: 0 auto" }

1. When you have generated an api key and you intend to use it for authentication through the python SDK, the best practice would be to store the API key and geostudio ui base url in a credentials file locally, for example in /User/bob/.geostudio_config_file. You can do this by:
    ```bash
    echo "GEOSTUDIO_API_KEY=<paste_api_key_here>" > .geostudio_config_file && echo "BASE_STUDIO_UI_URL=<paste_ui_base_url_here>" >> .geostudio_config_file
    ```

## Example usage of the SDK
In your Python Interpreter:
```py
from geostudio import Client

# change the value of geostudio_config_file below to the path of the file you saved your config in
gfm_client = Client(geostudio_config_file=".geostudio_config_file")

# list available models in the studio
models = gfm_client.list_models()
print(models)

# list available tunes
tunes = gfm_client.list_tunes()
print(tunes)
```

## SDK User guide

For detailed examples on how to use different components of the Studio through the SDK, checkout the [SDK Documentation](https://terrastackai.github.io/geospatial-studio-toolkit/examples/dataset-onboarding/001-Introduction-to-Onboarding-Tuning-Data/) for example notebooks.