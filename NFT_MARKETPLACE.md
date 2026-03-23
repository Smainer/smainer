# Smainer NFT Marketplace

## Overview

The Smainer NFT Marketplace is a fully on-chain marketplace built on Starknet for trading AI-generated art, compute credits, provider badges, and compute certificates. It uses STRK as the payment token with built-in escrow, creator royalties, and platform fees.

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────────┐
│  Telegram Bot   │     │   MiniApp    │     │  Next.js Frontend   │
│  /mint command  │     │  NFT Tab     │     │  (future)           │
└────────┬────────┘     └──────┬───────┘     └──────────┬──────────┘
         │                     │                        │
         └─────────┬───────────┘────────────────────────┘
                   ▼
         ┌─────────────────┐
         │  Relayer API    │
         │  /api/v1/nft/*  │
         │  FastAPI + Redis│
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │   Starknet      │
         │  SmainerNFT     │  ERC-721 + categories
         │  Marketplace    │  Escrow + fees
         └─────────────────┘
```

## Smart Contracts

### SmainerNFT (ERC-721)

**Address (Sepolia):** `0x0071a57304dceed85e73014549b5f8cb24bab8d777a67979687570ebf010bc42`

An ERC-721 NFT contract with four asset categories:

| Category | ID | Use Case |
|----------|----|----------|
| AI Art | 0 | AI-generated images from Smainer chat |
| Compute Credit | 1 | Redeemable tokens for compute tasks |
| Provider Badge | 2 | Reputation NFTs for GPU providers |
| Compute Certificate | 3 | Proof-of-computation receipts |

**Key capabilities:**
- Minting restricted to an authorized minter address (the relayer)
- Per-token metadata: category, creator address, token URI
- Query tokens by category or by owner + category
- Pausable by contract owner
- Standard ERC-721 transfers and approvals

### SmainerMarketplace (Escrow)

**Address (Sepolia):** `0x0719488328d8023a6063ebe35a88695aba29c57ca06447f57da95ac0d7bd1348`

A marketplace contract with full escrow. Sellers list NFTs, the contract holds them in escrow, buyers pay in STRK.

**Fee structure:**
- **Marketplace fee:** 2.5% (250 BPS) → treasury
- **Creator royalty:** 2.5% (250 BPS) → original minter
- **Seller receives:** 95% of sale price

**Listing flow:**
1. Seller calls `list_nft(token_id, price)` — NFT transferred to marketplace escrow
2. Buyer calls `buy_nft(listing_id)` — STRK transferred, fees split, NFT sent to buyer
3. Or seller calls `delist_nft(listing_id)` — NFT returned to seller

**Security:** ReentrancyGuard on all mutating functions. Pausable by owner.

## Relayer API

Base path: `/api/v1/nft`

### Browse (Public)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/listings` | GET | Paginated listings with category filter and sort |
| `/listings/{id}` | GET | Single listing detail |
| `/{token_id}` | GET | NFT metadata (category, creator, owner, URI) |
| `/user/{address}` | GET | All NFTs owned by address |
| `/stats/marketplace` | GET | Volume, fees, active listing count |

### Actions (Authenticated)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/mint` | POST | Mint new NFT (auto-increments token ID) |
| `/list` | POST | List NFT for sale on marketplace |
| `/buy` | POST | Purchase a listed NFT |
| `/delist` | POST | Cancel a listing |

### Data layer
- Redis-backed metadata cache and listing index
- Auto-incrementing token ID counter (`nft:next_token_id`)
- Sorted sets for paginated listing queries
- Starknet.py client for on-chain reads and transaction submission

## MiniApp (Telegram)

The NFT tab in the MiniApp has three sub-tabs:

### Marketplace tab
- Browse all active listings as horizontal cards
- Category SVG icons with color-coded borders
- Filter by category (AI Art, Compute Credit, Provider Badge, Compute Certificate)
- Buy modal with price display and confirmation

### Portfolio tab
- View NFTs owned by connected wallet
- List owned NFTs for sale (set price modal)
- Delist active listings

### Trades tab
- Transaction history (buys and sells)
- Status tracking for pending transactions

### Mint from Chat
- Generate an AI image in the chat view
- NFT Preview modal opens with name/description inputs
- Auto-populated attributes: Generation Method, Created At, Network
- Cost estimate: ~3 STRK (base + IPFS storage)
- Mints as AI Art category via relayer

## NFT Categories — Use Cases

### AI Art (category 0)
Generated through the Smainer AI chat. Users create images, then mint them as NFTs. Tradeable on the marketplace.

### Compute Credit (category 1)
Represents prepaid compute time on the Smainer network. Can be transferred or traded. Redeemable for AI inference tasks.

### Provider Badge (category 2)
Earned by GPU providers who maintain uptime and complete tasks. Reputation NFTs that are non-transferable in practice (social proof).

### Compute Certificate (category 3)
Proof that a specific computation was performed on the Smainer network. Immutable receipt with task parameters and result hash.

## Deployment

### Sepolia (Current)
- NFT: `0x0071a57304dceed85e73014549b5f8cb24bab8d777a67979687570ebf010bc42`
- Marketplace: `0x0719488328d8023a6063ebe35a88695aba29c57ca06447f57da95ac0d7bd1348`
- Payment Token: STRK (`0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d`)
- Test mint verified: Token #1, AI Art category

### Deployment Script
```bash
cd contracts && bash scripts/deploy-nft-marketplace.sh
```
Supports both `sepolia` and `mainnet` profiles via `snfoundry.toml`.

## Test Results
- **59 Cairo contract tests** — all passing
- **72 relayer tests** (19 NFT-specific + 53 existing) — all passing
- **12 security vulnerabilities** found and fixed during audit
- **Test mint** verified on Sepolia — token #1 minted and owner confirmed
