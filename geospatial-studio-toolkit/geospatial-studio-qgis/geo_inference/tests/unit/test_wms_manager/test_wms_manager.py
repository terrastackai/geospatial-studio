# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


"""Minimal unit tests for WMSManager"""

import sys
from unittest.mock import Mock, mock_open, patch

import pytest
import responses

# Mock QGIS components
sys.modules["qgis"] = Mock()
sys.modules["qgis.core"] = Mock()
sys.modules["qgis.utils"] = Mock()

# Mock config
sys.modules["config"] = Mock()
sys.modules["config"].GEOSERVER_URL = "https://test-geoserver.com"

from geo_inference.geo_inference_wms_manager import WMSManager  # noqa: E402


class TestWMSManager:
    """tests for WMSManager"""

    @pytest.fixture
    def wms_manager(self):
        return WMSManager()

    @patch("geo_inference.geo_inference_wms_manager.QgsRasterLayer")
    @patch("geo_inference.geo_inference_wms_manager.QgsProject")
    @patch("geo_inference.geo_inference_wms_manager.QgsMessageLog")
    def test_add_wms_layer_success(self, mock_log, mock_project, mock_raster_layer, wms_manager):
        """Test successful WMS layer addition"""
        # Mock layer
        mock_layer = Mock()
        mock_layer.isValid.return_value = True
        mock_layer.name.return_value = "test_layer"
        mock_layer.extent.return_value.toString.return_value = "1,2,3,4"
        mock_layer.crs.return_value.authid.return_value = "EPSG:4326"
        mock_raster_layer.return_value = mock_layer

        # Mock project
        mock_project_instance = Mock()
        mock_project.instance.return_value = mock_project_instance
        mock_project_instance.mapLayers.return_value = {"layer1": mock_layer}

        # Mock iface
        mock_iface = Mock()

        result = wms_manager.add_wms_layer_to_qgis("test_workspace", "test_layer", mock_iface)

        assert result is True
        mock_raster_layer.assert_called_once()
        mock_project_instance.addMapLayer.assert_called_once_with(mock_layer)
        mock_iface.mapCanvas().refresh.assert_called_once()

    @patch("geo_inference.geo_inference_wms_manager.QgsRasterLayer")
    @patch("geo_inference.geo_inference_wms_manager.QgsMessageLog")
    def test_add_wms_layer_invalid(self, mock_log, mock_raster_layer, wms_manager):
        """Test WMS layer addition with invalid layer"""
        # Mock invalid layer
        mock_layer = Mock()
        mock_layer.isValid.return_value = False
        mock_layer.error.return_value.message.return_value = "Layer not found"
        mock_raster_layer.return_value = mock_layer

        result = wms_manager.add_wms_layer_to_qgis("test_workspace", "invalid_layer")

        assert result is False

    def test_add_raster_from_url_zip(self, wms_manager):
        """Test URL routing for ZIP files"""
        with patch.object(wms_manager, "add_raster_from_zip") as mock_zip:
            mock_zip.return_value = (True, "Success")

            _ = wms_manager.add_raster_from_url_to_qgis("https://test.com/file.zip", "test_layer")

            mock_zip.assert_called_once_with("https://test.com/file.zip", "test_layer")

    def test_add_raster_from_url_direct(self, wms_manager):
        """Test URL routing for direct raster files"""
        with patch.object(wms_manager, "add_raster_file") as mock_file:
            mock_file.return_value = (True, "Success")

            _ = wms_manager.add_raster_from_url_to_qgis("https://test.com/file.tif", "test_layer")

            mock_file.assert_called_once_with("https://test.com/file.tif", "test_layer")

    @patch("geo_inference.geo_inference_wms_manager.QgsRasterLayer")
    @patch("geo_inference.geo_inference_wms_manager.QgsProject")
    @patch("geo_inference.geo_inference_wms_manager.iface")
    def test_add_raster_file_success(self, mock_iface, mock_project, mock_raster_layer, wms_manager):
        """Test successful  raster file addition"""
        # Mock valid layer
        mock_layer = Mock()
        mock_layer.isValid.return_value = True
        mock_layer.extent.return_value = "test_extent"
        mock_raster_layer.return_value = mock_layer

        # Mock project
        mock_project_instance = Mock()
        mock_project.instance.return_value = mock_project_instance

        success, message = wms_manager.add_raster_file("https://test.com/raster.tif", "test_raster")

        assert success is True
        assert "added successfully" in message
        mock_project_instance.addMapLayer.assert_called_once_with(mock_layer)
        mock_iface.mapCanvas().setExtent.assert_called_once()
        mock_iface.mapCanvas().refresh.assert_called_once()

    @patch("geo_inference.geo_inference_wms_manager.QgsRasterLayer")
    def test_add_raster_file_invalid(self, mock_raster_layer, wms_manager):
        """Test raster file addition with invalid file"""
        # Mock invalid layer
        mock_layer = Mock()
        mock_layer.isValid.return_value = False
        mock_layer.error.return_value.message.return_value = "Invalid raster"
        mock_raster_layer.return_value = mock_layer

        success, message = wms_manager.add_raster_file("https://test.com/invalid.tif", "test_raster")

        assert success is False
        assert "Invalid raster" in message

    @responses.activate
    def test_add_raster_from_zip_success(self, wms_manager):
        """Test successful ZIP download and extraction"""
        # Mock HTTP response
        zip_content = b"fake zip content"
        responses.add(responses.GET, "https://test.com/archive.zip", body=zip_content, status=200)

        with patch("geo_inference.geo_inference_wms_manager.zipfile.ZipFile") as mock_zipfile, patch(
            "geo_inference.geo_inference_wms_manager.tempfile.TemporaryDirectory"
        ) as mock_tempdir, patch.object(wms_manager, "find_raster_files") as mock_find, patch(
            "geo_inference.geo_inference_wms_manager.QgsRasterLayer"
        ) as mock_raster_layer, patch(
            "geo_inference.geo_inference_wms_manager.QgsProject"
        ) as mock_project, patch.object(
            wms_manager, "zoom_to_all_layers"
        ) as mock_zoom:  # noqa: F841
            # Mock temporary directory
            mock_tempdir.return_value.__enter__.return_value = "/tmp/test"

            # Mock ZIP extraction
            mock_zip_instance = Mock()
            mock_zipfile.return_value.__enter__.return_value = mock_zip_instance

            # Mock finding raster files
            mock_find.return_value = ["/tmp/test/raster1.tif"]

            # Mock valid raster layer
            mock_layer = Mock()
            mock_layer.isValid.return_value = True
            mock_raster_layer.return_value = mock_layer

            # Mock project components
            mock_project_instance = Mock()
            mock_root = Mock()
            mock_project.instance.return_value = mock_project_instance
            mock_project_instance.layerTreeRoot.return_value = mock_root

            with patch("builtins.open", mock_open()):
                success, message = wms_manager.add_raster_from_zip("https://test.com/archive.zip", "test_layer")

            assert success is True
            assert "Successfully loaded" in message

    @responses.activate
    def test_add_raster_from_zip_download_failure(self, wms_manager):
        """Test ZIP download failure"""
        responses.add(responses.GET, "https://test.com/archive.zip", body="Not Found", status=404)

        success, message = wms_manager.add_raster_from_zip("https://test.com/archive.zip", "test_layer")

        assert success is False
        assert "Failed to download" in message

    def test_find_raster_files(self, wms_manager):
        """Test finding raster files in directory"""
        with patch("os.walk") as mock_walk:
            # Mock directory structure
            mock_walk.return_value = [("/test", [], ["image1.tif", "image2.jpg", "readme.txt", "data.shp"])]

            raster_files = wms_manager.find_raster_files("/test")

            assert len(raster_files) == 2
            assert "/test/image1.tif" in raster_files
            assert "/test/image2.jpg" in raster_files
            assert "/test/readme.txt" not in raster_files

    @patch("geo_inference.geo_inference_wms_manager.QgsProject")
    @patch("geo_inference.geo_inference_wms_manager.iface")
    def test_zoom_to_all_layers(self, mock_iface, mock_project, wms_manager):
        """Test zooming to combined extent of layers"""
        # Mock project with layers
        mock_layer1 = Mock()
        mock_layer1.extent.return_value = "extent1"
        mock_layer2 = Mock()
        mock_layer2.extent.return_value = "extent2"

        mock_project_instance = Mock()
        mock_project.instance.return_value = mock_project_instance
        mock_project_instance.mapLayersByName.side_effect = [
            [mock_layer1],  # First call returns layer1
            [mock_layer2],  # Second call returns layer2
        ]

        # Mock QgsRectangle
        with patch("geo_inference.geo_inference_wms_manager.QgsRectangle") as mock_rectangle:
            mock_rect = Mock()
            mock_rect.isEmpty.return_value = False
            mock_rectangle.return_value = mock_rect

            wms_manager.zoom_to_all_layers(["layer1", "layer2"])

            mock_iface.mapCanvas().setExtent.assert_called_once()
            mock_iface.mapCanvas().refresh.assert_called_once()
