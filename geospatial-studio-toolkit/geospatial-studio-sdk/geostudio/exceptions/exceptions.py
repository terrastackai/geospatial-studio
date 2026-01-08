# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import logging
from typing import Union

logger = logging.getLogger(__name__)


class GeoFMException(Exception):
    """
    Custom exception class for handling errors in GeoFM operations.
    """

    def __init__(self, error: Exception) -> None:
        """
        Initializes the GeoFMException with the provided error.

        Args:
            error (Exception): The original exception that caused this error.
        """
        self.error = error
        self.error_message = str(error)
        logger.error(self.error_message)
        super().__init__(self.error_message)
