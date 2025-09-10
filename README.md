# 🔬 Open Science Funding DAO

A decentralized funding platform for scientific research built on the Stacks blockchain. Empowering researchers and enabling community-driven science funding through milestone-based releases and reputation systems.

## 🌟 Features

### 🧪 **Research Proposals**
- Create comprehensive research proposals with descriptions and categories
- Set funding goals and define milestone counts (up to 10 milestones)
- Automatic researcher profile creation and tracking

### 💰 **Community Funding**
- STX token-based funding mechanism
- Multiple funders can contribute to any proposal
- Transparent funding tracking and history

### 🎯 **Milestone-Based Releases**
- Break projects into measurable milestones
- Weighted voting based on funding contributions
- Automatic fund release upon milestone approval
- 144-block voting period for democratic decision making

### 📊 **Reputation System**
- Track researcher proposal history and completion rates
- Calculate reputation scores based on project success
- Transparent researcher profiles with funding statistics

### 🔐 **Security & Governance**
- DAO admin controls for system governance
- Secure fund escrow and release mechanisms
- Protection against double voting and unauthorized access

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet/) installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd Open-Science-Funding-DAO
clarinet check
```

### Usage Examples

#### Creating a Research Proposal
```clarity
(contract-call? .Open-Science-Funding-DAO create-proposal
  "AI Drug Discovery Platform"
  "Machine learning approach to accelerate pharmaceutical research"
  u1000000  ;; 1M microSTX funding goal
  u3        ;; 3 milestones
  "AI/ML"   ;; category
)
```

#### Funding a Proposal
```clarity
(contract-call? .Open-Science-Funding-DAO fund-proposal
  u1        ;; proposal-id
  u100000   ;; 100k microSTX
)
```

#### Creating Milestones
```clarity
(contract-call? .Open-Science-Funding-DAO create-milestone
  u1                              ;; proposal-id
  u0                              ;; milestone-id
  "Dataset Collection Complete"
  "Gathered 10,000 molecular structures with activity data"
  u300000                         ;; 300k microSTX for this milestone
)
```

#### Voting on Milestones
```clarity
(contract-call? .Open-Science-Funding-DAO vote-on-milestone
  u1     ;; proposal-id
  u0     ;; milestone-id
  true   ;; vote for approval
)
```

## 📋 Contract Functions

### 📖 Read-Only Functions

- `get-proposal(proposal-id)` - Retrieve proposal details
- `get-milestone(proposal-id, milestone-id)` - Get milestone information
- `get-funder-info(funder, proposal-id)` - Check funding contributions
- `get-researcher-profile(researcher)` - View researcher statistics
- `has-voted(voter, proposal-id, milestone-id)` - Check voting status

### ✍️ Public Functions

- `create-proposal(title, description, funding-goal, milestones-count, category)` - Submit research proposal
- `fund-proposal(proposal-id, amount)` - Contribute STX to a proposal
- `create-milestone(proposal-id, milestone-id, title, description, funding-amount)` - Define project milestones
- `vote-on-milestone(proposal-id, milestone-id, vote-for)` - Vote on milestone completion
- `execute-milestone(proposal-id, milestone-id)` - Release milestone funds after voting
- `complete-project(proposal-id)` - Mark project as completed
- `withdraw-unused-funds(proposal-id)` - Reclaim funds from completed/cancelled projects
- `update-dao-admin(new-admin)` - Transfer admin privileges

## 🏗️ Architecture

### Data Structures

- **Proposals**: Core research project information
- **Milestones**: Project breakdowns with voting mechanisms
- **Funders**: Community funding contributions and timestamps
- **MilestoneVotes**: Weighted voting records
- **ResearcherProfile**: Reputation and statistics tracking

### Security Model

- Proposal ownership by researchers
- Funding contribution requirements for voting
- Time-locked voting periods
- Protected admin functions
- Secure fund escrow and release

## 🧪 Testing

```bash
# Run contract checks
clarinet check

# Run test suite (when available)
npm test
```

## 📊 Metrics & Analytics

Track key platform metrics:
- Total proposals created
- Total funding raised
- Average completion rates
- Researcher reputation scores
- Community participation levels

## 🤝 Contributing

We welcome contributions to improve the Open Science Funding DAO! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language](https://docs.stacks.co/clarity/)
- [Clarinet Testing](https://docs.hiro.so/clarinet/)

---

*Built with ❤️ for the open science community*
