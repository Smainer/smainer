"""
Event bus for publish-subscribe messaging.

Thread-safe event bus implementing the Observer pattern for decoupled
communication between training engines, telemetry, and monitoring systems.
"""
from __future__ import annotations

import threading
from typing import Any, Callable, Dict, List


class EventBus:
    """
    Thread-safe publish-subscribe event bus.
    
    Implements Observer pattern for decoupled communication between
    training engines, telemetry visitors, and monitoring components.
    Multiple subscribers can listen to the same topic without coupling.
    """
    
    def __init__(self) -> None:
        self._subscribers: Dict[str, List[Callable[[Any], None]]] = {}
        self._lock = threading.Lock()
        
    def subscribe(self, topic: str, callback: Callable[[Any], None]) -> None:
        """
        Subscribe a callback function to a topic.
        
        The callback will be invoked whenever an event is published
        to the specified topic. Callbacks should be thread-safe.
        """
        with self._lock:
            if topic not in self._subscribers:
                self._subscribers[topic] = []
            self._subscribers[topic].append(callback)
            
    def unsubscribe(self, topic: str, callback: Callable[[Any], None]) -> None:
        """Remove a callback subscription from a topic."""
        with self._lock:
            if topic in self._subscribers:
                try:
                    self._subscribers[topic].remove(callback)
                    # Clean up empty topic lists
                    if not self._subscribers[topic]:
                        del self._subscribers[topic]
                except ValueError:
                    pass  # Callback not found
                    
    def publish(self, topic: str, event: Any) -> None:
        """
        Publish an event to all subscribers of a topic.
        
        All registered callbacks for the topic will be invoked
        with the event data. Callbacks are executed synchronously
        in the publishing thread.
        """
        # Get snapshot of subscribers to avoid holding lock during callbacks
        with self._lock:
            callbacks = self._subscribers.get(topic, []).copy()
            
        # Execute callbacks without lock to prevent deadlock
        for callback in callbacks:
            try:
                callback(event)
            except Exception:
                # Log error but continue with other callbacks
                # TODO: Add proper logging in later waves
                pass
                
    def topics(self) -> List[str]:
        """Get list of all topics with active subscribers."""
        with self._lock:
            return list(self._subscribers.keys())
            
    def subscriber_count(self, topic: str) -> int:
        """Get count of subscribers for a topic."""
        with self._lock:
            return len(self._subscribers.get(topic, []))

    def _reset_for_tests(self) -> None:
        """Reset event bus state for testing. Test use only!"""
        with self._lock:
            self._subscribers.clear()


# Module-level singleton instance
_INSTANCE = EventBus()


def get_event_bus() -> EventBus:
    """Get the global event bus instance."""
    return _INSTANCE