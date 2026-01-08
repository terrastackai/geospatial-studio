# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


from qgis.core import (
    Qgis,
    QgsCoordinateReferenceSystem,
    QgsCoordinateTransform,
    QgsMessageLog,
    QgsProject,
    QgsVectorLayer,
)
from qgis.PyQt.QtWidgets import QMessageBox
from qgis.utils import iface


class SpatialSelector:
    """Handles polygon drawing and spatial data capture in QGIS"""

    def __init__(self):
        pass

    def draw_polygon(self):
        # temporary layer for drawing
        drawing_layer = QgsVectorLayer("Polygon?crs=EPSG:4326", "draw_polygons", "memory")
        QgsProject.instance().addMapLayer(drawing_layer)

        # set layer as active and start editing
        iface.setActiveLayer(drawing_layer)
        drawing_layer.startEditing()

        # activate polygon drawing
        iface.actionAddFeature().trigger()

        QMessageBox.information(
            None,
            "Draw Polygons",
            "Draw polygons on map. Right-click to finish each polygon.",
        )

    def get_drawn_bbox(self):
        """get the bounding box of all drawn polygons"""

        for layer in QgsProject.instance().mapLayers().values():
            if layer.name() == "draw_polygons":
                # save edits
                layer.commitChanges()
                # get layer extent
                extent = layer.extent()

                # convert to WGS84 if needed
                layer_crs = layer.crs()
                wgs84_crs = QgsCoordinateReferenceSystem("EPSG:4326")

                if layer_crs != wgs84_crs:
                    transform = QgsCoordinateTransform(layer_crs, wgs84_crs, QgsProject.instance())
                    extent = transform.transformBoundingBox(extent)

                # return [west,south,east,north]
                bbox = [
                    extent.xMinimum(),
                    extent.yMinimum(),
                    extent.xMaximum(),
                    extent.yMaximum(),
                ]
                # Log to QGIS message log
                QgsMessageLog.logMessage(f"Drawn bbox: {bbox}", "GeoInference", Qgis.Info)
                QgsMessageLog.logMessage(
                    f"Bbox bounds: W={bbox[0]:.6f}, S={bbox[1]:.6f}," f"E={bbox[2]:.6f}, N={bbox[3]:.6f}",
                    "GeoInference",
                    Qgis.Info,
                )

                return bbox
        return None
