"""
Exponential Backoff Retry Logic

Implements retry strategy with:
- Exponential backoff: 1s, 2s, 4s, 8s, 16s...
- Jitter: Random variation to prevent thundering herd
- Max retries: Configurable maximum attempts
- Max delay: Configurable maximum delay cap
"""

import time
import random
import functools
from typing import Callable, TypeVar, Any
import structlog

logger = structlog.get_logger(__name__)

T = TypeVar("T")


class ExponentialBackoff:
    """
    Exponential backoff retry decorator.

    Usage:
        @ExponentialBackoff(max_retries=5, base_delay=1.0, max_delay=60.0)
        def unreliable_function():
            # Code that may fail
            pass
    """

    def __init__(
        self,
        max_retries: int = 5,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        jitter: bool = True,
    ):
        """
        Initialize retry strategy.

        Args:
            max_retries: Maximum number of retry attempts
            base_delay: Initial delay in seconds
            max_delay: Maximum delay cap in seconds
            jitter: Add random jitter to delays
        """
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.jitter = jitter

    def __call__(self, func: Callable[..., T]) -> Callable[..., T]:
        """Decorator implementation."""

        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            last_exception = None

            for attempt in range(self.max_retries):
                try:
                    return func(*args, **kwargs)

                except Exception as e:
                    last_exception = e

                    if attempt == self.max_retries - 1:
                        # Final attempt failed
                        logger.error(
                            "retry_exhausted",
                            function=func.__name__,
                            attempts=self.max_retries,
                            error=str(e),
                        )
                        raise

                    # Calculate delay with exponential backoff
                    delay = min(self.base_delay * (2**attempt), self.max_delay)

                    # Add jitter (0-10% of delay)
                    if self.jitter:
                        jitter_amount = random.uniform(0, 0.1 * delay)
                        delay += jitter_amount

                    logger.warning(
                        "retry_attempt",
                        function=func.__name__,
                        attempt=attempt + 1,
                        max_retries=self.max_retries,
                        delay=f"{delay:.2f}s",
                        error=str(e),
                    )

                    time.sleep(delay)

            # This should never be reached due to raise above
            raise last_exception  # type: ignore

        return wrapper


class AsyncExponentialBackoff:
    """
    Async version of exponential backoff retry decorator.

    Usage:
        @AsyncExponentialBackoff(max_retries=5)
        async def async_unreliable_function():
            # Async code that may fail
            pass
    """

    def __init__(
        self,
        max_retries: int = 5,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        jitter: bool = True,
    ):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.jitter = jitter

    def __call__(self, func: Callable[..., Any]) -> Callable[..., Any]:
        """Decorator implementation for async functions."""

        @functools.wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            import asyncio

            last_exception = None

            for attempt in range(self.max_retries):
                try:
                    return await func(*args, **kwargs)

                except Exception as e:
                    last_exception = e

                    if attempt == self.max_retries - 1:
                        logger.error(
                            "async_retry_exhausted",
                            function=func.__name__,
                            attempts=self.max_retries,
                            error=str(e),
                        )
                        raise

                    delay = min(self.base_delay * (2**attempt), self.max_delay)

                    if self.jitter:
                        jitter_amount = random.uniform(0, 0.1 * delay)
                        delay += jitter_amount

                    logger.warning(
                        "async_retry_attempt",
                        function=func.__name__,
                        attempt=attempt + 1,
                        max_retries=self.max_retries,
                        delay=f"{delay:.2f}s",
                        error=str(e),
                    )

                    await asyncio.sleep(delay)

            raise last_exception  # type: ignore

        return wrapper
