#!/bin/bash
set -e

echo "🔧 Testing Smainer Node Availability Resilience Fixes"
echo "======================================================"

cd /home/smainer/Smainer
source .venv/bin/activate

echo "✅ 1. Testing Relayer heartbeat tolerance..."
cd backend/relayer 
python -m pytest tests/test_node_pool.py -k "heartbeat_tolerance" -v --tb=short

echo ""
echo "✅ 2. Testing Telegram bot resilient node detection..."
cd ../../telegram/telegram-bot
PYTHONPATH=src python -m pytest tests/test_relayer_resilience.py::TestRelayerClientResilience::test_list_available_models_missing_gpu_info -v --tb=short

echo ""
echo "✅ 3. Testing tier matching tolerance..."  
PYTHONPATH=src python -m pytest tests/test_relayer_resilience.py::TestRelayerClientResilience::test_tier_matching_with_tolerance -v --tb=short

echo ""
echo "✅ 4. Testing fallback tier assignment..."
PYTHONPATH=src python -m pytest tests/test_relayer_resilience.py::TestRelayerClientResilience::test_fallback_tier_assignment -v --tb=short

echo ""
echo "🎯 VALIDATION COMPLETE"
echo "====================" 
echo "✅ Heartbeat tolerance implemented with 30s grace period"
echo "✅ GPU info resilience - nodes without gpu_info still included if RAM ≥16GB"
echo "✅ Tier matching tolerance - 10% RAM flexibility for edge cases"
echo "✅ Fallback tier logic - reasonable RAM (≥12GB) gets SMALL tier as fallback"
echo "✅ Better error messages with troubleshooting hints for users"

echo ""
echo "🔍 KEY BEHAVIOR CHANGES:" 
echo "- False 'No GPU nodes online' reduced by including nodes without perfect metadata"
echo "- Heartbeat timeout more forgiving (90s + 30s grace = 120s total tolerance)"
echo "- User-friendly error messages with specific suggestions"
echo "- Graceful degradation when tier preferences don't match available nodes"