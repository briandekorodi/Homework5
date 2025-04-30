# Audit Summary

This audit includes both static and dynamic analysis to assess the security and efficiency of the FractionalizedNFT DAO system.

---

## Static Analysis (Slither)

The static audit was performed using Slither on the entire project:

- No reentrancy vulnerabilities were detected.
- No arithmetic overflows/underflows were found 

###  Observations:
- Slither reports 524 findings, mostly minor: visibility defaults, shadowed variables, or misleading naming.
- One internal assembly operation in a dependency (`forge-std`) contains a risky bitwise shift operation.

---

## Dynamic Analysis (Gas Report)

We used `forge test --gas-report` to evaluate gas efficiency. Key results:

### Top Gas Consumers:
| Function                     | Avg Gas |
|-----------------------------|---------|
| `mint()`                    | ~428k   |
| `delegateFractions()`       | ~190k   |
| `transferFractions()`       | ~139k   |
| `claimRoyalties()`          | ~43k    |
| `rageQuit()`                | ~81k    |

### Governance:
| Function         | Avg Gas |
|------------------|---------|
| `propose()`      | ~155k   |
| `castVote()`     | ~307k   |
| `execute()`      | ~NA     |

**Deployment Costs:**
- `FractionalizedNFT`: ~5.1M gas  
- `GovernanceDAO`: ~2.2M gas

---

## Recommendations

### 1. Test Coverage
-  Most features are tested.
-  However, the governance flow test fails because the voter has no voting power at the time of voting.
  - **we may Fix by**: ensure the fractions are owned at voting time, or mock delegation more robustly.

### 2. Contract Design
-  Consider splitting `FractionalizedNFT.sol` further: the contract is growing in complexity.
-  `delegateFractions()` allows **multiple delegations without revocation** — this could be gamed in real DAO scenarios.

### 3. Security
- **Validate royalty percentages** to prevent 0% or >100% edge cases.
- Add `nonReentrant` modifier to functions like `claimRoyalties()` to avoid future reentrancy risks.

### 4. Gas Optimizations
- Use `unchecked` blocks for arithmetic where overflow is impossible (e.g., loop counters).
- Cache storage pointers in `getFraction()` and `delegateFractions()`.

---

## Lessons Learned

- DAO-based voting over fractional NFTs requires careful state tracking.
- Using Foundry for test and deployment was efficient but required careful remapping and mocking.

