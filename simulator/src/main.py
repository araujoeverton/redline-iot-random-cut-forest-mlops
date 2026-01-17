"""
Redline IoT Telemetry Simulator

Main entry point for the telemetry simulator.
Generates realistic vehicle telemetry and publishes to AWS IoT Core.
"""

import sys
import time
import argparse
from pathlib import Path
import structlog

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.config.loader import load_config
from src.telemetry.generator import TelemetryGenerator
from src.iot.publisher import IoTPublisher

# Configure structured logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer(),
    ]
)

logger = structlog.get_logger(__name__)


def main() -> None:
    """Main simulator loop."""
    parser = argparse.ArgumentParser(description="Redline IoT Telemetry Simulator")
    parser.add_argument(
        "--config",
        type=str,
        default="config/default.yml",
        help="Path to configuration file",
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=None,
        help="Override session duration (seconds)",
    )
    args = parser.parse_args()

    try:
        # Load configuration
        logger.info("loading_config", config_path=args.config)
        config = load_config(args.config)

        # Override duration if specified
        if args.duration:
            config.vehicle.session_duration_sec = args.duration

        logger.info(
            "simulator_starting",
            vehicle_id=config.vehicle.vehicle_id,
            duration=config.vehicle.session_duration_sec,
            sample_rate=config.vehicle.sample_rate_hz,
        )

        # Initialize components
        telemetry_generator = TelemetryGenerator(config)

        iot_publisher = IoTPublisher(
            endpoint=config.iot.endpoint,
            cert_path=config.iot.cert_path,
            private_key_path=config.iot.private_key_path,
            ca_path=config.iot.ca_path,
            client_id=config.iot.thing_name,
            topic=config.iot.topic,
        )

        # Connect to IoT Core
        iot_publisher.connect()

        # Main telemetry loop
        start_time = time.time()
        sample_interval = 1.0 / config.vehicle.sample_rate_hz
        sample_count = 0

        logger.info("telemetry_started", session_id=telemetry_generator.session_id)

        while time.time() - start_time < config.vehicle.session_duration_sec:
            try:
                # Generate telemetry sample
                current_time = time.time()
                telemetry = telemetry_generator.generate_sample(current_time)

                # Publish to IoT Core
                iot_publisher.publish(telemetry)

                sample_count += 1

                # Log progress every 100 samples
                if sample_count % 100 == 0:
                    elapsed = time.time() - start_time
                    logger.info(
                        "telemetry_progress",
                        samples=sample_count,
                        elapsed=f"{elapsed:.1f}s",
                        rate=f"{sample_count / elapsed:.1f} msg/s",
                    )

                # Sleep until next sample
                next_sample_time = start_time + (sample_count * sample_interval)
                sleep_time = next_sample_time - time.time()
                if sleep_time > 0:
                    time.sleep(sleep_time)

            except KeyboardInterrupt:
                logger.info("simulator_interrupted")
                break

            except Exception as e:
                logger.error("telemetry_error", error=str(e), exc_info=True)
                # Continue despite errors

        # Cleanup
        iot_publisher.disconnect()

        elapsed = time.time() - start_time
        logger.info(
            "simulator_finished",
            samples=sample_count,
            duration=f"{elapsed:.1f}s",
            avg_rate=f"{sample_count / elapsed:.1f} msg/s",
        )

    except Exception as e:
        logger.error("simulator_failed", error=str(e), exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
