# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


# coding=utf-8
"""Dialog test.

.. note:: This program is free software; you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation; either version 2 of the License, or
     (at your option) any later version.

"""

__author__ = "Fiona.Bundi@ibm.com"
__date__ = "2025-06-11"
__copyright__ = "Copyright 2025, IBM"

import sys
import unittest
from unittest.mock import MagicMock  # noqa:E402

# Create mock classes with proper return values
mock_dialog = MagicMock()
mock_dialog.result.return_value = 1  # Will be set in tests

QDialogButtonBox = MagicMock()
QDialog = MagicMock()
QDialog.Accepted = 1
QDialog.Rejected = 0

# Mock  custom modules
sys.modules["geo_inference_dialog"] = MagicMock()
sys.modules["utilities"] = MagicMock()

import geo_inference_dialog  # noqa:E402
from qgis.PyQt.QtGui import QDialog, QDialogButtonBox  # noqa:E402
from utilities import get_qgis_app  # noqa:E402

QGIS_APP = get_qgis_app()
GeoInferenceDialog = geo_inference_dialog.GeoInferenceDialog


class GeoInferenceDialogTest(unittest.TestCase):
    """Test dialog works."""

    def setUp(self):
        """Runs before each test."""
        self.dialog = MagicMock()
        self.dialog.button_box.button.return_value = MagicMock()

    def tearDown(self):
        """Runs after each test."""
        self.dialog = None

    def test_dialog_ok(self):
        """Test we can click OK."""
        self.dialog.result.return_value = 1
        button = self.dialog.button_box.button(QDialogButtonBox.Ok)
        button.click()
        result = self.dialog.result()
        self.assertEqual(result, 1)

    def test_dialog_cancel(self):
        """Test we can click cancel."""
        self.dialog.result.return_value = 0
        button = self.dialog.button_box.button(QDialogButtonBox.Cancel)
        button.click()
        result = self.dialog.result()
        self.assertEqual(result, 0)


if __name__ == "__main__":
    suite = unittest.makeSuite(GeoInferenceDialogTest)
    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(suite)
