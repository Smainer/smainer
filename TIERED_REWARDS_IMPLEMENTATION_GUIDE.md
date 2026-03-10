# Smainer Tiered Reward System - Implementation Guide

## 🎯 **System Overview**

The Smainer platform now supports **hardware-tier-based rewards** to properly compensate high-performance compute nodes. This documentation guides remaining implementation across the stack.

## ✅ **COMPLETED: Relayer Architecture** 

**Tier Classification System:**
- **BASIC Tier**: < 24GB VRAM → 1.0x reward multiplier  
- **PRO Tier**: 24GB+ VRAM → 2.2x reward multiplier  
- **PREMIUM Tier**: RTX 5090 32GB GDDR7 → 3.5x reward multiplier

**Implemented Features:**
- Enhanced GPU/VRAM detection with `nvidia-ml-py`
- WSL2 environment validation for optimal GPU passthrough
- Hardware-aware job scheduling matching tasks to appropriate tiers
- Dynamic reward calculation based on node tier
- Redis-backed tier tracking and node pool management

---

## 🔧 **REQUIRED IMPLEMENTATIONS**

### **1. Smart Contract Updates** 
**Agent:** `starknet-engineer`

**Current State:** Fixed 88% provider payout regardless of hardware tier

**Required Changes:**
```cairo
// Add to SmainerContract storage
tier_multipliers: Map::<u8, u256>,  // tier -> multiplier in basis points

// Add tier constants  
pub const TIER_BASIC: u8 = 1;
pub const TIER_PRO: u8 = 2;
pub const TIER_PREMIUM: u8 = 3;

// Update Task struct
pub struct Task {
    pub creator: ContractAddress,
    pub token_address: ContractAddress,
    pub amount: u256,
    pub base_reward: u256,           // NEW: Original payment amount
    pub tier_multiplier: u256,       // NEW: Multiplier in basis points  
    pub adjusted_reward: u256,       // NEW: Final reward calculation
    pub required_tier: u8,           // NEW: Minimum node tier required
    pub task_hash: felt252,
    pub status: u8,
    pub assigned_provider: ContractAddress,
}
```

**New Functions Needed:**
- `set_tier_multipliers(basic_bps: u256, pro_bps: u256, premium_bps: u256)` - Owner only
- `create_tiered_task(token_address, base_amount, required_tier, task_hash)` - Enhanced task creation
- Update `submit_proof_and_claim` to use `adjusted_reward` instead of `amount`

**Tier Multiplier Setup:**  
- Basic: 10000 basis points (1.0x)
- Pro: 22000 basis points (2.2x)  
- Premium: 35000 basis points (3.5x)

---

### **2. Frontend Integration**
**Agent:** `frontend-engineer`

**Required UI Components:**

**Node Dashboard Enhancements:**
```typescript
// Update types
interface NodeHardware {
  cpu_threads: number;
  ram_gb: number;
  gpu_info?: string;
  gpu_vram_gb?: number;        // NEW
  node_tier: 'basic' | 'pro' | 'premium';  // NEW  
  is_wsl2: boolean;            // NEW
}

// Tier badge component
<TierBadge 
  tier={node.hardware.node_tier}
  vram={node.hardware.gpu_vram_gb} 
/>
```

**Task Submission Form:**
- Tier selector dropdown (Basic/Pro/Premium)
- Real-time reward calculation display
- VRAM requirement input for GPU tasks
- WSL2 requirement toggle

**Pricing Display:**
```typescript
const tierMultipliers = {
  basic: 1.0,
  pro: 2.2, 
  premium: 3.5
};

const estimatedReward = baseAmount * tierMultipliers[selectedTier];
```

**Node Provider Registration:**
- Hardware tier detection and display
- WSL2 compatibility status
- Estimated earnings based on tier

---

### **3. API Enhancements**
**Agent:** `frontend-engineer`

**Update Relayer Client:**
```typescript
// Update TaskSubmission interface
interface TaskSubmission {
  payload: Record<string, any>;
  requirements: {
    cpu_threads: number;
    ram_gb: number; 
    gpu_required: boolean;
    min_vram_gb?: number;        // NEW
    required_tier: NodeTier;     // NEW
    requires_wsl2: boolean;      // NEW
    max_execution_time: number;
  };
  token_amount: number;
  description?: string;
}
```

**New API Endpoints:**
- `GET /api/tiers` - Get tier multipliers and requirements
- `GET /api/nodes/by-tier/{tier}` - List nodes by tier
- `POST /api/tasks/estimate-reward` - Calculate tier-adjusted rewards

---

### **4. Provider Node Updates**
**Agent:** `systems-engineer`

**Required Enhancements:**
- Install `nvidia-ml-py>=12.535.133` dependency
- Update hardware registration to include tier information
- Implement WSL2 validation warnings for Windows users
- Add tier-based task acceptance logic

**Hardware Registration Enhancement:**
```python
# Send enhanced hardware specs to relayer
hardware_spec = {
    "cpu_threads": get_cpu_count(),
    "ram_gb": get_ram_gb(),
    "gpu_info": get_gpu_model(),
    "gpu_vram_gb": get_gpu_vram(),      # NEW
    "node_tier": determine_tier(),      # NEW 
    "is_wsl2": detect_wsl2(),          # NEW
    "storage_gb": get_storage_gb()
}
```

---

## 🧪 **Testing Requirements**

### **Integration Tests Needed:**

**Relayer Tests:** ✅ Already implemented
- GPU tier detection accuracy
- WSL2 environment validation  
- Hardware-aware task scheduling
- Tier-based reward calculations

**Smart Contract Tests:**
- Tier multiplier configuration
- Tiered task creation and completion
- Accurate reward distribution based on tier

**Frontend Tests:**  
- Tier display and selection UI
- Reward estimation accuracy
- Node hardware tier visualization

**End-to-End Tests:**
- Full task lifecycle with tier-based rewards
- Node registration with hardware detection
- Reward payout verification

---

## 🚀 **Deployment Checklist**

### **Phase 1: Backend Infrastructure** ✅ COMPLETE
- [x] Relayer tier-based scheduling
- [x] Enhanced GPU detection  
- [x] WSL2 validation

### **Phase 2: Smart Contracts** 
- [ ] Deploy updated SmainerContract with tier support
- [ ] Configure tier multipliers (1.0x, 2.2x, 3.5x)
- [ ] Test tiered reward payouts

### **Phase 3: Frontend Integration**
- [ ] Update task submission forms with tier selection
- [ ] Implement real-time reward estimation
- [ ] Add tier badges and hardware displays
- [ ] Update node provider dashboard

### **Phase 4: Provider Rollout**
- [ ] Deploy enhanced provider nodes with tier detection
- [ ] Update documentation for node operators
- [ ] Monitor tier distribution and reward accuracy

---

## ⚡ **Key Benefits**

**For High-Spec Node Operators:**
- RTX 5090 nodes earn 3.5x rewards for complex AI inference
- Pro-tier nodes (24GB+) get 2.2x for deep reasoning tasks
- Proper compensation for hardware investment

**For Task Requestors:**  
- Access to premium-tier hardware for demanding workloads
- Guaranteed performance for Llama 4 Scout (109B) and Llama 3.3 (70B) models
- Transparent tier-based pricing

**For Network Health:**
- Incentivizes high-performance node participation
- Attracts users requiring heavy compute workloads  
- Balances network hardware distribution

---

## 📋 **Implementation Priority**

1. **IMMEDIATE**: Smart contract tier system (`starknet-engineer`)
2. **NEXT**: Frontend tier selection and display (`frontend-engineer`)  
3. **FINAL**: Provider node tier registration (`systems-engineer`)

**Target Timeline**: Complete implementation within 2 sprints

---

*This document represents the complete roadmap for integrating hardware-tier-based rewards across the Smainer platform. Each agent should implement their designated components while maintaining compatibility with the tier classification system.*