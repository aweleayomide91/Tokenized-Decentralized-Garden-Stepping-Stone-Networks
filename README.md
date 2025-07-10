# Tokenized Decentralized Garden Stepping Stone Networks

A blockchain-based system for managing garden stepping stone networks through smart contracts. Each aspect of stepping stone management is tokenized and handled by specialized contracts.

## System Overview

The Tokenized Decentralized Garden Stepping Stone Networks consists of five main smart contracts:

### 1. Path Planning Contract (`path-planning.clar`)
- Designs optimal walkway layouts and stone placement
- Issues Path Planning Tokens (PPT) for completed designs
- Manages design proposals and voting
- Tracks stone coordinates and pathway efficiency

### 2. Safety Inspection Contract (`safety-inspection.clar`)
- Ensures stable footing and trip hazard prevention
- Issues Safety Certificates as NFTs
- Manages inspection schedules and results
- Tracks safety ratings and compliance

### 3. Weed Management Contract (`weed-management.clar`)
- Maintains clear pathways between stepping stones
- Issues Maintenance Tokens (WMT) for completed work
- Schedules regular maintenance tasks
- Tracks pathway cleanliness scores

### 4. Replacement Coordination Contract (`replacement-coordination.clar`)
- Handles cracked or damaged stone substitution
- Manages replacement stone inventory as NFTs
- Coordinates replacement scheduling
- Tracks stone condition and lifecycle

### 5. Aesthetic Enhancement Contract (`aesthetic-enhancement.clar`)
- Provides decorative stone selection and arrangement
- Issues Aesthetic Enhancement NFTs
- Manages design themes and color schemes
- Tracks aesthetic ratings and preferences

## Token Economics

- **Path Planning Tokens (PPT)**: Fungible tokens earned for successful path designs
- **Safety Certificates**: NFTs representing safety inspection approvals
- **Maintenance Tokens (WMT)**: Fungible tokens earned for weed management work
- **Replacement Stone NFTs**: Unique tokens representing individual replacement stones
- **Aesthetic Enhancement NFTs**: Unique tokens representing design enhancements

## Key Features

- Decentralized governance for all network decisions
- Tokenized incentives for maintenance and improvements
- Transparent tracking of all network activities
- Community-driven quality assurance
- Automated scheduling and coordination

## Getting Started

1. Deploy all five smart contracts to the Stacks blockchain
2. Initialize each contract with appropriate parameters
3. Begin issuing tokens for completed work
4. Use the governance mechanisms to make network decisions

## Contract Interactions

Each contract operates independently without cross-contract calls, maintaining their own state and token economies. Users can interact with multiple contracts to participate in different aspects of the stepping stone network management.

## Testing

Run the test suite using Vitest:

\`\`\`bash
npm test
\`\`\`

Tests cover all contract functionality including token issuance, governance, and state management.
