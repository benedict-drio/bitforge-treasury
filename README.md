# BitForge Treasury

**Decentralized Bitcoin-Native Investment Protocol**

---

## 📌 Overview

**BitForge Treasury** is a decentralized treasury management protocol built on the **Stacks blockchain**, leveraging Bitcoin's finality guarantees for secure and transparent investment operations.

The protocol enables **community-driven treasury management**, where participants stake STX tokens to gain governance power, propose fund allocations, and vote on proposals. Through **time-locked deposits** and **transparent governance**, BitForge ensures long-term commitment, democratic decision-making, and auditable treasury operations—all secured by Bitcoin.

---

## 🎯 Key Features

* **Tokenized Governance** – Stake STX to receive governance tokens representing voting power.
* **Time-Locked Deposits** – Secure staking with enforced lock periods to prevent manipulation.
* **Democratic Proposals** – Community members propose, vote, and decide on treasury allocations.
* **Bitcoin-Native Security** – Built on Stacks, inheriting Bitcoin’s final settlement guarantees.
* **Transparent Operations** – All treasury activity is fully auditable on-chain.

---

## ⚙️ System Overview

The BitForge Treasury follows a **stake → govern → allocate → withdraw** cycle:

1. **Staking**

   * Users deposit STX into the contract.
   * A 1:1 governance token (gToken) is minted.
   * Deposits are locked for a fixed duration (default \~10 days).

2. **Governance Participation**

   * Governance tokens grant voting power.
   * Token holders submit and vote on treasury proposals.

3. **Proposal Execution**

   * Approved proposals transfer treasury funds to specified addresses.
   * Execution is only possible after the voting period ends.

4. **Withdrawal**

   * After lock expiry, users burn governance tokens to reclaim their STX.

---

## 🏛️ Contract Architecture

The contract is structured into **core modules**:

* **Protocol Lifecycle**

  * `initialize-protocol`: One-time setup by contract owner.
  * `get-protocol-status`: Provides system-level metadata.

* **Staking & Governance Tokens**

  * `stake-deposit`: Deposit STX & mint governance tokens.
  * `unstake-withdrawal`: Burn governance tokens & withdraw STX after lock period.
  * Internal mint/burn functions maintain token supply integrity.

* **Proposal & Voting System**

  * `submit-treasury-proposal`: Create proposals with description, amount, target, and duration.
  * `cast-governance-vote`: Vote “yes” or “no” weighted by governance token balance.
  * `execute-approved-proposal`: Execute only if voting succeeds and period expires.

* **Query Functions** (Read-Only)

  * Governance token balances
  * User deposits and lock states
  * Proposal metadata and voting tallies
  * Total governance token supply

---

## 🗄️ Data Storage Design

| **Storage**            | **Type**                         | **Description**                                    |
| ---------------------- | -------------------------------- | -------------------------------------------------- |
| `token-balances`       | map(principal → uint)            | Governance token balances (voting power).          |
| `user-deposits`        | map(principal → struct)          | Tracks deposited STX, lock expiry, reward blocks.  |
| `treasury-proposals`   | map(uint → struct)               | Stores proposal metadata, votes, execution status. |
| `proposal-votes`       | map({proposal-id, voter} → bool) | Prevents double voting.                            |
| `total-supply`         | uint                             | Total governance tokens minted.                    |
| `proposal-counter`     | uint                             | Incremental ID counter for proposals.              |
| `protocol-initialized` | bool                             | Ensures safe one-time initialization.              |

---

## 🔄 Data Flow

1. **Staking Flow**

   * User calls `stake-deposit` → STX transferred into contract → Deposit recorded → Governance tokens minted.

2. **Proposal Flow**

   * Governance holder calls `submit-treasury-proposal` → Proposal stored → Voting window starts.

3. **Voting Flow**

   * Token holders call `cast-governance-vote` → Votes recorded with weight equal to governance tokens held.

4. **Execution Flow**

   * After expiry, `execute-approved-proposal` validates majority → Treasury transfers funds → Proposal marked executed.

5. **Withdrawal Flow**

   * After lock expiry, user calls `unstake-withdrawal` → Governance tokens burned → STX released.

---

## 🔐 Security Model

* **Time-Locks** – Prevent short-term manipulation and enforce governance commitment.
* **Proportional Voting Power** – Governance influence tied directly to economic stake.
* **Anti Double-Voting** – Each voter can only vote once per proposal.
* **Proposal Expiry** – Prevents execution of stale or outdated proposals.
* **Owner Restrictions** – Owner only initializes protocol; no treasury control afterwards.

---

## 📊 Example Usage

1. **Initialize Protocol** (owner only):

```clarity
(initialize-protocol)
```

2. **Stake STX** (e.g., 2 STX = 2,000,000 µSTX):

```clarity
(stake-deposit u2000000)
```

3. **Submit Proposal** (transfer 1 STX to another address for investment):

```clarity
(submit-treasury-proposal "Fund early-stage investment" u1000000 'SP123... u144)
```

4. **Vote on Proposal**:

```clarity
(cast-governance-vote u1 true)
```

5. **Execute Approved Proposal**:

```clarity
(execute-approved-proposal u1)
```

6. **Unstake After Lock Period**:

```clarity
(unstake-withdrawal u2000000)
```

---

## 📜 License

This protocol is released under the **MIT License**, promoting open collaboration and contribution.
