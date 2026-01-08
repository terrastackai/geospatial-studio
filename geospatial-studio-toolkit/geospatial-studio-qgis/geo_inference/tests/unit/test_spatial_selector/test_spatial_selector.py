# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


""" unit tests for SpatialSelector"""

from unittest.mock import Mock, patch

import pytest
from geo_inference.geo_inference_spatial_Selector import SpatialSelector


class TestSpatialSelector:
    """Minimal tests for SpatialSelector"""

    @pytest.fixture
    def spatial_selector(self):
        return SpatialSelector()

    def test_initialization(self, spatial_selector):
        """Test that SpatialSelector can be created"""
        assert spatial_selector is not None

    @patch("geo_inference.geo_inference_spatial_Selector.QgsProject")
    def test_get_drawn_bbox_no_layer(self, mock_qgs_project, spatial_selector):
        """Test get_drawn_bbox when no drawing layer exists"""
        # Setup mock chain: QgsProject.instance().mapLayers().values()
        mock_project_instance = Mock()
        mock_qgs_project.instance.return_value = mock_project_instance
        mock_project_instance.mapLayers.return_value = {}

        result = spatial_selector.get_drawn_bbox()

        assert result is None

    @patch("geo_inference.geo_inference_spatial_Selector.QgsProject")
    @patch("geo_inference.geo_inference_spatial_Selector.QgsCoordinateReferenceSystem")
    @patch("geo_inference.geo_inference_spatial_Selector.QgsMessageLog")
    def test_get_drawn_bbox_with_layer(self, mock_log, mock_crs_class, mock_qgs_project, spatial_selector):
        """Test get_drawn_bbox with drawing layer"""
        # Mock layer with extent
        mock_layer = Mock()
        mock_layer.name.return_value = "draw_polygons"
        mock_layer.commitChanges.return_value = True

        # Mock extent
        mock_extent = Mock()
        mock_extent.xMinimum.return_value = 1.0
        mock_extent.yMinimum.return_value = 2.0
        mock_extent.xMaximum.return_value = 3.0
        mock_extent.yMaximum.return_value = 4.0
        mock_layer.extent.return_value = mock_extent

        # Mock CRS (same CRS, no transform needed)
        mock_layer_crs = Mock()
        mock_wgs84_crs = Mock()
        mock_layer.crs.return_value = mock_layer_crs
        mock_crs_class.return_value = mock_wgs84_crs

        # Make CRS comparison return True (same CRS)
        mock_layer_crs.__eq__ = Mock(return_value=True)

        # Setup project mock chain
        mock_project_instance = Mock()
        mock_qgs_project.instance.return_value = mock_project_instance

        mock_project_instance.mapLayers.return_value = {"layer1": mock_layer}

        result = spatial_selector.get_drawn_bbox()

        assert result == [1.0, 2.0, 3.0, 4.0]
        mock_layer.commitChanges.assert_called_once()
