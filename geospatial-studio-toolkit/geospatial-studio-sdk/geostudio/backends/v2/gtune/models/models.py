# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import enum
import re
import uuid
from typing import Any, Dict, List, Literal, Optional, Union

from pydantic import BaseModel, Field, field_validator, model_validator

from ..ginference.models import DataSource, GeoServerPush, SpatialDomain


##############################################
# Tunes
##############################################
class TuneUpdateIn(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    train_options: Optional[dict] = {}


class TuneSubmitBase(BaseModel):
    name: str = Field(
        description="Alphanumeric, no special characters or spaces",
        min_length=4,
        max_length=30,
    )
    description: Optional[str] = None
    dataset_id: str

    class Config:
        protected_namespaces = ()

    @field_validator("name")
    @classmethod
    def validate_name(cls, name: str) -> str:
        """Validates the tune name

        Parameters
        ----------
        name : str
            The name of the tune.

        Returns
        -------
        str
            Cleaned up name of the tune without special characters or white spaces.

        Raises
        ------
        ValueError
             If `name` contains special characters or white spaces.
        """
        # Clean-up the tune name.
        name = name.replace(" ", "-").replace("_", "-").strip()
        if not re.match("^[a-zA-Z0-9]+([.-]{0,1}[a-zA-Z0-9]+)*$", name):
            raise ValueError("must not contain special characters or white spaces. Replace underscores with hyphens.")
        return name


class TuneSubmitIn(TuneSubmitBase):
    base_model_id: Optional[uuid.UUID] = None
    tune_template_id: uuid.UUID
    model_parameters: Optional[Any] = {}
    train_options: Optional[Dict] = Field(
        description="Define options for training",
        default={},
    )


class HpoTuneSubmitIn(BaseModel):
    """Schema for hpo tune submission."""

    tune_metadata: TuneSubmitBase
    config_file: str


class PostProcessing(BaseModel):
    cloud_masking: Optional[Union[bool, str, dict]] = None
    snow_ice_masking: Optional[Union[bool, str, dict]] = None
    permanent_water_masking: Optional[Union[bool, str, dict]] = None
    ocean_masking: Optional[Union[bool, str, dict]] = None
    regularization_custom: Optional[List[Dict[str, Any]]] = None
    model_config = {"extra": "allow"}


class TryOutTuneInput(BaseModel):
    model_display_name: str = ""
    description: Optional[str] = "try-out"
    location: str
    geoserver_layers: Optional[Dict[str, Any]] = None
    spatial_domain: SpatialDomain
    temporal_domain: List[str]
    model_input_data_spec: Optional[List[Dict[str, Any]]] = None
    data_connector_config: Optional[List[DataSource]] = None
    geoserver_push: Optional[List[GeoServerPush]] = None
    post_processing: Optional[PostProcessing] = None

    class Config:
        protected_namespaces = ()


class UploadTuneInput(BaseModel):
    name: str
    description: str
    tune_config_url: str
    tune_checkpoint_url: str
    model_input_data_spec: Optional[List[Dict[str, Any]]] = None
    data_connector_config: Optional[List[DataSource]] = None

    class Config:
        protected_namespaces = ()


##############################################
# Templates
##############################################
class TaskPurposeEnum(str, enum.Enum):
    REGRESSION = "Regression"
    SEGMENTATION = "Segmentation"
    OTHER = "Other"
    MULTIMODAL = "Multimodal"

    def __str__(self) -> str:
        """Generates string representation of the ModelCategory

        Returns
        -------
        str
            String representation of ModelCategory value
        """
        return self.value

    @classmethod
    def _missing_(cls, value: str):
        # for case insensitive input mapping
        return cls.__members__.get(value.upper(), None)


class TaskIn(BaseModel):
    name: str
    description: Optional[str] = None
    purpose: Optional[TaskPurposeEnum] = Field(
        description="The use case for this task",
        default=TaskPurposeEnum.SEGMENTATION,
    )
    content: str = Field(description="Base64 encoded string of a fine-tuning yaml template.")
    model_params: Optional[Any] = {}
    extra_info: Optional[dict] = Field(
        description="Extra params e.g {'runtime_image': 'us.icr.io/gfmaas/geostudio-ft-deploy:v3'}",
        default={"runtime_image": ""},
    )
    dataset_id: Optional[str] = None

    class Config:
        protected_namespaces = ()


##############################################
# Datasets
##############################################
class PreScanDatasetIn(BaseModel):
    dataset_url: str
    label_suffix: str
    training_data_suffixes: List[str]


class DatasetUpdateIn(BaseModel):
    dataset_name: Optional[str] = None
    description: Optional[str] = None
    custom_bands: Optional[List[dict]] = None
    label_categories: Optional[List[dict]] = None

    @field_validator("custom_bands")
    @classmethod
    def validate_custom_bands(cls, custom_bands):
        if custom_bands:
            for band in custom_bands:
                if band.get("id") == "":
                    raise ValueError("Valid band ID is needed")
        return custom_bands

    @field_validator("label_categories")
    @classmethod
    def validate_label_categories(cls, label_categories):
        if label_categories:
            for label_category in label_categories:
                if label_category.get("id") == "":
                    raise ValueError("Valid label category ID is needed")
        return label_categories


class GeoDatasetTrainParamUpdateSchema(BaseModel):
    training_params: Optional[dict] = None

    @model_validator(mode="before")
    def custom_schema_validation(cls, values):
        training_params = values.get("training_params")
        if training_params:
            # Class weights should be defined for all classes or none.
            weights = training_params.get("class_weights", [])
            classes = training_params.get("classes", [])
            if weights and (len(weights) != len(classes)):
                raise ValueError("Class weights must either be defined for all classes or None")
            if weights and not classes:
                raise ValueError("classes must be provided when defining class_weights")
        return values


class DatasetOnboardIn(GeoDatasetTrainParamUpdateSchema):
    dataset_name: str
    label_suffix: str
    dataset_url: str
    description: Optional[str]
    purpose: Literal["Regression", "Segmentation", "Generate", "NER", "Classify", "Other"]
    data_sources: List[dict] = []
    label_categories: Optional[List[dict]] = []
    version: str = "v2"


##############################################
# Base models
##############################################
class ModelCategory(str, enum.Enum):
    terramind = "terramind"
    prithvi = "prithvi"
    clay = "clay"
    dofa = "dofa"
    resnet = "resnet"
    convnext = "convnext"

    def __str__(self) -> str:
        """Generates string representation of the ModelCategory

        Returns
        -------
        str
            String representation of ModelCategory value
        """
        return self.value


class BaseModelParamsIn(BaseModel):
    backbone: Optional[str] = Field(description="the base model backbone", default="")
    patch_size: Optional[int] = Field(description="num_layers", default=16)
    num_layers: Optional[int] = Field(description="num_layers", default=12)
    embed_dim: Optional[int] = Field(description="embed_dim", default=768)
    num_heads: Optional[int] = Field(description="num_heads", default=12)
    tile_size: Optional[int] = Field(description="tile_size", default=1)
    tubelet_size: Optional[int] = Field(description="tubelet_size", default=1)
    model_category: Optional[ModelCategory] = Field(description="model_category", default="prithvi")

    class Config:
        protected_namespaces = ()


class BaseModelsIn(BaseModel):
    name: str
    description: str
    checkpoint_filename: Optional[str] = ""
    model_params: Optional[BaseModelParamsIn] = BaseModelParamsIn()

    class Config:
        protected_namespaces = ()


class BaseModelParamsIn(BaseModel):
    backbone: Optional[str] = Field(description="the base model backbone", default="")
    patch_size: Optional[int] = Field(description="num_layers", default=16)
    num_layers: Optional[int] = Field(description="num_layers", default=12)
    embed_dim: Optional[int] = Field(description="embed_dim", default=768)
    num_heads: Optional[int] = Field(description="num_heads", default=12)
    tile_size: Optional[int] = Field(description="tile_size", default=1)
    tubelet_size: Optional[int] = Field(description="tubelet_size", default=1)
    model_category: Optional[ModelCategory] = Field(description="model_category", default="prithvi")

    class Config:
        protected_namespaces = ()
