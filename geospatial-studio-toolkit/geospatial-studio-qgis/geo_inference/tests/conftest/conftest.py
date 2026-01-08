# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
import sys
from unittest.mock import MagicMock

# Add the parent directory to Python path for package imports
tests_dir = os.path.dirname(os.path.abspath(__file__))
geo_inference_dir = os.path.dirname(tests_dir)
parent_dir = os.path.dirname(geo_inference_dir)
sys.path.insert(0, parent_dir)

# Create detailed QGIS mocks to handle nested imports
qgis_mock = MagicMock()
qgis_core_mock = MagicMock()
qgis_pyqt_mock = MagicMock()
qgis_pyqt_qtcore_mock = MagicMock()
qgis_pyqt_qtwidgets_mock = MagicMock()
qgis_pyqt_qtgui_mock = MagicMock()
qgis_utils_mock = MagicMock()

# Set up nested structure for PyQt imports
qgis_pyqt_mock.QtCore = qgis_pyqt_qtcore_mock
qgis_pyqt_mock.QtWidgets = qgis_pyqt_qtwidgets_mock
qgis_pyqt_mock.QtGui = qgis_pyqt_qtgui_mock

# Install all the mocks
sys.modules["qgis"] = qgis_mock
sys.modules["qgis.core"] = qgis_core_mock
sys.modules["qgis.PyQt"] = qgis_pyqt_mock
sys.modules["qgis.PyQt.QtCore"] = qgis_pyqt_qtcore_mock
sys.modules["qgis.PyQt.QtWidgets"] = qgis_pyqt_qtwidgets_mock
sys.modules["qgis.PyQt.QtGui"] = qgis_pyqt_qtgui_mock
sys.modules["qgis.utils"] = qgis_utils_mock
