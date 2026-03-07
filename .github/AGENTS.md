# Smainer Development Agents

Specialized agents for building the Smainer decentralized compute marketplace. Each agent focuses on specific domains with optimized tool access and expert knowledge.

## Team Structure

### 🚀 Core Development

**[@frontend-engineer](./agents/frontend-engineer.agent.md)**  
Next.js frontend, starknet-react wallet integration, Argent X/Braavos connections, dashboard UI, compute task forms, shadcn/ui components, Tailwind styling

**[@starknet-engineer](./agents/starknet-engineer.agent.md)**  
Cairo smart contracts, DeFi protocols, decentralized compute networks, escrow systems, ERC-20 integration, Scarb projects, security auditing  

**[@relayer-architect](./agents/relayer-architect.agent.md)**  
FastAPI coordination service, WebSocket compute nodes, job scheduling, result aggregation, signature verification, Starknet bundling, Redis state

**[@systems-engineer](./agents/systems-engineer.agent.md)**  
Python daemons, distributed compute workers, WebSocket/REST clients, Docker sandboxing, cryptographic signing, resource monitoring

**[@telegram-bot-developer](./agents/telegram-bot-developer.agent.md)**  
Telegram bots, WebApp integration, wallet connectivity, crypto payment flows, encrypted messaging, miniapps, security architecture

### 🎨 Product & Brand

**[@brand-designer](./agents/brand-designer.agent.md)**  
Brand identity, color palettes, UI/UX aesthetics, marketing funnel optimization, professional minimalist interfaces, AI-generated design critique

**[@marketing-copywriter](./agents/marketing-copywriter.agent.md)**  
Marketing copy, headlines, CTAs, value propositions, technical descriptions, onboarding flows, conversion optimization for power users

**[@fee-economist](./agents/fee-economist.agent.md)**  
Protocol fee structure, treasury splits, gas subsidy logic, token economics modeling, transparent pricing UI design

### ⚙️ Operations  

**[@it-guy](./agents/it-guy.agent.md)**  
Git operations, repository management, branching strategies, deployment, DevOps, infrastructure setup, dependency management

**[@chief-director](./agents/chief-director.agent.md)**  
System-wide status reporting, cross-agent coordination, launch prerequisites, go-to-market strategy, development roadmap guidance

## Specialized Workflows

### Feature Development Pipeline
1. **[@chief-director]** - Plan feature and coordinate team
2. **[@frontend-engineer]** OR **[@starknet-engineer]** - Build core functionality  
3. **[@brand-designer]** - Design review and visual optimization
4. **[@marketing-copywriter]** - User-facing copy and messaging
5. **[@it-guy]** - Deployment and infrastructure

### Telegram Bot Development  
1. **[@telegram-bot-developer]** - Bot architecture and security design
2. **[@starknet-engineer]** - Blockchain integration patterns
3. **[@systems-engineer]** - Infrastructure and scaling considerations
4. **[@it-guy]** - Deployment pipeline setup

### Security & Privacy Features
1. **[@telegram-bot-developer]** - Privacy architecture design  
2. **[@systems-engineer]** - Secure execution environment
3. **[@starknet-engineer]** - On-chain security verification
4. **[@fee-economist]** - Economic security models

## Quick Commands

**Development Tasks:**
- `@frontend-engineer` Build wallet connection UI
- `@starknet-engineer` Create escrow smart contract  
- `@relayer-architect` Design task distribution system
- `@telegram-bot-developer` Implement payment flow

**Product & Marketing:**
- `@brand-designer` Redesign color palette
- `@marketing-copywriter` Write landing page copy
- `@fee-economist` Model pricing strategy

**Operations:**
- `@it-guy` Set up deployment pipeline
- `@chief-director` Status report and next milestones

## Cross-Agent Communication

Agents can invoke each other as subagents:

```markdown
@frontend-engineer Please build the staking interface. 
Coordinate with @brand-designer for visual design and @starknet-engineer for contract integration.
```

**Best Practices:**
- Start with **[@chief-director]** for complex multi-component features
- Use **[@brand-designer]** early in UI development for consistent aesthetics
- Involve **[@telegram-bot-developer]** for any privacy-sensitive features
- Coordinate **[@fee-economist]** when building payment/reward systems

## Context Files

Agents automatically load relevant context:
- **[crypto-security.instructions.md](./instructions/crypto-security.instructions.md)** - Security patterns for crypto development
- **[web3-integration.instructions.md](./instructions/web3-integration.instructions.md)** - Wallet connection and DeFi patterns

## Quick Prompts

- **`/telegram-api`** - Generate bot handlers, keyboards, commands
- **`/deployment-security`** - Docker configs, environment validation, production checklists

---

*Use `@agent-name task description` to invoke specialized agents. For complex workflows, start with @chief-director for coordination.*