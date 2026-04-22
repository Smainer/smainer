"""
Training engine adapters.

This package contains concrete TrainingEngine implementations for
various training libraries. Waves 2-5 adapters are now implemented.

Available adapters:
- axolotl_adapter.py (Wave 2) - Apache-2.0 licensed, LoRA/QLoRA/full-ft
- unsloth_adapter.py (Wave 3) - AGPL-3.0 licensed, LoRA/QLoRA optimization
- llama_factory_adapter.py (Wave 4) - Apache-2.0 licensed, comprehensive methods
- transformerlab_adapter.py (Wave 5) - AGPL-3.0 licensed, research-oriented

Each adapter passes the golden test contract in test_golden_engine_contract.py
AGPL adapters (Unsloth, TransformerLab) run in subprocess isolation only.
"""

from .axolotl_adapter import AxolotlAdapter
from .unsloth_adapter import UnslothAdapter  
from .llama_factory_adapter import LlamaFactoryAdapter
from .transformerlab_adapter import TransformerLabAdapter

__all__ = [
    "AxolotlAdapter",
    "UnslothAdapter", 
    "LlamaFactoryAdapter",
    "TransformerLabAdapter",
]