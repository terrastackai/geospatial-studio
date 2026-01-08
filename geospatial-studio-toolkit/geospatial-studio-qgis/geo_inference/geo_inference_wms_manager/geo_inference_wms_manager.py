# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import hashlib
import os
import tempfile
import traceback
import zipfile

import requests
from qgis.core import (
    Qgis,
    QgsMessageLog,
    QgsProject,
    QgsRasterDataProvider,
    QgsRasterLayer,
    QgsRectangle,
)
from qgis.utils import iface

from .config import GEOSERVER_URL


class WMSManager:
    def __init__(self):
        self.geoserver_url = GEOSERVER_URL
        pass

    def add_wms_layer_to_qgis(
        self,
        workspace,
        layer_name,
        group,
        iface=None,
    ):
        """
        Add a WMS layer from GeoServer to QGIS with comprehensive logging

        Args:
            geoserver_url (str): Base GeoServer URL
            workspace (str): GeoServer workspace name
            layer_name (str): Name of the layer to add
            iface: QGIS interface object (optional)

        Returns:
            bool: True if successful, False otherwise
        """

        try:
            style_name = "segmentation-generic-20"
            if "rgb" in layer_name.lower() or "input" in layer_name.lower() or "pred" not in layer_name.lower():
                style_name = ""

            # Log the start of the process
            log_message = f"Starting to add WMS layer '{layer_name}' from workspace '{workspace}'"
            QgsMessageLog.logMessage(log_message, "WMS Layer", Qgis.Info)

            # Build WMS service URL
            service_url = f"{self.geoserver_url}/{workspace}/wms"

            # # remove workspace prefix if already included
            clean_layer_name = layer_name
            if layer_name.startswith(f"{workspace}:"):
                clean_layer_name = layer_name[len(workspace) + 1 :]

            # # WMS layer URI
            uri = (
                f"url={service_url}&layers={clean_layer_name}&format=image/png"
                f"&styles={style_name}&crs=EPSG:4326&timeout=30000&version=1.3.0"
            )

            # Create WMS layer
            log_message = "Creating WMS raster layer (this may take a while)"
            QgsMessageLog.logMessage(log_message, "WMS Layer", Qgis.Info)

            layer = QgsRasterLayer(uri, layer_name, "wms")

            # Check if layer is valid
            # Checks if QGIS could successfully connect to and understand the layer
            # If invalid (eg layer doesn't exist or server is down)
            if not layer.isValid():
                error_message = f"Failed to create WMS layer: {layer_name}"
                layer_error = layer.error().message() if layer.error() else "Unknown error"
                detailed_error = f"{error_message} - Layer error: {layer_error}"

                QgsMessageLog.logMessage(detailed_error, "WMS Layer", Qgis.Critical)

                # Additional debugging info
                debug_message = f"Layer provider: {layer.providerType()},\
                Data source: {layer.dataProvider().dataSourceUri()}"
                QgsMessageLog.logMessage(debug_message, "WMS Layer", Qgis.Warning)

                return False, "failed"

            # Log successful layer creation
            success_message = f"WMS layer '{layer_name}' created successfully and is valid"
            QgsMessageLog.logMessage(success_message, "WMS Layer", Qgis.Success)

            # Log layer details
            layer_info = f"WMS Layer details - Extent: {layer.extent().toString()},\
            CRS: {layer.crs().authid()}"
            QgsMessageLog.logMessage(layer_info, "WMS Layer", Qgis.Info)

            # Add layer to QGIS project
            log_message = "Adding layer to QGIS project..."
            QgsMessageLog.logMessage(log_message, "WMS Layer", Qgis.Info)

            QgsProject.instance().addMapLayer(layer, False)
            group.addLayer(layer)
            if iface:
                iface.mapCanvas().setExtent(layer.extent())
                iface.mapCanvas().refresh()

            # Confirm layer was added to project
            project_layers = QgsProject.instance().mapLayers()
            layer_added = any(added_layer.name() == layer_name for added_layer in project_layers.values())

            if layer_added:
                success_message = f"WMS layer '{layer_name}' successfully added to QGIS project"
                QgsMessageLog.logMessage(success_message, "WMS Layer", Qgis.Success)
            else:
                error_message = f"WMS layer '{layer_name}' was not found in project after adding"
                QgsMessageLog.logMessage(error_message, "WMS Layer", Qgis.Critical)
                return False, error_message

            # Refresh the map canvas
            if iface:
                log_message = "Refreshing map canvas..."
                QgsMessageLog.logMessage(log_message, "WMS Layer", Qgis.Info)

                iface.mapCanvas().refresh()

                success_message = "Map canvas refreshed successfully"
                QgsMessageLog.logMessage(success_message, "WMS Layer", Qgis.Success)
            else:
                warning_message = "No iface provided - map canvas not refreshed"
                QgsMessageLog.logMessage(warning_message, "WMS Layer", Qgis.Warning)

            # Final success message
            final_message = f"WMS layer '{layer_name}' successfully downloaded and added to QGIS"
            QgsMessageLog.logMessage(final_message, "WMS Layer", Qgis.Success)

            return True, final_message

        except Exception as e:
            error_message = f"Error adding WMS layer to QGIS: {str(e)}"
            QgsMessageLog.logMessage(error_message, "WMS Layer", Qgis.Critical)

            # Log the full traceback for debugging
            traceback_message = f"Full traceback: {traceback.format_exc()}"
            QgsMessageLog.logMessage(traceback_message, "WMS Layer", Qgis.Warning)

            return False, error_message

    def add_raster_from_url_to_qgis(self, output_url, layer_name, sld_mapping=None, rgb_group=None, pred_group=None):
        """Add raster layer from a presigned URL to QGIS"""
        try:
            # Check if URL points to a ZIP file
            if output_url.lower().endswith(".zip") or "archive.zip" in output_url:
                return self.add_raster_from_zip(output_url, layer_name, sld_mapping, rgb_group, pred_group)
            else:
                return self.add_raster_file(output_url, layer_name, sld_mapping)

        except Exception as e:
            error_msg = f"Failed to add raster layer: {str(e)}"
            QgsMessageLog.logMessage(error_msg, "GEOFM", Qgis.Critical)
            return False, error_msg

    def add_raster_file(self, output_url, layer_name):
        """Add raster layer directly from URL"""
        # Create raster layer
        raster_layer = QgsRasterLayer(output_url, layer_name, "gdal")

        if not raster_layer.isValid():
            error_msg = raster_layer.error().message() if raster_layer.error() else "No error details"
            QgsMessageLog.logMessage(f"Raster invalid: {error_msg}", "GEOFM", Qgis.Critical)
            return False, error_msg

        # Add to QGIS project
        QgsProject.instance().addMapLayer(raster_layer)

        # Zoom to layer extent and refresh
        iface.mapCanvas().setExtent(raster_layer.extent())
        iface.mapCanvas().refresh()

        QgsMessageLog.logMessage(f"Raster layer added: {layer_name}", "GEOFM", Qgis.Info)
        return True, f"Image layer '{layer_name}' added successfully!"

    def add_raster_from_zip(self, zip_url, layer_name, sld_mapping, rgb_group, pred_group):
        """Download ZIP, extract, and add raster to QGIS with caching"""

        try:
            QgsMessageLog.logMessage(f"Processing ZIP from: {zip_url}", "GEOFM", Qgis.Info)

            # Create a unique identifier for this ZIP URL
            url_hash = hashlib.md5(zip_url.encode()).hexdigest()[:8]

            # Use a persistent temp directory for caching
            cache_dir = os.path.join(tempfile.gettempdir(), "qgis_raster_cache")
            os.makedirs(cache_dir, exist_ok=True)

            zip_cache_path = os.path.join(cache_dir, f"archive_{url_hash}.zip")
            extract_cache_dir = os.path.join(cache_dir, f"extracted_{url_hash}")

            # Check if ZIP already exists and is valid
            zip_exists = os.path.exists(zip_cache_path)
            extracted_exists = os.path.exists(extract_cache_dir) and os.listdir(extract_cache_dir)

            if zip_exists and extracted_exists:
                QgsMessageLog.logMessage(
                    f"Using cached ZIP and extracted files for {layer_name}",
                    "GEOFM",
                    Qgis.Info,
                )
                temp_dir = extract_cache_dir
            elif zip_exists:
                QgsMessageLog.logMessage(
                    f"Using cached ZIP file, extracting for {layer_name}",
                    "GEOFM",
                    Qgis.Info,
                )
                # Extract the cached ZIP
                os.makedirs(extract_cache_dir, exist_ok=True)
                with zipfile.ZipFile(zip_cache_path, "r") as zip_ref:
                    zip_ref.extractall(extract_cache_dir)
                temp_dir = extract_cache_dir
            else:
                QgsMessageLog.logMessage(f"Downloading ZIP from: {zip_url}", "GEOFM", Qgis.Info)

                # Download the ZIP file
                response = requests.get(zip_url, timeout=30)
                response.raise_for_status()

                # Save ZIP file to cache
                with open(zip_cache_path, "wb") as f:
                    f.write(response.content)

                # Extract ZIP to cache directory
                os.makedirs(extract_cache_dir, exist_ok=True)
                with zipfile.ZipFile(zip_cache_path, "r") as zip_ref:
                    zip_ref.extractall(extract_cache_dir)

                temp_dir = extract_cache_dir

            # Find raster files in the extracted directory
            raster_files = self.find_raster_files(temp_dir)

            if not raster_files:
                error_msg = "No raster files found in ZIP archive"
                QgsMessageLog.logMessage(error_msg, "GEOFM", Qgis.Critical)
                return False, error_msg

            loaded_layers = []
            failed_layers = []

            for _, raster_path in enumerate(raster_files):
                try:
                    file_name = os.path.splitext(os.path.basename(raster_path))[0]
                    unique_layer_name = f"{file_name}" if len(raster_files) > 1 else layer_name

                    QgsMessageLog.logMessage(
                        f"Attempting to create raster layer for: {raster_path}",
                        "GEOFM",
                        Qgis.Info,
                    )

                    # Create a raster layer
                    raster_layer = QgsRasterLayer(raster_path, unique_layer_name, "gdal")

                    QgsMessageLog.logMessage(
                        f"Raster layer created. Valid: {raster_layer.isValid()}",
                        "GEOFM",
                        Qgis.Info,
                    )

                    if raster_layer.isValid():
                        # Set resampling
                        raster_layer.dataProvider().setZoomedInResamplingMethod(
                            QgsRasterDataProvider.ResamplingMethod.Bilinear
                        )
                        raster_layer.dataProvider().setZoomedOutResamplingMethod(
                            QgsRasterDataProvider.ResamplingMethod.Bilinear
                        )

                        # Determine which group this layer belongs to
                        target_group = None

                        # Apply SLD styling and determine group
                        if sld_mapping:
                            if "tif_pred" in file_name and "pred" in sld_mapping:
                                QgsMessageLog.logMessage(
                                    f"Applying SLD to: {file_name}",
                                    "GEOFM",
                                    Qgis.Info,
                                )
                                styling_success = self.apply_sld_as_qml(raster_layer, sld_mapping["pred"])
                                QgsMessageLog.logMessage(
                                    f"SLD styling result: {styling_success}",
                                    "GEOFM",
                                    Qgis.Info,
                                )
                                # Set transparency for prediction layers
                                raster_layer.renderer().setOpacity(0.7)
                                target_group = pred_group

                            elif "rgb" in file_name and "rgb" in sld_mapping:
                                QgsMessageLog.logMessage(
                                    f"Applying SLD styling to RGB layer: {file_name}",
                                    "GEOFM",
                                    Qgis.Info,
                                )
                                styling_success = self.apply_sld_as_qml(raster_layer, sld_mapping["rgb"])
                                QgsMessageLog.logMessage(
                                    f"SLD styling result: {styling_success}",
                                    "GEOFM",
                                    Qgis.Info,
                                )
                                target_group = rgb_group

                        # Fallback group assignment if no SLD applied
                        if target_group is None:
                            root = QgsProject.instance().layerTreeRoot()
                            if "rgb" in file_name.lower():
                                target_group = rgb_group if rgb_group else root
                            elif "pred" in file_name.lower():
                                target_group = pred_group if pred_group else root
                                raster_layer.renderer().setOpacity(0.7)  # Make predictions semi-transparent
                            else:
                                target_group = root  # Default to main group

                        # Don't add to root project
                        QgsProject.instance().addMapLayer(raster_layer, False)

                        # Add to appropriate group
                        target_group.addLayer(raster_layer)
                        group_name = target_group.name()
                        QgsMessageLog.logMessage(
                            f"Added {unique_layer_name} to {group_name} group",
                            "GEOFM",
                            Qgis.Info,
                        )

                        loaded_layers.append(unique_layer_name)
                        QgsMessageLog.logMessage(
                            f"Successfully loaded: {unique_layer_name}",
                            "GEOFM",
                            Qgis.Info,
                        )
                    else:
                        error_msg = raster_layer.error().message() if raster_layer.error() else "Unknown error"
                        QgsMessageLog.logMessage(
                            f"Raster layer invalid for {file_name}: {error_msg}",
                            "GEOFM",
                            Qgis.Critical,
                        )
                        failed_layers.append(f"{file_name}:{error_msg}")
                except Exception as e:
                    file_name = os.path.basename(raster_path)
                    QgsMessageLog.logMessage(
                        f"Exception loading {file_name}: {str(e)}",
                        "GEOFM",
                        Qgis.Critical,
                    )
                    failed_layers.append(f"{file_name}:{str(e)}")

            if loaded_layers:
                self.zoom_to_all_layers(loaded_layers)
                success_msg = f"Successfully loaded {len(loaded_layers)} raster layer(s)"
                if failed_layers:
                    success_msg += f". Failed to load {len(failed_layers)} layer(s)."

                QgsMessageLog.logMessage(success_msg, "GEOFM", Qgis.Info)
                return True, success_msg
            else:
                error_msg = f"Failed to load any raster layers. Errors:" f" {'; '.join(failed_layers)}"
                QgsMessageLog.logMessage(error_msg, "GEOFM", Qgis.Critical)
                return False, error_msg

        except requests.RequestException as e:
            error_msg = f"Failed to download ZIP file: {str(e)}"
            QgsMessageLog.logMessage(error_msg, "GEOFM", Qgis.Critical)
            return False, error_msg

        except zipfile.BadZipFile as e:
            error_msg = f"Invalid ZIP file: {str(e)}"
            QgsMessageLog.logMessage(error_msg, "GEOFM", Qgis.Critical)
            return False, error_msg

    def clear_raster_cache(self):
        """Optional method to clear the cache when needed"""
        try:
            cache_dir = os.path.join(tempfile.gettempdir(), "qgis_raster_cache")
            if os.path.exists(cache_dir):
                import shutil

                shutil.rmtree(cache_dir)
                QgsMessageLog.logMessage("Raster cache cleared", "GEOFM", Qgis.Info)
                return True
        except Exception as e:
            QgsMessageLog.logMessage(f"Failed to clear cache: {str(e)}", "GEOFM", Qgis.Warning)
            return False

    def find_raster_files(self, directory):
        """Find raster files in directory - only rgb.tif and .tif_pred.tif files"""
        raster_files = []
        for root, _dirs, files in os.walk(directory):
            QgsMessageLog.logMessage(f"All files in directory: {files}", "GEOFM", Qgis.Info)

            for file in files:
                # Check for rgb files or pred files
                if file.endswith("pred.tif"):
                    raster_files.append(os.path.join(root, file))
                    QgsMessageLog.logMessage(f"Found prediction file: {file}", "GEOFM", Qgis.Info)
                elif file.endswith("rgb.tif"):
                    raster_files.append(os.path.join(root, file))
                    QgsMessageLog.logMessage(f"Found RGB file: {file}", "GEOFM", Qgis.Info)

                else:
                    QgsMessageLog.logMessage(f"Skipped file: {file}", "GEOFM", Qgis.Info)

        QgsMessageLog.logMessage(f"Total target raster files found: {len(raster_files)}", "GEOFM", Qgis.Info)
        return raster_files

    def zoom_to_all_layers(self, layer_names):
        """zoom to combined extent of  multiple layers"""

        combined_extent = QgsRectangle()
        combined_extent.setMinimal()

        for layer_name in layer_names:
            layers = QgsProject.instance().mapLayersByName(layer_name)
            if layers:
                layer_extent = layers[0].extent()
                if combined_extent.isEmpty():
                    combined_extent = layer_extent
                else:
                    combined_extent.combineExtentWith(layer_extent)

        if not combined_extent.isEmpty():
            iface.mapCanvas().setExtent(combined_extent)
            iface.mapCanvas().refresh()

    def load_raster_layers_from_outputs(self, task_outputs, inference_data=None, progress_callback=None):
        """Load raster layers from task outputs."""
        loaded_count = 0
        failed_count = 0

        # Get SLD information from inference data if available
        sld_mapping = {}
        if inference_data and "geoserver_layers" in inference_data:
            predicted_layers = inference_data["geoserver_layers"].get("predicted_layers", [])
            for layer in predicted_layers:
                display_name = layer.get("display_name", "")
                sld_body = layer.get("sld_body", "")
                if "prediction" in display_name.lower() or "pred" in display_name.lower():
                    sld_mapping["pred"] = sld_body
                elif "rgb" in display_name.lower():
                    sld_mapping["rgb"] = sld_body

        # Create groups for RGB and Prediction layers (for ALL tasks)
        root = QgsProject.instance().layerTreeRoot()
        main_group = root.insertGroup(0, "Inference Results")
        pred_group = main_group.insertGroup(0, "Predictions")
        rgb_group = main_group.insertGroup(1, "RGB Images")

        QgsMessageLog.logMessage(
            f"Starting to load {len(task_outputs)} task outputs",
            "WMS Manager",
            Qgis.Info,
        )

        # Process each task
        for i, task_output in enumerate(task_outputs):
            if progress_callback:
                progress_callback(i, len(task_outputs), task_output.get("task_id"))
            task_id = task_output.get("task_id")
            presigned_url = task_output.get("presigned_url")

            QgsMessageLog.logMessage(
                f"Processing task {i+1}/{len(task_outputs)}: {task_id}",
                "WMS Manager",
                Qgis.Info,
            )

            if not presigned_url:
                failed_count += 1
                continue

            try:
                # Load this task's files
                success, message = self.add_raster_from_url_to_qgis(
                    presigned_url, task_id, sld_mapping, rgb_group, pred_group
                )

                if success:
                    loaded_count += 1
                else:
                    failed_count += 1
                    QgsMessageLog.logMessage(
                        f"Failed to load task {task_id}: {message}",
                        "WMS Manager",
                        Qgis.Warning,
                    )

            except Exception as e:
                failed_count += 1
                QgsMessageLog.logMessage(
                    f"Exception loading task {task_id}: {str(e)}",
                    "WMS Manager",
                    Qgis.Critical,
                )

        # Clean up empty groups
        if rgb_group.children() == []:
            main_group.removeChildNode(rgb_group)
        if pred_group.children() == []:
            main_group.removeChildNode(pred_group)

        QgsMessageLog.logMessage(
            f"Loading completed: {loaded_count} tasks processed, {failed_count} failed",
            "WMS Manager",
            Qgis.Info,
        )
        return loaded_count, failed_count

    def load_wms_layers(self, layers, workspace="geofm"):
        """Load WMS layers."""
        loaded_count = 0

        for layer_name in layers:
            try:
                success = self.add_wms_layer_to_qgis(workspace, layer_name, iface)
                if success:
                    loaded_count += 1
            except Exception as e:
                QgsMessageLog.logMessage(
                    f"Error loading WMS layer {layer_name}: {e}",
                    "WMS Manager",
                    Qgis.Warning,
                )

        return loaded_count

    def apply_sld_as_qml(self, raster_layer, sld_body):
        """Convert SLD to QML and apply to raster layer"""
        try:
            import re

            from qgis.core import (
                QgsColorRampShader,
                QgsRasterShader,
                QgsSingleBandPseudoColorRenderer,
            )
            from qgis.PyQt.QtGui import QColor

            # Extract ColorMapEntry elements from SLD
            pattern = (
                r"<ColorMapEntry\s+"
                r'color="([^"]+)"\s+'
                r'opacity="([^"]+)"\s+'
                r'quantity="([^"]+)"\s+'
                r'label="([^"]+)"\s*/>'
            )
            matches = re.findall(pattern, sld_body)

            if not matches:
                QgsMessageLog.logMessage("No ColorMapEntry found in SLD", "GEOFM", Qgis.Warning)
                return False

            # Create color ramp shader
            shader = QgsRasterShader()
            color_ramp = QgsColorRampShader()
            color_ramp.setColorRampType(QgsColorRampShader.Exact)

            # Convert SLD color entries to QML format
            items = []
            for color_hex, opacity_str, quantity_str, label in matches:
                try:
                    # Parse color
                    hex_color = color_hex.lstrip("#")
                    r = int(hex_color[0:2], 16)
                    g = int(hex_color[2:4], 16)
                    b = int(hex_color[4:6], 16)

                    # Parse opacity and quantity
                    opacity = float(opacity_str)
                    alpha = int(opacity * 255)
                    quantity = float(quantity_str)

                    # Create color with alpha
                    color = QColor(r, g, b, alpha)

                    # Add color ramp item
                    items.append(QgsColorRampShader.ColorRampItem(quantity, color, label.strip()))

                    QgsMessageLog.logMessage(
                        f"Added color entry: {label} = {color_hex}" f"(opacity: {opacity}) for value {quantity}",
                        "GEOFM",
                        Qgis.Info,
                    )

                except (ValueError, IndexError) as e:
                    QgsMessageLog.logMessage(f"Error parsing color entry: {e}", "GEOFM", Qgis.Warning)
                    continue

            if not items:
                QgsMessageLog.logMessage("No valid color entries found", "GEOFM", Qgis.Warning)
                return False

            # Sort by value and set color ramp
            items.sort(key=lambda x: x.value)
            color_ramp.setColorRampItemList(items)
            shader.setRasterShaderFunction(color_ramp)

            # Create and apply renderer
            renderer = QgsSingleBandPseudoColorRenderer(raster_layer.dataProvider(), 1, shader)
            raster_layer.setRenderer(renderer)

            # Refresh layer
            raster_layer.triggerRepaint()

            QgsMessageLog.logMessage(
                f"Successfully applied SLD styling with {len(items)} color classes",
                "GEOFM",
                Qgis.Info,
            )
            return True

        except Exception as e:
            QgsMessageLog.logMessage(f"Error applying SLD styling: {e}", "GEOFM", Qgis.Critical)
            return False
