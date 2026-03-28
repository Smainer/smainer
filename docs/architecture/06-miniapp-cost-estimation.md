# MiniApp Cost Estimation UI

> Module: `telegram/miniapp/src/`
> Owner Agent: `frontend-engineer`
> Status: Planned

## Purpose

Show users an estimated cost before they approve payment, based on prompt length and selected tier. The user escrows the estimated maximum; actual cost is settled post-inference with automatic on-chain refund of excess.

## User Experience Flow

```
┌──────────────────────────────────────────────┐
│  SMAINER - Pay & Compute                     │
│                                              │
│  Your prompt: "Analyze this document..."     │
│  Tier: PRO                                   │
│                                              │
│  ┌─────────────────────────────────────┐     │
│  │  Cost Estimate                      │     │
│  │                                     │     │
│  │  Input tokens:    ~1,250            │     │
│  │  Model:           llama3.1:70b      │     │
│  │  Effort estimate: 3.2x             │     │
│  │                                     │     │
│  │  Max escrow:      0.92 STRK        │     │
│  │  Estimated actual: ~0.71 STRK      │     │
│  │  Your balance:    426.3 STRK       │     │
│  │                                     │     │
│  │  Excess refunded automatically     │     │
│  │  after task completes.              │     │
│  └─────────────────────────────────────┘     │
│                                              │
│  [ Approve & Pay 0.92 STRK ]                 │
│                                              │
└──────────────────────────────────────────────┘
```

## Token Estimation (Client-Side)

Since we can't run the model's tokenizer in the browser, we use a character-based approximation:

```typescript
/**
 * Estimate token count from prompt text.
 * Approximation: ~4 characters per token for English text.
 * Conservative (over-estimates) to ensure sufficient escrow.
 */
function estimateTokenCount(text: string): number {
  const CHARS_PER_TOKEN = 3.5; // Slightly conservative
  return Math.ceil(text.length / CHARS_PER_TOKEN);
}
```

## Cost Estimation Hook

```typescript
// hooks/useCostEstimate.ts

interface CostEstimate {
  inputTokens: number;
  estimatedEffort: number;     // Capped at 7.5
  maxEscrow: string;           // Formatted STRK amount
  estimatedActual: string;     // Without safety margin
  tierMultiplier: number;
  modelComplexity: number;
}

function useCostEstimate(
  prompt: string,
  tier: ComputeTier,
  modelId: string,
): CostEstimate {
  return useMemo(() => {
    const inputTokens = estimateTokenCount(prompt);
    const maxOutputTokens = 512; // Default Ollama num_predict
    const modelComplexity = getModelComplexity(modelId);

    const effort = Math.min(7.5, Math.max(1.0,
      (inputTokens / 100) * 0.3
      + (maxOutputTokens / 256) * 0.5
      + modelComplexity
    ));

    const tierMult = COMPUTE_TIERS[tier].multiplier;
    const SAFETY_MARGIN = 1.3;

    const maxEscrowWei = BigInt(
      Math.floor(
        Number(BASE_PROMPT_COST) * tierMult * effort * SAFETY_MARGIN
      )
    );

    const estimatedActualWei = BigInt(
      Math.floor(Number(BASE_PROMPT_COST) * tierMult * effort)
    );

    return {
      inputTokens,
      estimatedEffort: effort,
      maxEscrow: formatTokenAmount(maxEscrowWei, TOKEN_DECIMALS.STRK),
      estimatedActual: formatTokenAmount(estimatedActualWei, TOKEN_DECIMALS.STRK),
      tierMultiplier: tierMult,
      modelComplexity,
    };
  }, [prompt, tier, modelId]);
}
```

## Model Complexity Map

```typescript
// lib/starknet.ts — add to existing file

const MODEL_COMPLEXITY: Record<string, number> = {
  // 7B class
  'llama3.1:8b': 0.2,
  'mistral:7b': 0.2,
  'gemma2:9b': 0.2,

  // 13B class
  'llama3.1:13b': 0.4,
  'codellama:13b': 0.4,

  // 34B class
  'codellama:34b': 0.6,
  'yi:34b': 0.6,

  // 70B class
  'llama3.1:70b': 0.8,
  'mixtral:8x7b': 0.8,

  // 100B+ class
  'llama3.1:405b': 1.0,
};

function getModelComplexity(modelId: string): number {
  // Exact match first
  if (MODEL_COMPLEXITY[modelId]) return MODEL_COMPLEXITY[modelId];

  // Fuzzy match by param count
  const match = modelId.match(/(\d+)b/i);
  if (match) {
    const params = parseInt(match[1]);
    if (params >= 100) return 1.0;
    if (params >= 34) return 0.6;
    if (params >= 13) return 0.4;
  }
  return 0.2; // Default to small
}
```

## PaymentFlow Changes

The `PaymentFlow.tsx` component needs these modifications:

### 1. Import and use cost estimate

```typescript
const costEstimate = useCostEstimate(prompt, tier, userModel);
```

### 2. Update createTask to use estimated max escrow

```typescript
// Instead of flat getPromptCost(tier), use dynamic estimate
const escrowAmount = BigInt(
  Math.floor(
    Number(BASE_PROMPT_COST)
    * COMPUTE_TIERS[tier].multiplier
    * costEstimate.estimatedEffort
    * 1.3 // SAFETY_MARGIN
  )
);
```

### 3. Show cost breakdown in confirm step

Replace the static cost display with the dynamic estimate UI showing input tokens, effort estimate, max escrow, and the "excess refunded automatically" note.

### 4. Post-settlement refund display

After task completes, show:
```
Task completed!
Escrowed:  0.92 STRK
Actual:    0.71 STRK
Refunded:  0.21 STRK → your wallet
```

## Escrow vs Actual — User Communication

Key messaging:
- **Before payment**: "Max escrow: X STRK (estimated actual: ~Y STRK)"
- **After payment**: "Escrowed X STRK. Excess refunded when task completes."
- **After settlement**: "Paid Y STRK. Refunded Z STRK to your wallet."

This transparency builds trust — users see they're never overcharged.

## Dependencies

- `lib/starknet.ts` — add MODEL_COMPLEXITY map and `estimateTokenCount()`
- `hooks/useCostEstimate.ts` — new hook
- `hooks/useSmainerContract.ts` — modify `createTask()` to accept dynamic escrow amount
- `components/PaymentFlow.tsx` — update UI to show cost breakdown

## Where Model ID Comes From

The user's preferred model is stored in relayer KV (`prefs:{user_id}:model`) and passed to the MiniApp via the payment URL query parameter:

```
smainer-miniapp.vercel.app/pay?prompt=...&tier=PRO&model=llama3.1:70b
```

The bot already constructs this URL in `handle_inference()`. Just needs to add the `model` parameter.
