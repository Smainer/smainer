#!/bin/bash
# 
# Quick Fix: Redis Timeout Error Handling
# Patches batch processor to treat timeouts as debug, not errors
#

set -euo pipefail

REPO_ROOT="/home/smainer/Smainer"
AGGREGATOR_FILE="${REPO_ROOT}/backend/relayer/src/relayer/core/aggregator.py"
PATCH_FILE="/tmp/batch_processor_fix.patch"

echo "==== Applying Redis Timeout Fix to Batch Processor ===="

# Backup original file
cp "$AGGREGATOR_FILE" "$AGGREGATOR_FILE.backup"
echo "✅ Backed up original file to $AGGREGATOR_FILE.backup"

# Create the patch in /tmp to avoid re-cluttering the repo root
cat > "$PATCH_FILE" << 'EOF'
--- aggregator.py.orig
+++ aggregator.py
@@ -292,13 +292,18 @@
 
     async def _batch_processor(self) -> None:
         """Background task to process batches."""
         logger.info("Started batch processor")
         
         while True:
             try:
                 # Wait for batches to be available
                 batch_id = await self.redis.blpop(BATCH_QUEUE, timeout=10)
                 
                 if batch_id:
                     # batch_id is a tuple (queue_name, batch_id)
                     batch_id = batch_id[1]
                     logger.info(f"Processing batch {batch_id}")
                     # Batch processing will be handled by the chain client
+                else:
+                    # Timeout occurred, no batches available - this is expected
+                    logger.debug("Batch processor timeout (no batches available)")
                     
             except asyncio.CancelledError:
                 logger.info("Batch processor cancelled")
                 break
+            except aioredis.TimeoutError:
+                # Redis timeout is expected when no batches are queued
+                logger.debug("Batch processor Redis timeout (no batches queued)")
+            except aioredis.ConnectionError as e:
+                logger.error(f"Redis connection error in batch processor: {e}")
+                await asyncio.sleep(5)  # Wait before retrying
             except Exception as e:
-                logger.error(f"Error in batch processor: {e}")
+                logger.error(f"Unexpected error in batch processor: {e}")
                 await asyncio.sleep(5)  # Wait before retrying
EOF

# Apply the fix manually since we need to handle Redis timeout properly
python3 << 'PYTHON_EOF'
import sys

AGGREGATOR_FILE = "/home/smainer/Smainer/backend/relayer/src/relayer/core/aggregator.py"

# Read the file
with open(AGGREGATOR_FILE, "r") as f:
    content = f.read()

# Replace the batch processor method with improved error handling
old_method = '''    async def _batch_processor(self) -> None:
        """Background task to process batches."""
        logger.info("Started batch processor")
        
        while True:
            try:
                # Wait for batches to be available
                batch_id = await self.redis.blpop(BATCH_QUEUE, timeout=10)
                
                if batch_id:
                    # batch_id is a tuple (queue_name, batch_id)
                    batch_id = batch_id[1]
                    logger.info(f"Processing batch {batch_id}")
                    # Batch processing will be handled by the chain client
                    
            except asyncio.CancelledError:
                logger.info("Batch processor cancelled")
                break
            except Exception as e:
                logger.error(f"Error in batch processor: {e}")
                await asyncio.sleep(5)  # Wait before retrying'''

new_method = '''    async def _batch_processor(self) -> None:
        """Background task to process batches."""
        logger.info("Started batch processor")
        
        while True:
            try:
                # Wait for batches to be available
                batch_id = await self.redis.blpop(BATCH_QUEUE, timeout=10)
                
                if batch_id:
                    # batch_id is a tuple (queue_name, batch_id)
                    batch_id = batch_id[1]
                    logger.info(f"Processing batch {batch_id}")
                    # Batch processing will be handled by the chain client
                else:
                    # Timeout occurred, no batches available - this is expected
                    logger.debug("Batch processor timeout (no batches available)")
                    
            except asyncio.CancelledError:
                logger.info("Batch processor cancelled")
                break
            except aioredis.TimeoutError:
                # Redis timeout is expected when no batches are queued
                logger.debug("Batch processor Redis timeout (no batches queued)")
            except aioredis.ConnectionError as e:
                logger.error(f"Redis connection error in batch processor: {e}")
                await asyncio.sleep(5)  # Wait before retrying
            except Exception as e:
                logger.error(f"Unexpected error in batch processor: {e}")
                await asyncio.sleep(5)  # Wait before retrying'''

# Replace in content
if old_method in content:
    new_content = content.replace(old_method, new_method)
    
    # Write back
    with open(AGGREGATOR_FILE, "w") as f:
        f.write(new_content)
    print("✅ Applied batch processor timeout fix")
else:
    print("❌ Could not find exact method to replace")
    print("Manual patch required - see /tmp/batch_processor_fix.patch")
    sys.exit(1)
PYTHON_EOF

echo "✅ Fixed batch processor error handling"
echo "   - Redis timeouts now logged as debug instead of error"
echo "   - Specific handling for connection vs timeout errors"
echo "   - Reduced log spam while preserving error visibility"
echo 
echo "🚀 Deploy this fix after contract deployment to clean up logs"