"""
AWS IoT Core MQTT Publisher

Handles secure MQTT connection and message publishing to AWS IoT Core.
"""

import json
import time
from typing import Dict, Any, Optional
from awsiot import mqtt_connection_builder
from awscrt import mqtt
import structlog

from .retry import ExponentialBackoff

logger = structlog.get_logger(__name__)


class IoTPublisher:
    """
    AWS IoT Core MQTT client with retry logic.

    Features:
    - X.509 certificate authentication
    - Exponential backoff retry
    - QoS 1 (At Least Once) delivery
    - Connection health monitoring
    """

    def __init__(
        self,
        endpoint: str,
        cert_path: str,
        private_key_path: str,
        ca_path: str,
        client_id: str,
        topic: str,
    ):
        """
        Initialize IoT publisher.

        Args:
            endpoint: AWS IoT Core endpoint
            cert_path: Path to certificate PEM file
            private_key_path: Path to private key file
            ca_path: Path to Amazon Root CA certificate
            client_id: MQTT client ID (should match Thing name)
            topic: MQTT topic to publish to
        """
        self.endpoint = endpoint
        self.cert_path = cert_path
        self.private_key_path = private_key_path
        self.ca_path = ca_path
        self.client_id = client_id
        self.topic = topic

        self.mqtt_connection: Optional[mqtt.Connection] = None
        self.connected = False

    @ExponentialBackoff(max_retries=5, base_delay=1.0, max_delay=30.0)
    def connect(self) -> None:
        """
        Establish MQTT connection to AWS IoT Core.

        Raises:
            Exception: If connection fails after retries
        """
        logger.info(
            "iot_connecting",
            endpoint=self.endpoint,
            client_id=self.client_id,
        )

        self.mqtt_connection = mqtt_connection_builder.mtls_from_path(
            endpoint=self.endpoint,
            cert_filepath=self.cert_path,
            pri_key_filepath=self.private_key_path,
            ca_filepath=self.ca_path,
            client_id=self.client_id,
            clean_session=False,
            keep_alive_secs=30,
        )

        # Connect with timeout
        connect_future = self.mqtt_connection.connect()
        connect_future.result(timeout=10)

        self.connected = True
        logger.info("iot_connected", client_id=self.client_id)

    @ExponentialBackoff(max_retries=3, base_delay=0.5, max_delay=10.0)
    def publish(self, payload: Dict[str, Any]) -> None:
        """
        Publish telemetry message to IoT Core.

        Args:
            payload: Telemetry data dictionary

        Raises:
            Exception: If publish fails after retries
        """
        if not self.connected or self.mqtt_connection is None:
            raise ConnectionError("Not connected to IoT Core")

        # Serialize to JSON
        message = json.dumps(payload).encode("utf-8")

        # Publish with QoS 1
        publish_future, _ = self.mqtt_connection.publish(
            topic=self.topic, payload=message, qos=mqtt.QoS.AT_LEAST_ONCE
        )

        # Wait for publish confirmation
        publish_future.result(timeout=5)

        logger.debug(
            "message_published",
            topic=self.topic,
            size=len(message),
            vehicle_id=payload.get("vehicle_id"),
        )

    def disconnect(self) -> None:
        """Gracefully disconnect from IoT Core."""
        if self.mqtt_connection and self.connected:
            logger.info("iot_disconnecting", client_id=self.client_id)
            disconnect_future = self.mqtt_connection.disconnect()
            disconnect_future.result(timeout=5)
            self.connected = False
            logger.info("iot_disconnected")
