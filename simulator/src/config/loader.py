"""Configuration loader for simulator."""

import yaml
from pathlib import Path
from typing import Any, Dict
from dataclasses import dataclass


@dataclass
class IoTConfig:
    """IoT connection configuration."""

    endpoint: str
    topic: str
    cert_path: str
    private_key_path: str
    ca_path: str
    thing_name: str


@dataclass
class VehicleConfig:
    """Vehicle simulation configuration."""

    vehicle_id: str
    session_duration_sec: int
    sample_rate_hz: int


@dataclass
class BrakeConfig:
    """Brake sensor configuration."""

    fade_coefficient: float
    cooling_rate: float


@dataclass
class EngineConfig:
    """Engine sensor configuration."""

    max_rpm: int
    idle_rpm: int


@dataclass
class SimulatorConfig:
    """Complete simulator configuration."""

    vehicle: VehicleConfig
    iot: IoTConfig
    brake: BrakeConfig
    engine: EngineConfig


def load_config(config_path: str) -> SimulatorConfig:
    """
    Load configuration from YAML file.

    Args:
        config_path: Path to YAML configuration file

    Returns:
        SimulatorConfig object
    """
    path = Path(config_path)
    with open(path, "r") as f:
        data = yaml.safe_load(f)

    return SimulatorConfig(
        vehicle=VehicleConfig(**data["vehicle"]),
        iot=IoTConfig(**data["iot"]),
        brake=BrakeConfig(**data["brake"]),
        engine=EngineConfig(**data["engine"]),
    )
