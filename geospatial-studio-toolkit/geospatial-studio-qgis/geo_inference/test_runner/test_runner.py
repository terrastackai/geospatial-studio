#!/usr/bin/env python3

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0

"""Simple test runner to avoid import issues"""

import os
import sys
from unittest.mock import Mock

# Add current directory to path
sys.path.insert(0, os.path.dirname(__file__))

# Mock QGIS
sys.modules["qgis"] = Mock()
sys.modules["qgis.core"] = Mock()
sys.modules["qgis.core"].QgsMessageLog = Mock()
sys.modules["qgis.core"].Qgis = Mock()

# Mock inference_request_builder
sys.modules["inference_request_builder"] = Mock()

# Now run pytest
if __name__ == "__main__":
    import pytest

    sys.exit(pytest.main(["-v", "tests/unit/"]))
