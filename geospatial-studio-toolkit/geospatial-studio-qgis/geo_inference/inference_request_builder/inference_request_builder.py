# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


class InferenceRequestBuilder:
    def __init__(self):
        self.reset()

    def reset(self):
        self.request = {
            "spatial_domain": {"bbox": [], "polygons": [], "tiles": [], "urls": []},
            "temporal_domain": ["2020-01-01_2024-12-31"],
            "description": "",
            "location": "",
            "model_id": "d5a82d97-ffb8-4de1-bd91-ad3c12828976",
        }
        return self

    def with_bbox(self, bbox):
        self.request["spatial_domain"]["bbox"] = [bbox]
        return self

    def with_description(self, description):
        self.request["description"] = description
        return self

    def with_location(self, location):
        self.request["location"] = location
        return self

    def with_temporal_domain(self, start_date, end_date):
        self.request["temporal_domain"] = [f"{start_date}_{end_date}"]
        return self

    def with_model_id(self, model_id):
        self.request["model_id"] = model_id
        return self

    def build(self):
        return self.request
