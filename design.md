# Design Document – FractionalizedNFT DAO

## 1. Short Technical Specification and Architecture Diagram

This system allows users to collectively own NFTs via fractionalization and vote on proposals using their fractions. It integrates two smart contracts:

- `FractionalizedNFT.sol` manages fractionalized ownership, royalty distribution, voting delegation, and core governance features.
- `GovernanceDAO.sol` handles proposal creation, voting tracking, and execution using the voting power provided by `FractionalizedNFT`.

### Contract Interaction Diagram
```
User Wallet
   │
   └─▶ FractionalizedNFT
            ├─ mint() ─────────────▶ NFT Ownership
            ├─ transferFractions() ─▶ Fraction Redistribution
            ├─ delegateFractions() ─▶ Voting Power Mapping
            ├─ castVote() ──────────▶ Governance Vote
            ├─ distributeRoyalties() / claimRoyalties()
            └─ rageQuit() ──────────▶ Burn Fractions

   └─▶ GovernanceDAO
            ├─ propose() ──────────▶ Proposal created
            ├─ castVote() ─────────▶ Vote recorded with NFT power
            └─ execute() ──────────▶ Action completed after success
```

---

## 2. Chosen Token Standard
We extended the **ERC-721** standard using OpenZeppelin’s `ERC721Enumerable`, and introduced internal mappings to represent fractional ownership instead of creating an ERC-20 token.

- **No additional ERC-20 token introduced**: all logic operates purely on ERC-721 NFTs.
- **Fractions represented via mappings**: each NFT is split into `totalFractions`, tracked per address.
- **Voting rights** and **royalty shares** are proportional to owned fractions.

This approach allows composability with standard NFT tools while simplifying user interaction and gas usage.

---

## 3. Chosen Governance Process Model
The DAO uses a **delegated voting model**:
- Voting power is computed based on NFT fractions held.
- Users may delegate specific fractions to another address.
- GovernanceDAO contract manages:
  - **Proposal creation**: `propose()`
  - **Vote casting**: `castVote()` with eligibility check
  - **Proposal execution**: `execute()` when succeeded
- Proposals have a delay, a voting window, and a quorum.

---

## 4. Reflection

### Why Fractionalized NFTs?
- Lowers entry barrier to valuable NFTs by splitting ownership.
- Ensures governance decisions can be influenced by many smaller holders.
- Allows partial exit with `rageQuit()` and passive income through royalties.

### Why This Governance Model?
- Simplicity: direct on-chain voting tied to NFT holdings.
- Delegation enables passive users to still participate via trusted delegates.
- Compatibility with typical DAO frameworks like Compound.

---

## 5. Technical Challenges Encountered
-  **Import issues**: OpenZeppelin paths, remapping and file extensions caused initial build errors.
-  **SafeMath**: legacy math usage required updates as Solidity 0.8+ handles overflow checks.
-  **Test Governance Flow**: complex state simulation (mint → transfer → proposal → vote → execute) was partially working but ultimately failed due to timing/sync issues. Documented and explained.

