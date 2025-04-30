# DAO FractionalizedNFT

This project implements a decentralized autonomous organization (DAO) that manages NFTs through **fractional ownership**, enabling **collective governance**, **revenue sharing**, and **secure exits** for its members.

##  What It Does

-  **Fractionalized NFTs**: Each NFT is split into multiple fractions, allowing ownership to be distributed among multiple DAO participants.
-  **Voting & Delegation**: Members vote with their fractional holdings and can delegate their votes to other members.
-  **Royalty Distribution**: Revenues (e.g. resale royalties) are proportionally distributed to fraction holders.
-  **Rage Quit Mechanism**: Members can burn their fractions and leave the DAO if they disagree with governance decisions.
-  **Governance**: On-chain proposal/vote/execute system via `GovernanceDAO`.
-  **Security & Transparency**: All logic is encoded in smart contracts, deployed and audited.

---
## Project Structure

| Folder       | Purpose                                      |
|--------------|----------------------------------------------|
| `src/`       | Smart contracts                              |
| `test/`      | Unit & integration tests using Foundry       |
| `lib/`       | Dependencies (OpenZeppelin, forge-std)       |
| `script/`    | Deployment scripts                           |
| `audit/`     | Static analysis with Slither                 |

---

##  Getting Started

### Requirements

- [Foundry](https://book.getfoundry.sh/)
- Git & Node (for frontend or deployment automation)
- Sepolia ETH via [Infura](https://infura.io)
- MetaMask or private key

```bash
git clone https://github.com/briandekorodi/Homework5.git
cd Homework5
forge install
```

---

## 🧪 Tests

We implemented 6 tests, 5 of which pass successfully:

| Test                                      | Status    |
|------------------------------------------|-----------|
| `testMint()`                             | ✅ Passed |
| `testDelegate()`                         | ✅ Passed |
| `testRageQuit()`                         | ✅ Passed |
| `testIntegration_DistributeRoyalties()`  | ✅ Passed |
| `testFuzz_TransferFractions()`           | ✅ Passed |
| `testGovernanceFlow()`                   | ⚠️ Failed (explanation below) |

> ⚠️ The `testGovernanceFlow()` fails due to `No fractions to vote with`. We decided not to patch this test forcibly in order to maintain system consistency. The error occurs because the governance contract expects voting power based on precise delegation logic, which could not be fully simulated in a unit test.

---

## 📦 Build and Test

```bash
forge build
forge test
forge test --gas-report
```

---

##  Audit

### Static Analysis with Slither

```bash
slither .
```

See full audit in `audit/` folder.

---

##  Deployment

We deployed both smart contracts (`FractionalizedNFT` and `GovernanceDAO`) on Sepolia via Foundry using Infura and a MetaMask private key.

### Deploy Command

```bash
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url https://sepolia.infura.io/v3/1929ddd49e934d72b3e4d629bed9e96b \
  --private-key <YOUR_PRIVATE_KEY> \
  --broadcast
```

> Replace `<YOUR_PRIVATE_KEY>` with your MetaMask private key. Do **not** expose this key in public repositories.

### Contract Addresses

##### sepolia
[Success] Hash: 0x4e6781106cd5557b9c9520e251cbcc791f0097005a2889793eaa6c474f0fb3e2
GovernanceDAO deployed at: 0x4c57D8f79de271D0927C408283b18bf9821844DE
                                                                                                               
##### sepolia                                                                                                  
[Success] Hash: 0x2c9361ccef1b441cb678e9c8f8cecdbf5c2a9d51a814deaced1c740b9459db18                         
FractionalizedNFT deployed at: 0x691Cc642d893fa5F39Ce41EC7d2A425985E4c3fd


[Etherscan Sepolia](https://sepolia.etherscan.io/address/0x654fa9800849234b366c94e40d3d04af0f129828)

---

##  Features

- `mint()` – Mint NFT and split into shares
- `transferFractions()` – Transfer partial ownership
- `delegateFractions()` – Assign voting rights
- `castVote()` – On-chain voting
- `distributeRoyalties()` – Distribute ETH to holders
- `claimRoyalties()` – Individual claiming
- `rageQuit()` – Leave the DAO and burn tokens

---

##  Team

- **Brian**
- **Joakim**
- **Anmool** 

---

## 📄 License

MIT
