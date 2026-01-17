"""
Engine Sensor Physics Model

Implements realistic engine thermodynamics including:
- RPM distribution by driving mode (idle/cruise/race)
- Oil temperature: Friction heating + coolant dissipation
- Oil pressure: RPM-dependent with temperature compensation
- Boost pressure: Turbo wastegate model
- Fuel consumption: Throttle-dependent
"""

import random
from typing import Dict


class EngineSensor:
    """
    Simulates engine telemetry with realistic thermodynamics.

    Driving Modes:
    - Idle: 800 RPM, 0% throttle (10% probability)
    - Cruise: 3500 RPM, 20-40% throttle (60% probability)
    - Race: 7500 RPM, 70-100% throttle (30% probability)
    """

    def __init__(
        self,
        max_rpm: int = 9000,
        idle_rpm: int = 800,
        redline_rpm: int = 8500,
        oil_capacity_liters: float = 8.5,
        coolant_capacity_liters: float = 12.0,
    ):
        """
        Initialize engine sensor.

        Args:
            max_rpm: Maximum engine RPM
            idle_rpm: Idle RPM
            redline_rpm: Redline RPM (warning threshold)
            oil_capacity_liters: Oil capacity
            coolant_capacity_liters: Coolant capacity
        """
        # State variables
        self.rpm = idle_rpm
        self.oil_temp = 90.0  # °C
        self.oil_pressure = 4.5  # bar
        self.coolant_temp = 85.0  # °C
        self.boost = 0.0  # bar (turbo boost)
        self.throttle = 0.0  # 0.0 to 1.0
        self.fuel_consumption_rate = 0.0  # L/100km

        # Engine parameters
        self.max_rpm = max_rpm
        self.idle_rpm = idle_rpm
        self.redline_rpm = redline_rpm
        self.oil_capacity = oil_capacity_liters
        self.coolant_capacity = coolant_capacity_liters

        # Operating state
        self.mode = "idle"

    def sample(self, timestamp: float) -> Dict[str, float]:
        """
        Generate one telemetry sample.

        Args:
            timestamp: Current timestamp (seconds)

        Returns:
            Dictionary with engine sensor readings
        """
        # Select driving mode probabilistically
        self.mode = random.choices(
            ["idle", "cruise", "race"], weights=[0.1, 0.6, 0.3], k=1
        )[0]

        # Update RPM and throttle based on mode
        if self.mode == "idle":
            self.rpm = random.gauss(self.idle_rpm, 50)
            self.throttle = 0.0
        elif self.mode == "cruise":
            self.rpm = random.gauss(3500, 300)
            self.throttle = random.uniform(0.2, 0.4)
        else:  # race
            self.rpm = random.gauss(7500, 500)
            self.throttle = random.uniform(0.7, 1.0)

        # Clamp RPM to valid range
        self.rpm = max(self.idle_rpm, min(self.max_rpm, self.rpm))

        # Oil temperature (increases with RPM, cools with airflow)
        heat_rate = (self.rpm / self.max_rpm) * 0.5
        cooling_rate = 0.2 * (self.oil_temp - 90)
        self.oil_temp += heat_rate - cooling_rate

        # Oil pressure (RPM-dependent, drops at high temperature)
        # P = k * RPM * (1 - temp_factor)
        base_pressure = 5.0 * (self.rpm / self.max_rpm)
        temp_penalty = 0.001 * max(0, self.oil_temp - 90)
        self.oil_pressure = base_pressure * (1 - temp_penalty)
        self.oil_pressure = max(1.0, self.oil_pressure)  # Minimum 1 bar

        # Coolant temperature (correlated with oil temp)
        self.coolant_temp = self.oil_temp * 0.95

        # Boost pressure (only when throttle > 50%)
        if self.throttle > 0.5:
            # Turbo spools up proportionally
            target_boost = (self.throttle - 0.5) * 2.0 * 1.8  # Max 1.8 bar
            self.boost += (target_boost - self.boost) * 0.3  # Smooth ramp-up
        else:
            self.boost *= 0.7  # Quick spool-down

        self.boost = max(0.0, self.boost)

        # Fuel consumption (throttle-dependent)
        # Base: 8 L/100km, Racing: 20 L/100km
        self.fuel_consumption_rate = 8.0 + self.throttle * 12.0

        # Inject overheating anomaly (2% probability)
        if random.random() < 0.02:
            self._inject_overheat()

        # Ensure physical constraints
        self.oil_temp = max(60.0, min(150.0, self.oil_temp))
        self.coolant_temp = max(60.0, min(130.0, self.coolant_temp))

        return {
            "engine_rpm": int(self.rpm),
            "engine_oil_temp": float(self.oil_temp),
            "engine_oil_pressure": float(self.oil_pressure),
            "engine_coolant_temp": float(self.coolant_temp),
            "boost_pressure": float(self.boost),
            "fuel_consumption_rate": float(self.fuel_consumption_rate),
            "throttle_position": float(self.throttle),
        }

    def _inject_overheat(self) -> None:
        """
        Inject overheating anomaly.

        Simulates coolant leak or radiator failure:
        - Rapid coolant temperature rise
        - Secondary oil temperature increase
        - Detectable as sudden temperature spike
        """
        self.coolant_temp += random.uniform(20, 35)
        self.oil_temp += random.uniform(10, 20)

        # Optional: Log event for debugging
        # print(f"OVERHEAT: Coolant {self.coolant_temp:.1f}°C, Oil {self.oil_temp:.1f}°C")
