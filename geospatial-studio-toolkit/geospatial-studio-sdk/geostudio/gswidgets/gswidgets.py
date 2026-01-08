# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import functools
import io
import math
import random
from base64 import b64encode
from io import BytesIO
from uuid import UUID

import folium
import folium.plugins
import geopandas as gpd
import ipywidgets as widgets
import matplotlib.pyplot as plt
import numpy as np
import PIL
import plotly.figure_factory as ff
import rasterio
from ipyleaflet import (
    DrawControl,
    FullScreenControl,
    ImageOverlay,
    LayersControl,
    Map,
    SearchControl,
)
from IPython.display import HTML, display
from PIL import Image
from pyproj import Geod
from remotezip import RemoteZip


def geojson_to_details(geojson):
    """
    This function takes a GeoJSON object as input and returns a string containing the area, perimeter, and bounding box coordinates of the polygon.

    Args:
        geojson (dict): A dictionary representing a GeoJSON object with 'geometry' and 'type' keys.
                     The 'geometry' key should contain a dictionary with 'type' set to 'Polygon' and 'coordinates' containing a list of coordinate pairs.
                     The 'type' key should be set to 'Feature'.

    Returns:
        str: A string containing the area (in square kilometers), perimeter (in kilometers), and bounding box coordinates (in decimal degrees) of the polygon.
    """

    print(geojson.get("geometry"))
    # gdf4326 = gpd.GeoDataFrame(index=[0], crs='epsg:4326', geometry=[geojson.get('geometry')])
    gdf4326 = gpd.GeoDataFrame.from_features([geojson], crs="epsg:4326")

    # Get the geometry from `gdf4326`
    pgon = gdf4326.geometry.iloc[0]
    # Extract list of longitude/latitude of polygon's boundary
    lons, lats = pgon.exterior.xy[:][0], pgon.exterior.xy[:][1]

    geod = Geod("+a=6378137 +f=0.0033528106647475126")
    poly_area, poly_perimeter = geod.polygon_area_perimeter(lons, lats)

    bbox_list = [round(pgon.bounds[0], 5), round(pgon.bounds[1], 5), round(pgon.bounds[2], 5), round(pgon.bounds[3], 5)]

    if bbox_list[0] > 180:
        bbox_list[0] = round(bbox_list[0] - 360, 5)
    if bbox_list[2] > 180:
        bbox_list[2] = round(bbox_list[2] - 360, 5)

    # Print the results
    output_details = "Area, (sq.km): {:.1f}".format(abs(poly_area) / 1000000) + "\n"
    output_details = output_details + "Perimeter, (km): {:.2f}".format(poly_perimeter / 1000) + "\n"
    output_details = output_details + "Bounding box coordinates: {}".format(str(bbox_list))

    return output_details


def geojson_to_bbox(geojson):
    """
    Convert a GeoJSON feature to a bounding box in the format [west, south, east, north].

    Args:
        geojson (dict): A dictionary representing a GeoJSON feature. It should contain a 'geometry' key with a GeoJSON geometry object.

    Returns:
        list: A list of four floating point numbers representing the bounding box in the order [west, south, east, north].
        The values are rounded to 5 decimal places. Longitude and latitude values are adjusted to be within the range [-180, 180].
    """

    gdf4326 = gpd.GeoDataFrame.from_features([geojson], crs="epsg:4326")

    # Get the geometry from `gdf4326`
    pgon = gdf4326.geometry.iloc[0]
    bbox_list = [round(pgon.bounds[0], 5), round(pgon.bounds[1], 5), round(pgon.bounds[2], 5), round(pgon.bounds[3], 5)]

    if bbox_list[0] > 180:
        bbox_list[0] = bbox_list[0] - 360
    if bbox_list[2] > 180:
        bbox_list[2] = bbox_list[2] - 360

    return bbox_list


def list_output_files(url, just_tif=True):
    """
    Lists the files present in a remote zip archive.

    Args:
        url (str): The URL of the remote zip archive.
        just_tif (bool, optional): If True, only return files with '.tif' extension. Defaults to True.

    Returns:
        List[str]: A list of filenames present in the zip archive.
    """
    with RemoteZip(url) as zip:
        il = zip.infolist()
    if just_tif == True:
        return [X.filename for X in il if X.filename[-4:] == ".tif"]
    else:
        return [X.filename for X in il]


def download_file(url, filename, output_path="./"):
    """
    Downloads a file from a given URL and saves it to a specified output path.

    Args:
        url (str): The URL of the file to download.
        filename (str): The name of the file to save locally.
        output_path (str, optional): The directory where the file will be saved. Defaults to './'.

    Returns:
        str: The path where the file was saved.
    """
    with RemoteZip(url) as zip:
        a = zip.extract(filename, path=output_path)
    return a


def bboxSelector():
    """
    Creates a user interface for selecting a bounding box on a map.

    Args:
        None

    Returns:
        ipywidgets.widgets.GridspecLayout: A grid layout containing that can be displayed in a Jupyter notebook or similar environment. It contains a map, a search control, a full screen control, a title, a text area for displaying bounding box details,
        a clear button, and a use button. The map has a draw control for selecting a bounding box.
    """
    bbox = []

    grid = widgets.GridspecLayout(4, 4, height="400px")

    m = Map(center=(50, 354), zoom=5, scroll_wheel_zoom=True)

    draw_control = DrawControl(polyline={}, circle={}, polygon={}, circlemarker={})

    draw_control.rectangle = {"shapeOptions": {"fillColor": "#fca45d", "color": "#fca45d", "fillOpacity": 0.3}}

    m.add(SearchControl(position="topleft", url="https://nominatim.openstreetmap.org/search?format=json&q={s}", zoom=8))

    m.add(FullScreenControl())

    grid[:, 1:4] = m

    title = widgets.HTML(
        value="<h1>Bounding box selector</h1> </p>Use the map on the right to draw a bounding box.  Once you selected it you will see the details of the bounding box below."
    )

    grid[0, 0] = title

    bbox_details = widgets.Textarea(value="Your bbox info will appear here", description="", disabled=False, rows=5)

    grid[1, 0] = bbox_details

    def on_bbox_draw(self, action, geo_json):
        """
        Callback function for the draw control's on_draw event.

        Args:
            self: The draw control object.
            action: The action that triggered the event.
            geo_json: The GeoJSON representation of the drawn shape.

        Returns:
            None
        """
        print(geo_json)
        bbox_details.value = geojson_to_details(geo_json)
        # bbox_details.value = json.dumps(geo_json)

    draw_control.on_draw(on_bbox_draw)

    m.add(draw_control)

    button_layout1 = widgets.Layout(width="auto", height="40px")  # set width and height
    button_layout2 = widgets.Layout(width="auto", height="40px")  # set width and height

    clear_button = widgets.Button(
        description="Clear bboxes",
        button_style="warning",
        display="flex",
        flex_flow="column",
        align_items="stretch",
        layout=button_layout1,
    )

    def on_clear_click(b):
        """
        Callback function for the clear button's on_click event.

        Args:
            b: The button object.

        Returns:
            None
        """
        draw_control.clear()
        bbox_details.value = "Your bbox info will appear here"

    clear_button.on_click(on_clear_click)

    grid[2, 0] = clear_button

    use_button = widgets.Button(
        description="Use this bounding box",
        button_style="success",
        display="flex",
        flex_flow="column",
        align_items="stretch",
        layout=button_layout2,
    )

    def on_use_click(b):
        """
        Callback function for the use button's on_click event.

        Args:
            b: The button object.

        Returns:
            The bounding box coordinates as a list.
        """
        # global bbox
        bbox = geojson_to_bbox(draw_control.last_draw)
        draw_control.last_draw["properties"]["style"]["fillColor"] = "#32a852"
        print(bbox)
        return bbox

    bbox = use_button.on_click(on_use_click)

    # grid[3,0] = use_button

    return grid


def time_selector():
    """
    Creates a time range selector using ipywidgets.

    Args:
        None

    Returns:
        ipywidgets.widgets.GridspecLayout: A layout containing two datetime pickers for selecting a start and end time.
    """
    start_time_picker = widgets.DatetimePicker(description="Start time:  ", disabled=False)

    end_time_picker = widgets.DatetimePicker(description="End time:  ", disabled=False)

    grid = widgets.GridspecLayout(4, 2, height="200px")

    grid[0, 0:2] = widgets.HTML(
        value="<h1>Time range selector</h1> </p>Use the datetime pickers to pick a time window for inference."
    )
    grid[1, 0] = start_time_picker
    grid[2, 0] = end_time_picker

    return grid


def add_geotiff(filename, layer_name="", colormap="viridis", cmin=0, cmax="", opacity=1.0):
    """
    Adds a GeoTIFF file to a Folium map as an overlay.

    Args:
        filename (str): The path to the GeoTIFF file.
        layer_name (str, optional): The name of the layer. Defaults to "".
        colormap (str, optional): The colormap to use for the GeoTIFF data. Defaults to "viridis".
        cmin (int or float, optional): The minimum value for the colormap. Defaults to 0.
        cmax (int or float, optional): The maximum value for the colormap. If not provided, it is automatically calculated as the maximum value in the GeoTIFF data. Defaults to "".
        opacity (float, optional): The opacity of the overlay. Defaults to 1.0.

    Returns:
        folium.raster_layers.ImageOverlay: An ImageOverlay object that can be added to a Folium map.
    """
    with rasterio.open(filename) as src:
        dataArray = src.read(1)
        bounds = src.bounds
        nd = src.nodata

    # TODO remove - never used
    # midLat = (bounds[3] + bounds[1]) / 2
    # midLon = (bounds[2] + bounds[0]) / 2

    if cmax == "":
        cmax = np.max(dataArray)
    dataArrayMasked = np.ma.masked_where(dataArray == nd, dataArray)
    imc = colorize(dataArrayMasked, cmax, cmin=cmin, cmap=colormap)

    return folium.raster_layers.ImageOverlay(
        imc,
        [[bounds[1], bounds[0]], [bounds[3], bounds[2]]],
        name=layer_name,
        opacity=opacity,
    )


def colorize(array, cmax, cmin=0, cmap="rainbow"):
    """Converts a 2D numpy array of values into an RGBA array given a colour map and range.

    Args:
        array (ndarray):
        cmax (float): Max value for colour range
        cmin (float): Min value for colour range
        cmap (string): Colour map to use (from matplotlib colourmaps)

    Returns:
            rgba_array (ndarray): 3D RGBA array which can be plotted.
    """
    normed_data = (array - cmin) / (array.max() - cmin)
    cm = plt.cm.get_cmap(cmap)
    return cm(normed_data)


def available_models_ui(client):
    """
    A UI for browsing and selecting available models.

    Args:
        client (object): :py:class:`geostudio.backends.ginference.client.Client`

    Returns:
        widgets.VBox: A Jupyter widget containing a header, text input for filtering, checkbox for active models, interactive dropdown for selecting a model, and the model selection table.
    """
    # workflows = self.available_workflows()
    models_df = client.list_models(output="df")
    models_trim = models_df[["name", "description", "created_at", "created_by", "active"]].sort_values(by=["name"])

    # all_tags = []
    # [all_tags.extend(X) for X in wf_trim.tags]
    # diff_tags = list(np.unique(np.array(all_tags)))

    def view(name="", active=True):
        """
        Displays a filtered list of models based on the provided name and active status.

        Args:
            name (str, optional): The name of the model(s) to filter by. If not provided, all models are displayed.
            active (bool, optional): Whether to filter models by their active status. If True, only active models are displayed.

        Returns:
            None
        """
        if name != "":
            models_trim_filtered = models_trim[[name in X for X in models_trim.name]]
        else:
            models_trim_filtered = models_trim

        if active == True:
            models_trim_filtered = models_trim_filtered[models_trim_filtered.active == True]
            #     ["true" in X for X in models_trim_filtered.active]
            # ]
        else:
            models_trim_filtered = models_trim_filtered

        model_names = list(models_trim_filtered.name)

        if len(model_names) > 0:
            wf_dd.options = model_names
        else:
            wf_dd.value = "None found"
            wf_dd.options = ["None found"]

        return display(HTML(models_trim_filtered.to_html(index=False)))

    keyText = widgets.Text(
        value="",
        placeholder="Type something to filter results",
        description="Model name:",
        disabled=False,
        layout=widgets.Layout(height="auto", width="400px"),
    )

    wf_dd = widgets.Dropdown(
        options=list(models_trim.name),
        value=list(models_trim.name)[0],
        description="Select Model:",
        disabled=False,
        layout=widgets.Layout(height="auto", width="600px"),
    )

    def on_change(change):
        if change["type"] == "change" and change["name"] == "value":
            model_name = change["new"]

    wf_dd.observe(on_change)

    activeCheck = widgets.Checkbox(value=True, description="Active only?", disabled=False)

    # hdr = widgets.Button(
    #     description="GeoDN Modeling workflow catalogue",
    #     disabled=True,
    #     button_style="info",  # 'success', 'info', 'warning', 'danger' or ''
    #     layout=widgets.Layout(height="auto", width="800px"),
    # )
    hdr = widgets.HTML(value="<h1>Inference model selector</h1> </p>Explore which models are deployed for inference.")

    models_filter = widgets.interactive(
        view,
        name=keyText,
        # tags=tagsSelect,
        active=activeCheck,
        layout=widgets.Layout(height="auto", width="800px"),
    )

    # hdr = widgets.Button(
    #     description="Inference model selector",
    #     disabled=True,
    #     button_style="info",  # 'success', 'info', 'warning', 'danger' or ''
    #     layout=widgets.Layout(height="auto", width="800px"),
    # )

    models_table = widgets.VBox(
        [
            hdr,
            widgets.HBox([widgets.VBox([keyText, activeCheck])]),
            models_filter.children[2],
            wf_dd,
        ],
        layout=widgets.Layout(margin="20px 20px 20px 20px", padding="5px 5px 5px 5px"),
    )

    return models_table


# def poll_until_finished(client, id, poll_frequency=2):
#     finished=False

#     while finished==False:
#         r = client.get_inference_task(id)
#         status = r['status']
#         time_taken = (datetime.now()-datetime.strptime(r['created_at'], '%Y-%m-%dT%H:%M:%S.%fZ')).seconds

#         if (status=='COMPLETED'):
#             print(status + ' - ' + str(time_taken) + ' seconds')
#             # print(r)
#             finished=True
#             return r

#         elif (status=='FAILED'):
#             print(status + ' - ' + str(time_taken) + ' seconds')
#             print(r['info'])
#             finished=True
#             return r

#         else:
#             print(status + ' - ' + str(time_taken) + ' seconds', end='\r')

#     sleep(poll_frequency)


def fileDownloader(client, id, just_tifs=True):
    """
    Downloads the output files of an inference task.

    Args:
        client (:py:class:`geostudio.backends.ginference.client.Client`): An object representing the client to interact with the inference service.
        id (str): The unique identifier of the inference task.

    Returns:
        None
    """

    r = client.get_inference_task(id)
    fl = list_output_files(url=r["output_url"], just_tif=just_tifs)

    sm = widgets.SelectMultiple(
        options=fl,
        value=[],
        rows=10,
        description="Files:",
        disabled=False,
        layout={"width": "1000px"},
    )

    db = widgets.Button(
        description="Download",
        disabled=False,
        button_style="",  # 'success', 'info', 'warning', 'danger' or ''
        tooltip="Click me to download the selected",
        icon="check",
        layout=widgets.Layout(height="auto", width="800px"),
    )

    dlp = widgets.Text(value="./", description="Dl path:", disabled=False)

    hdr = widgets.HTML(
        value="<h1>Inference output downloader</h1> </p>Select the files and the download path and hit download."
    )

    output = widgets.Output()

    display(hdr, sm, dlp, db, output)

    def on_button_clicked(db):
        """This function is triggered when a button is clicked."""
        with output:
            for X in list(sm.value):
                print("Downloading...", end="\r")
                a = download_file(r["output_url"], X)
                print(a)

    db.on_click(on_button_clicked)


def fileDownloaderTasks(client, task_id, just_tifs=True):
    """
    Downloads the output files of an inference task.

    Args:
        client (:py:class:`geostudio.backends.v2.ginference.client.Client`): An object representing the client to interact with the inference service.
        task_id (str): The unique identifier of the inference task id.

    Returns:
        None
    """

    r = client.get_task_output_url(task_id)
    fl = list_output_files(url=r["output_url"], just_tif=just_tifs)

    sm = widgets.SelectMultiple(
        options=fl,
        value=[],
        rows=10,
        description="Files:",
        disabled=False,
        layout={"width": "1000px"},
    )

    db = widgets.Button(
        description="Download",
        disabled=False,
        button_style="",  # 'success', 'info', 'warning', 'danger' or ''
        tooltip="Click me to download the selected",
        icon="check",
        layout=widgets.Layout(height="auto", width="800px"),
    )

    dlp = widgets.Text(value="./", description="Dl path:", disabled=False)

    hdr = widgets.HTML(
        value="<h1>Inference Task output downloader</h1> </p>Select the files and the download path and hit download."
    )

    output = widgets.Output()

    display(hdr, sm, dlp, db, output)

    def on_button_clicked(db):
        """This function is triggered when a button is clicked."""
        with output:
            for X in list(sm.value):
                print("Downloading...", end="\r")
                a = download_file(r["output_url"], X)
                print(a)

    db.on_click(on_button_clicked)


def geotiff2img(filename, band=1, cmax=""):
    """
    Converts a GeoTIFF file to a base64 encoded PNG image URL.

    Args:
        filename (str): The path to the GeoTIFF file.
        band (int, optional): The band number to use for the image. Default is 1.
        cmax (str or float, optional): The maximum value for color scaling. If not provided, it will be automatically calculated.

    Returns:
        tuple: A tuple containing the base64 encoded PNG image URL and the image bounds.
    """

    if "_rgb.tif" not in filename:
        # In the case of a non-RGB tagged image convert to an RGB png based on a color map from a single selected band
        with rasterio.open(filename) as src:
            dataArray = src.read(band)
            bounds = src.bounds
            nd = src.nodata

        if cmax == "":
            cmax = np.max(dataArray)
        dataArrayMasked = np.ma.masked_where(dataArray == nd, dataArray)
        imc = colorize(dataArrayMasked, cmax, cmin=0, cmap="viridis")

        img = 255 * imc
        img = img.astype(np.uint8)
        im = PIL.Image.fromarray(img, mode="RGBA")

    elif "_rgb.tif" in filename:
        # In the case of an RGB tagged image convert to an RGB png
        with rasterio.open(filename) as src:
            rBand = src.read(1)
            gBand = src.read(2)
            bBand = src.read(3)
            bounds = src.bounds
            nd = src.nodata

        opacity_layer = np.ma.masked_where(rBand == nd, 255 * np.ones(rBand.shape))
        img = np.stack([rBand, gBand, bBand, opacity_layer], axis=-1)

        img = 2 * img
        img = img.astype(np.uint8)
        im = PIL.Image.fromarray(img, mode="RGBA")

    f = BytesIO()
    im.save(f, "png")

    data = b64encode(f.getvalue())
    data = data.decode("ascii")
    imgurl = "data:image/png;base64," + data

    return imgurl, bounds


def inferenceViewer(client, id):
    """
    Creates a Jupyter widget for visualizing inference task outputs.

    Args:
        client (:py:class:`geostudio.backends.ginference.client.Client`): An object representing the client for interacting with the inference service.
        id (str): The unique identifier for the inference task.

    Returns:
        object: A Jupyter widget containing a map with image overlays of the inference outputs.
    """

    r = client.get_inference_task(id)
    fl = list_output_files(r["output_url"])

    fl_options = [(X.split("/")[-1].replace(r["event_id"] + "_", ""), X) for X in fl]

    sm = widgets.SelectMultiple(
        options=fl_options,
        value=[],
        rows=10,
        description="",
        disabled=False,
        layout={"width": "800px"},
    )

    db = widgets.Button(
        description="Update layers",
        disabled=False,
        button_style="",  # 'success', 'info', 'warning', 'danger' or ''
        tooltip="Click me to update the layers on the map",
        icon="check",
        layout=widgets.Layout(height="auto", width="100px"),
    )

    output = widgets.Output()

    left = widgets.VBox([sm, db, output])

    header = widgets.HTML(value="<h1>Inference output viewer</h1>")
    footer = widgets.HTML(value="Thanks for using the viewer, any questions please ask....")

    map = Map(center=(52.0, 0.0), zoom=8, scroll_wheel_zoom=True, world_copy_jump=False)
    map.add(FullScreenControl())
    control = LayersControl(position="topright")
    map.add(control)

    def on_button_clicked(db):
        """
        Adds image overlays to a map based on a list of URLs.

        Args:
            db (object): The database object containing necessary information for the operation.

        Returns:
            None
        """
        layer_files = []

        # map.clear_layers()

        with output:
            output.clear_output()
            for X in list(sm.value):
                print("Downloading...", end="\r")
                a = download_file(r["output_url"], X)
                print(a)
                layer_files = layer_files + [a]
                imgurl, bounds = geotiff2img(X)
                imgBounds = ((bounds.bottom, bounds.left), (bounds.top, bounds.right))

                map.add(
                    ImageOverlay(
                        name=a.split("/")[-1].replace(r["event_id"] + "_", ""),
                        url=imgurl,
                        bounds=imgBounds,
                        opacity=0.9,
                    )
                )
                # map.add(io)
                # map.fit_bounds([[bounds.bottom, bounds.left],[bounds.top, bounds.right]])
                map.center = (bounds.bottom, bounds.left)
                print(">>> added to map")

    db.on_click(on_button_clicked)

    return widgets.VBox(
        [
            header,
            # widgets.HBox([widgets.VBox([sm, db]), output]),
            sm,
            db,
            map,
            output,
            # footer
        ]
    )


def inferenceTaskViewer(client, task_id):
    """
    Creates a Jupyter widget for visualizing inference task outputs.

    Args:
        client (:py:class:`geostudio.backends.v2.ginference.client.Client`): An object representing the client for interacting with the inference service.
        task_id (str): The unique identifier for the inference task.

    Returns:
        object: A Jupyter widget containing a map with image overlays of the inference outputs.
    """

    r = client.get_task_output_url(task_id)
    fl = list_output_files(r["output_url"])

    fl_options = [(X.split("/")[-1].replace(r["task_id"] + "_", ""), X) for X in fl]

    sm = widgets.SelectMultiple(
        options=fl_options,
        value=[],
        rows=10,
        description="",
        disabled=False,
        layout={"width": "800px"},
    )

    db = widgets.Button(
        description="Update layers",
        disabled=False,
        button_style="",  # 'success', 'info', 'warning', 'danger' or ''
        tooltip="Click me to update the layers on the map",
        icon="check",
        layout=widgets.Layout(height="auto", width="100px"),
    )

    output = widgets.Output()

    left = widgets.VBox([sm, db, output])

    header = widgets.HTML(value="<h1>Inference output viewer</h1>")
    footer = widgets.HTML(value="Thanks for using the viewer, any questions please ask....")

    map = Map(center=(52.0, 0.0), zoom=8, scroll_wheel_zoom=True, world_copy_jump=False)
    map.add(FullScreenControl())
    control = LayersControl(position="topright")
    map.add(control)

    def on_button_clicked(db):
        """
        Adds image overlays to a map based on a list of URLs.

        Args:
            db (object): The database object containing necessary information for the operation.

        Returns:
            None
        """
        layer_files = []

        # map.clear_layers()

        with output:
            output.clear_output()
            for X in list(sm.value):
                print("Downloading...", end="\r")
                a = download_file(r["output_url"], X)
                print(a)
                layer_files = layer_files + [a]
                imgurl, bounds = geotiff2img(X)
                imgBounds = ((bounds.bottom, bounds.left), (bounds.top, bounds.right))

                map.add(
                    ImageOverlay(
                        name=a.split("/")[-1].replace(r["task_id"] + "_", ""),
                        url=imgurl,
                        bounds=imgBounds,
                        opacity=0.9,
                    )
                )
                # map.add(io)
                # map.fit_bounds([[bounds.bottom, bounds.left],[bounds.top, bounds.right]])
                map.center = (bounds.bottom, bounds.left)
                print(">>> added to map")

    db.on_click(on_button_clicked)

    return widgets.VBox(
        [
            header,
            # widgets.HBox([widgets.VBox([sm, db]), output]),
            sm,
            db,
            map,
            output,
            # footer
        ]
    )


def color_inference_tasks_by_status(val):
    """
    Takes a scalar and returns a string with
    the css property `'color: red'` for negative
    strings, black otherwise.
    """

    if val == "READY":
        color = "#ffd966"
    elif val == "WAITING":
        color = "#f6b26b"
    elif val == "RUNNING":
        color = "#d9ead3"
    elif val == "FINISHED":
        color = "#8fce00"
    elif val == "FAILED":
        color = "#ff0000"
    elif val == "STOP":
        color = "#b00020"
    else:
        color = "black"

    return "color: %s" % color


def view_inference_process_timeline(client, inference_id: UUID):
    status = client.get_inference_tasks(inference_id)
    tasks = status["tasks"]
    task_processes = []

    for t in tasks:
        for st in t["pipeline_steps"]:
            if "start_time" in st:
                task_processes = task_processes + [
                    {
                        "Task": t["task_id"],
                        "Start": st["start_time"],
                        "Finish": st.get("end_time", st["start_time"]),
                        "process_id": st["process_id"],
                    }
                ]

    for t in task_processes:
        t["Task"] = (
            "_".join(t["Task"].split("_")[:-1]) + "_" + (t["Task"].split("_")[-1]).zfill(len(str(len(task_processes))))
        )

    df = sorted(task_processes, key=lambda d: d["Task"])

    colors = {
        "inference-planner": "rgb(200, 100, 50)",
        "sentinelhub-connector": "rgb(220, 0, 0)",
        "url-connector": "rgb(220, 0, 0)",
        "terrakit-data-fetch": "rgb(220, 0, 0)",
        "run-inference": (1, 0.9, 0.16),
        "terratorch-inference": (1, 0.9, 0.16),
        "postprocess-generic": "rgb(0, 255, 100)",
        "push-to-geoserver": "rgb(100, 100, 100)",
    }

    fig = ff.create_gantt(
        df,
        title=f"Task performance - {inference_id}",
        colors=colors,
        index_col="process_id",
        show_colorbar=True,
        group_tasks=True,
        showgrid_x=True,
    )
    fig.show()


def plot_tune_metrics(client, tune_id: str, run_name: str = "Train"):
    """
    Plots training and validation metrics for a given tuning experiment in a 2x2 subplot grid.

    Parameters:
        tune_id (str): The unique identifier of the tuning experiment.

    Returns:
        None
    """
    mlflow_urls = client.get_mlflow_metrics(tune_id)
    if mlflow_urls:
        print(mlflow_urls)
    else:
        return f"Tune {tune_id}, has not started to generate metrics. Try to rerun this cell after a few moments!"

    mdf = client.get_tune_metrics_df(tune_id, run_name)
    r = client.get_tune(tune_id)
    status = r["status"]

    mdf_columns = mdf.columns.tolist()
    if not mdf_columns:
        return f"Tune {tune_id}, has not started to generate metrics. Try to rerun this cell after a few moments!"
    mdf_columns.remove("epoch")
    mdf_columns_len = len(mdf_columns)

    nrows = math.ceil(mdf_columns_len / 2)
    ncols = 2
    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, sharex=True, sharey=False, figsize=(10, mdf_columns_len))
    fig.tight_layout()
    step_num = max(mdf.epoch)
    fig.suptitle(f"{tune_id} - {status} - Step number: {step_num}")
    fig.subplots_adjust(top=0.88)

    axes = axes.flatten()

    for i, column in enumerate(mdf_columns):
        axes[i].plot(mdf["epoch"], mdf[column], "b.-")
        axes[i].set_title(column)
        axes[i].grid(True)


def add_wms_time_layer(m, url, layer, name, sld_body, visible_by_default):
    args = {"name": name, "fmt": "image/png", "transparent": True, "layers": layer, "overlay": True}
    if sld_body:
        args["SLD_BODY"] = sld_body
    if visible_by_default and visible_by_default.lower() in ("true", "t", "yes", "y", "1"):
        args["show"] = True
    else:
        args["show"] = False

    wms_tile_layer = folium.WmsTileLayer(url=f"{url}/geoserver/geofm/wms", **args).add_to(m)
    return wms_tile_layer


def inferenceTaskViewerWMS(client, inference_id: UUID):
    inference_response = client.get_inference(inference_id)

    if not inference_response.get("geoserver_layers", {}).get("predicted_layers"):
        print("Geoserver layers missing from the inference")
        return

    glayers = inference_response["geoserver_layers"]["predicted_layers"]
    sorted_glayers = sorted(glayers, key=lambda x: x.get("z_index", random.randint(50, 100)))

    m = folium.Map(location=[0, 0], zoom_start=9)
    bbox = inference_response["spatial_domain"]["bbox"][0]
    bbox_formatted = [[bbox[1], bbox[0]], [bbox[3], bbox[2]]]
    m.fit_bounds(bbox_formatted)

    folium.plugins.Fullscreen(position="topright", force_separate_button=True).add_to(m)

    wms_tile_layer_list = []
    wmts_dates = []
    for g in sorted_glayers:
        layer = g["uri"]
        # print(m._children)
        dates = client.get_layer_timestamps(layer)
        if dates:
            wmts_dates.extend(dates)
        wms_tile_layer = add_wms_time_layer(
            m, client.get_geoserver_url(), layer, g["display_name"], g.get("sld_body"), g.get("visible_by_default")
        )
        if wms_tile_layer:
            wms_tile_layer_list.append(wms_tile_layer)

    if wmts_dates:
        wmts_dates.sort()
        folium.plugins.TimestampedWmsTileLayers(
            wms_tile_layer_list, period="P1D", time_interval=f"{wmts_dates[0]}/{wmts_dates[-1]}"
        ).add_to(m)

    folium.LayerControl().add_to(m)
    return m


def crop_image_bytes(img_bytes):
    """
    Crops the white space from the training image provided as raw bytes and return PNG bytes.

    Parameters
    ----------
    img_bytes : bytes
        Raw image bytes (any format supported by PIL.Image.open).

    Returns
    -------
    bytes
        PNG-encoded bytes of the cropped image. The function uses a fixed crop box
        (left=0, upper=350, right=image_width, lower=650) so the returned image contains
        the horizontal strip between y=350 and y=650 from the original image.

    Notes
    -----
    - The result is always encoded as PNG.
    - If the crop box extends beyond the source image bounds, PIL.Image.crop behavior applies.
    """

    imageFile = Image.open(io.BytesIO(img_bytes))
    w, h = imageFile.size
    croppedImageFile = imageFile.crop((0, 350, w, 650))
    imgBytes = io.BytesIO()
    croppedImageFile.save(imgBytes, format="PNG")
    return imgBytes.getvalue()


def save_training_image(image_number, epoch, img_dict, cropped=True):
    """
    Save a training sample image from img_dict to a PNG file.

    Parameters
    ----------
    image_number : int
        The sample index/number to save (matches the 'image_number' key in img_dict).
    epoch : int
        The epoch number to save (matches the 'epoch' key in img_dict).
    img_dict : list[dict]
        List of artefact records as returned by get_tuning_artefacts. Each item must contain:
          - 'filename' : str
          - 'image' : bytes
          - 'epoch' : int
          - 'image_number' : int
    cropped : bool, optional
        If True (default) crop the image bytes using crop_image_bytes before saving.

    Raises
    ------
    ValueError
        If no matching image is found in img_dict.
    """
    img_bytes = [X for X in img_dict if (X["epoch"] == epoch) & (X["image_number"] == image_number)][0]["image"]
    with open(f"training_image_epoch_{epoch}_number_{image_number}.png", "wb") as f:
        if cropped:
            f.write(crop_image_bytes(img_bytes))
        else:
            f.write(img_bytes)


def browse_training_images(img_dict: object, tune_id: str):
    """
    Create an interactive Jupyter widget viewer to browse fine-tuning sample images.

    Parameters
    ----------
    img_dict : list[dict]
        List of artefact records. Each item must be a dict with at least the keys:
          - 'filename' : str
          - 'image' : bytes  (raw image bytes as returned by get_tuning_artefacts)
          - 'epoch' : int
          - 'image_number' : int
    tune_id : str
        Identifier shown in the viewer header.

    Notes
    -----
    - Depends on crop_image_bytes(img_bytes) to produce the PNG bytes shown in the widget.
    - Expects img_dict to contain at least one image; raises ValueError otherwise.
    - Uses ipywidgets and functools to wire button callbacks.
    - To use: viewer = browse_training_images(img_dict, tune_id); display(viewer)
    """

    if not img_dict:
        raise ValueError("img_dict is empty - must contain at least one image record")

    epochs = sorted(list(set([X["epoch"] for X in img_dict])))
    image_numbers = sorted(list(set([X["image_number"] for X in img_dict])))

    header = widgets.HTML(value=f"<h2>Fine-tuning samples - {tune_id}</h2>")

    image_widget = widgets.Image(
        value=crop_image_bytes(
            [X for X in img_dict if (X["epoch"] == epochs[0]) & (X["image_number"] == image_numbers[0])][0]["image"]
        ),
        format="png",
        width=800,
        height=400,
    )

    # Create buttons for navigation
    back_epoch_button = widgets.Button(description="< Back")
    forward_epoch_button = widgets.Button(description="Next >")
    back_image_button = widgets.Button(description="< Back")
    forward_image_button = widgets.Button(description="Next >")

    # Use a widget to hold the current image index
    epoch_index_w = widgets.IntText(value=0, visible=False)
    image_number_index_w = widgets.IntText(value=0, visible=False)

    epoch_text = widgets.Text(value=str(epochs[epoch_index_w.value]), description="Epoch:", disabled=True)
    image_text = widgets.Text(
        value=str(image_numbers[image_number_index_w.value]), description="Sample:", disabled=True
    )

    # Arrange the widgets in a horizontal box
    viewer_container = widgets.VBox(
        [
            header,
            widgets.HBox([epoch_text, back_epoch_button, forward_epoch_button]),
            widgets.HBox([image_text, back_image_button, forward_image_button]),
            image_widget,
        ]
    )

    # Create a function to handle button clicks
    def on_epoch_button_click(b, epochs=[], image_numbers=[]):
        current_index = epoch_index_w.value
        max_index = len(epochs) - 1

        if b.description == "Next >" and current_index < max_index:
            epoch_index_w.value += 1
        elif b.description == "< Back" and current_index > 0:
            epoch_index_w.value -= 1

        epoch_text.value = str(epochs[epoch_index_w.value])

        # Update the displayed image
        image_widget.value = crop_image_bytes(
            [
                X
                for X in img_dict
                if (X["epoch"] == epochs[epoch_index_w.value])
                & (X["image_number"] == image_numbers[image_number_index_w.value])
            ][0]["image"]
        )

    # Attach the click event to the buttons
    back_epoch_button.on_click(functools.partial(on_epoch_button_click, epochs=epochs, image_numbers=image_numbers))
    forward_epoch_button.on_click(functools.partial(on_epoch_button_click, epochs=epochs, image_numbers=image_numbers))

    def on_image_button_click(b, epochs=[], image_numbers=[]):
        current_index = image_number_index_w.value
        max_index = len(image_numbers) - 1

        if b.description == "Next >" and current_index < max_index:
            image_number_index_w.value += 1
        elif b.description == "< Back" and current_index > 0:
            image_number_index_w.value -= 1

        image_text.value = str(image_numbers[image_number_index_w.value])

        # Update the displayed image
        image_widget.value = crop_image_bytes(
            [
                X
                for X in img_dict
                if (X["epoch"] == epochs[epoch_index_w.value])
                & (X["image_number"] == image_numbers[image_number_index_w.value])
            ][0]["image"]
        )

    # Attach the click event to the buttons
    back_image_button.on_click(functools.partial(on_image_button_click, epochs=epochs, image_numbers=image_numbers))
    forward_image_button.on_click(functools.partial(on_image_button_click, epochs=epochs, image_numbers=image_numbers))

    # Display the interactive viewer
    return viewer_container
