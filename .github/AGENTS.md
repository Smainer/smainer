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

**[@security-expert](./agents/security-expert.agent.md)**  
Application security reviews, threat modeling, auth hardening, callback/webhook integrity, secret handling, and security regression testing

### 🎨 Product & Brand

**[@brand-designer](./agents/brand-designer.agent.md)**  
Brand identity, color palettes, UI/UX aesthetics, marketing funnel optimization, professional minimalist interfaces, AI-generated design critique

**[@marketing-copywriter](./agents/marketing-copywriter.agent.md)**  
Marketing copy, headlines, CTAs, value propositions, technical descriptions, onboarding flows, conversion optimization for power users

**[@fee-economist](./agents/fee-economist.agent.md)**  
Protocol fee structure, treasury splits, gas subsidy logic, token economics modeling, transparent pricing UI design

### ⚙️ Operations  

**[@repository-architect](./agents/repository-architect.agent.md)**  
Comprehensive repository management, open source governance, Git coordination, deployment orchestration, community management, release engineering, infrastructure setup

**[@chief-director](./agents/chief-director.agent.md)**  
System-wide status reporting, cross-agent coordination, launch prerequisites, go-to-market strategy, development roadmap guidance

**[@planner](./agents/planner.agent.md)**  
Sprint planning, backlog prioritization, task decomposition, dependency mapping, and distribution of work to specialist agents — the bridge between strategy and execution

## Specialized Workflows

### Feature Development Pipeline
1. **[@chief-director]** - Define goal and coordinate team
2. **[@planner]** - Decompose goal into sprint tasks, sequence by dependency, assign owners
3. **[@frontend-engineer]** OR **[@starknet-engineer]** - Build core functionality  
3. **[@brand-designer]** - Design review and visual optimization
4. **[@marketing-copywriter]** - User-facing copy and messaging
5. **[@repository-architect]** - Security audit, deployment coordination, and release management

### Telegram Bot Development  
1. **[@telegram-bot-developer]** - Bot architecture and security design
2. **[@starknet-engineer]** - Blockchain integration patterns
3. **[@systems-engineer]** - Infrastructure and scaling considerations
4. **[@repository-architect]** - Deployment pipeline setup and release coordination

### Security & Privacy Features
1. **[@security-expert]** - Threat modeling, security review, and abuse-case test planning
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
- `@security-expert` Review auth, callbacks, and secret handling
- `@repository-architect` Coordinate deployment across components
- `@repository-architect` Audit security and dependency status 
- `@repository-architect` Manage release and version coordination
- `@chief-director` Status report and next milestones
- `@planner` Break down [feature] into sprint tasks with owners and dependencies

## Cross-Agent Communication

Agents can invoke each other as subagents:

```markdown
@frontend-engineer Please build the staking interface. 
Coordinate with @brand-designer for visual design and @starknet-engineer for contract integration.
```

**Best Practices:**
- Start with **[@chief-director]** for complex multi-component features
- Use **[@security-expert]** before launch reviews or when adding external callbacks, auth, or wallet flows
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