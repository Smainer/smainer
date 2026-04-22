"""
Test EventBus publish-subscribe functionality.

Verifies thread-safe publish/subscribe operations, topic isolation,
and test reset functionality for the Observer pattern implementation.
"""
from __future__ import annotations

import threading
import time
from typing import Any
import pytest

from smainer_training.events.event_bus import EventBus, get_event_bus


def test_get_event_bus_singleton():
    """Test that get_event_bus returns the same instance."""
    bus1 = get_event_bus()
    bus2 = get_event_bus()
    assert bus1 is bus2


def test_subscribe_and_publish():
    """Test basic subscribe and publish functionality."""
    bus = EventBus()
    received_events = []
    
    def callback(event: Any) -> None:
        received_events.append(event)
    
    # Subscribe to topic
    bus.subscribe("test_topic", callback)
    
    # Publish event
    test_event = {"message": "hello", "value": 42}
    bus.publish("test_topic", test_event)
    
    assert len(received_events) == 1
    assert received_events[0] == test_event


def test_multiple_subscribers():
    """Test that multiple subscribers receive the same event."""
    bus = EventBus()
    received1 = []
    received2 = []
    
    def callback1(event: Any) -> None:
        received1.append(event)
    
    def callback2(event: Any) -> None:
        received2.append(event)
    
    # Subscribe both callbacks
    bus.subscribe("test_topic", callback1)
    bus.subscribe("test_topic", callback2)
    
    # Publish event
    test_event = {"data": "shared"}
    bus.publish("test_topic", test_event)
    
    assert len(received1) == 1
    assert len(received2) == 1
    assert received1[0] == test_event
    assert received2[0] == test_event


def test_topic_isolation():
    """Test that events are only delivered to correct topic subscribers."""
    bus = EventBus()
    topic1_events = []
    topic2_events = []
    
    def topic1_callback(event: Any) -> None:
        topic1_events.append(event)
    
    def topic2_callback(event: Any) -> None:
        topic2_events.append(event)
    
    # Subscribe to different topics
    bus.subscribe("topic1", topic1_callback)
    bus.subscribe("topic2", topic2_callback)
    
    # Publish to topic1
    bus.publish("topic1", "event1")
    
    # Publish to topic2
    bus.publish("topic2", "event2")
    
    assert len(topic1_events) == 1
    assert len(topic2_events) == 1
    assert topic1_events[0] == "event1"
    assert topic2_events[0] == "event2"


def test_unsubscribe():
    """Test unsubscribing from topics."""
    bus = EventBus()
    received_events = []
    
    def callback(event: Any) -> None:
        received_events.append(event)
    
    # Subscribe and publish
    bus.subscribe("test_topic", callback)
    bus.publish("test_topic", "event1")
    
    # Unsubscribe and publish again
    bus.unsubscribe("test_topic", callback)
    bus.publish("test_topic", "event2")
    
    # Should only have received first event
    assert len(received_events) == 1
    assert received_events[0] == "event1"


def test_unsubscribe_nonexistent():
    """Test unsubscribing from nonexistent topic/callback."""
    bus = EventBus()
    
    def callback(event: Any) -> None:
        pass
    
    # Should not raise error
    bus.unsubscribe("nonexistent_topic", callback)
    
    # Subscribe then unsubscribe different callback
    bus.subscribe("test_topic", callback)
    
    def other_callback(event: Any) -> None:
        pass
    
    # Should not raise error
    bus.unsubscribe("test_topic", other_callback)


def test_publish_to_empty_topic():
    """Test publishing to topic with no subscribers."""
    bus = EventBus()
    
    # Should not raise error
    bus.publish("empty_topic", "test_event")


def test_topics_list():
    """Test getting list of active topics."""
    bus = EventBus()
    
    def callback(event: Any) -> None:
        pass
    
    # Initially no topics
    assert bus.topics() == []
    
    # Add subscribers
    bus.subscribe("topic1", callback)
    bus.subscribe("topic2", callback)
    
    topics = bus.topics()
    assert len(topics) == 2
    assert "topic1" in topics
    assert "topic2" in topics
    
    # Unsubscribe - topic should be removed
    bus.unsubscribe("topic1", callback)
    topics = bus.topics()
    assert "topic1" not in topics
    assert "topic2" in topics


def test_subscriber_count():
    """Test getting subscriber count for topics."""
    bus = EventBus()
    
    def callback1(event: Any) -> None:
        pass
        
    def callback2(event: Any) -> None:
        pass
    
    # No subscribers initially
    assert bus.subscriber_count("test_topic") == 0
    
    # Add subscribers
    bus.subscribe("test_topic", callback1)
    assert bus.subscriber_count("test_topic") == 1
    
    bus.subscribe("test_topic", callback2)
    assert bus.subscriber_count("test_topic") == 2
    
    # Remove subscriber
    bus.unsubscribe("test_topic", callback1)
    assert bus.subscriber_count("test_topic") == 1


def test_callback_exception_handling():
    """Test that exceptions in callbacks don't break event delivery."""
    bus = EventBus()
    good_events = []
    
    def failing_callback(event: Any) -> None:
        raise RuntimeError("Callback error")
    
    def good_callback(event: Any) -> None:
        good_events.append(event)
    
    # Subscribe both callbacks
    bus.subscribe("test_topic", failing_callback)
    bus.subscribe("test_topic", good_callback)
    
    # Publish event - should not raise exception
    bus.publish("test_topic", "test_event")
    
    # Good callback should still receive event
    assert len(good_events) == 1
    assert good_events[0] == "test_event"


def test_thread_safety():
    """Test that EventBus operations are thread-safe."""
    bus = EventBus()
    events_received = []
    lock = threading.Lock()
    
    def callback(event: Any) -> None:
        with lock:
            events_received.append(event)
    
    bus.subscribe("test_topic", callback)
    
    # Function to publish events from multiple threads
    def publish_events(thread_id: int, count: int) -> None:
        for i in range(count):
            bus.publish("test_topic", f"thread_{thread_id}_event_{i}")
    
    # Start multiple threads
    threads = []
    for thread_id in range(5):
        thread = threading.Thread(target=publish_events, args=(thread_id, 10))
        threads.append(thread)
        thread.start()
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    
    # Should have received all events
    assert len(events_received) == 50
    
    # Verify all expected events are present
    for thread_id in range(5):
        for i in range(10):
            expected_event = f"thread_{thread_id}_event_{i}"
            assert expected_event in events_received


def test_reset_for_tests():
    """Test that _reset_for_tests clears all state."""
    bus = EventBus()
    
    def callback(event: Any) -> None:
        pass
    
    # Add some subscribers
    bus.subscribe("topic1", callback)
    bus.subscribe("topic2", callback)
    
    assert len(bus.topics()) == 2
    
    # Reset should clear everything
    bus._reset_for_tests()
    
    assert len(bus.topics()) == 0
    assert bus.subscriber_count("topic1") == 0
    assert bus.subscriber_count("topic2") == 0