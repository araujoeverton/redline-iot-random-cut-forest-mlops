"""Telemetry generator orchestrator."""

import time
import uuid
from typing import Dict, Any
from ..config.loader import SimulatorConfig
from .sensors.brake import BrakeSensor
from .sensors.engine import EngineSensor


class TelemetryGenerator:
    """
    Orchestrates sensor data generation.

    Combines brake and engine sensors into complete telemetry messages.
    """

    def __init__(self, config: SimulatorConfig):
        """
        Initialize telemetry generator.

        Args:
            config: Simulator configuration
        """
        self.config = config
        self.session_id = str(uuid.uuid4())

        # Initialize sensors
        self.brake_sensor = BrakeSensor(
            fade_coefficient=config.brake.fade_coefficient,
            cooling_rate=config.brake.cooling_rate,
        )

        self.engine_sensor = EngineSensor(
            max_rpm=config.engine.max_rpm, idle_rpm=config.engine.idle_rpm
        )

    def generate_sample(self, timestamp: float) -> Dict[str, Any]:
        """
        Generate one complete telemetry sample.

        Args:
            timestamp: Current timestamp (seconds since epoch)

        Returns:
            Complete telemetry message dictionary
        """
        # Sample sensors
        brake_data = self.brake_sensor.sample(timestamp)
        engine_data = self.engine_sensor.sample(timestamp)

        # Combine into telemetry message
        telemetry = {
            "vehicle_id": self.config.vehicle.vehicle_id,
            "timestamp": int(timestamp * 1000),  # Milliseconds
            "session_id": self.session_id,
            **brake_data,
            **engine_data,
        }

        return telemetry
