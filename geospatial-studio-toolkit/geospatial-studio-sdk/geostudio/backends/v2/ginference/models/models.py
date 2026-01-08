# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import re
from typing import Any, Dict, List, Optional, Union
from uuid import UUID

from pydantic import BaseModel, Field, HttpUrl, field_validator, model_validator

from ....config import settings


##############################################
# Model
##############################################
class ModelOnboardingInputSchema(BaseModel):
    fine_tuned_model_id: str = Field(description="", default=None, max_length=100)
    model_configs_url: str = Field(description="Presigned url model config file.", default=None)
    model_checkpoint_url: str = Field(description="Presigned url to model checkpoint file.", default=None)

    class Config:
        from_attributes = True
        protected_namespaces = ()


class ModelUpdateInput(BaseModel):
    display_name: str
    description: Optional[str] = None
    model_url: Optional[HttpUrl] = None
    pipeline_steps: Optional[List[Dict[str, Any]]] = None
    geoserver_push: Optional[List[Dict[str, Any]]] = None
    model_input_data_spec: Optional[List[Dict[str, Any]]] = None
    postprocessing_options: Optional[Dict] = None
    sharable: Optional[bool] = False
    model_onboarding_config: Optional[ModelOnboardingInputSchema] = None
    latest: Optional[bool] = None

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, v):
        if not re.match(r"^[a-zA-Z0-9_-]+$", v):
            raise ValueError("model display_name can only contain letters, underscores, and hyphens")
        return v

    class Config:
        protected_namespaces = ()


class ModelCreateInput(ModelUpdateInput):
    version: Optional[float] = 1.0


##############################################
# Inference
##############################################
class SpatialDomain(BaseModel):
    bbox: Optional[List[List[float]]] = Field(default_factory=list)
    polygons: Optional[List] = Field(default_factory=list)
    tiles: Optional[List] = Field(default_factory=list)
    urls: Optional[List] = Field(default_factory=list)

    @model_validator(mode="after")
    def at_least_one_field_required(cls, model):
        if not (model.bbox or model.polygons or model.tiles or model.urls):
            raise ValueError("At least one of 'bbox', 'polygons', 'tiles', or 'urls' must be provided.")
        return model


class DataSource(BaseModel):
    connector: Optional[str] = None
    collection: Optional[str] = None
    bands: Optional[List[Dict[str, Any]]] = None
    scaling_factor: Optional[List[float]] = None
    model_config = {"extra": "allow"}

    @model_validator(mode="before")
    def update_missing_fields(cls, data):
        if ("collection_name" in data) and ("collection" not in data):
            data["collection"] = data["collection_name"]
        return data


class GeoServerPush(BaseModel):
    workspace: str
    layer_name: str
    display_name: str
    filepath_key: str
    file_suffix: str
    geoserver_style: Union[str, dict]
    model_config = {"extra": "allow"}


class PostProcessing(BaseModel):
    cloud_masking: Optional[Union[bool, str, dict]] = None
    ocean_masking: Optional[Union[bool, str, dict]] = None
    model_config = {"extra": "allow"}


class InferenceConfig(BaseModel):
    spatial_domain: SpatialDomain
    temporal_domain: List[str] = None
    model_input_data_spec: Optional[List[Dict[str, Any]]] = None
    data_connector_config: Optional[List[DataSource]] = None
    geoserver_push: Optional[List[GeoServerPush]] = None
    pipeline_steps: Optional[List[Dict[str, Any]]] = None
    post_processing: Optional[PostProcessing] = None
    fine_tuning_id: Optional[str] = None

    class Config:
        protected_namespaces = ()


class InferenceCreateInput(InferenceConfig):
    model_display_name: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None
    geoserver_layers: Optional[Dict[str, Any]] = None
    # priority: Optional[str] = None
    # queue: Optional[str] = None
    fine_tuning_id: Optional[str] = None
    demo: Optional[Dict[str, Any]] = None
    model_id: Optional[UUID] = None
    inference_output: Optional[Dict[str, Any]] = None

    class Config:
        protected_namespaces = ()

    @model_validator(mode="after")
    def check_model_required(cls, model):
        if not (model.model_id or model.model_display_name):
            raise ValueError("At least one of 'model_id' or 'model_display_name' must be provided.")
        return model


class DataAdvisorIn(BaseModel):
    collections: list[str] = None
    dates: list[str] = None
    bbox: Optional[list[list[float]]] = None
    area_polygon: Optional[str] = None
    maxcc: Optional[float] = Field(description="", default=settings.DATA_ADVISOR_MAXCC)
    pre_days: int = Field(description="", default=settings.DATA_ADVISOR_PRE_DAYS)
    post_days: int = Field(description="", default=settings.DATA_ADVISOR_PRE_DAYS)
