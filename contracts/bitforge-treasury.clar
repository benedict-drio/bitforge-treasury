;; BitForge Treasury - Decentralized Bitcoin-Native Investment Protocol
;; 
;; OVERVIEW:
;; A sophisticated treasury management protocol built on Stacks that enables 
;; community-driven investment decisions through secure tokenized governance,
;; time-locked deposits, and democratic proposal execution mechanisms.
;;
;; DESCRIPTION:
;; BitForge Treasury represents the next evolution of decentralized finance on
;; Bitcoin's Layer 2. This protocol transforms traditional treasury management
;; by implementing a trustless, community-governed investment vehicle that
;; harnesses Bitcoin's security while enabling sophisticated DeFi operations.
;;
;; CORE FEATURES:
;; - Tokenized Governance: Stake STX to receive governance tokens with voting power
;; - Secure Time-Locks: Mandatory lock periods prevent panic withdrawals and manipulation  
;; - Democratic Proposals: Community members propose and vote on fund allocations
;; - Bitcoin-Native Security: Leverages Stacks' unique Bitcoin finality guarantees
;; - Transparent Operations: All treasury movements are publicly auditable on-chain
;;
;; WORKFLOW:
;; 1. Users stake STX tokens to receive proportional governance tokens
;; 2. Governance token holders can propose treasury fund allocations
;; 3. Community votes on proposals using their governance token weight
;; 4. Approved proposals are executed, transferring funds to specified targets
;; 5. Users can unstake after time-lock period expires
;;
;; SECURITY MODEL:
;; - Time-locked deposits prevent manipulation and ensure commitment
;; - Voting power is proportional to economic stake in the protocol
;; - Proposals have expiration dates to prevent stale governance
;; - Double-voting protection ensures democratic integrity
;; - Contract owner controls only initialization, not fund movements
;;

;; PROTOCOL CONSTANTS & ERROR DEFINITIONS

;; Contract deployer - only used for initialization
(define-constant CONTRACT_OWNER tx-sender)

;; Error codes for various failure conditions
(define-constant ERR_OWNER_ONLY (err u100))         ;; Action restricted to contract owner
(define-constant ERR_NOT_INITIALIZED (err u101))    ;; Protocol not yet initialized
(define-constant ERR_ALREADY_INITIALIZED (err u102)) ;; Protocol already initialized
(define-constant ERR_INSUFFICIENT_BALANCE (err u103)) ;; Not enough tokens/STX
(define-constant ERR_INVALID_AMOUNT (err u104))     ;; Invalid amount parameter
(define-constant ERR_UNAUTHORIZED (err u105))       ;; Caller lacks permission
(define-constant ERR_PROPOSAL_NOT_FOUND (err u106)) ;; Proposal ID doesn't exist
(define-constant ERR_PROPOSAL_EXPIRED (err u107))   ;; Proposal past deadline
(define-constant ERR_ALREADY_VOTED (err u108))      ;; User already voted on proposal
(define-constant ERR_BELOW_MINIMUM (err u109))      ;; Amount below minimum threshold
(define-constant ERR_LOCKED_PERIOD (err u110))      ;; Tokens still time-locked
(define-constant ERR_TRANSFER_FAILED (err u111))    ;; STX transfer failed
(define-constant ERR_INVALID_DURATION (err u112))   ;; Proposal duration out of bounds
(define-constant ERR_ZERO_AMOUNT (err u113))        ;; Amount cannot be zero
(define-constant ERR_INVALID_TARGET (err u114))     ;; Invalid target address
(define-constant ERR_INVALID_DESCRIPTION (err u115)) ;; Empty or invalid description

;; Governance proposal time bounds (in blocks, ~10 minutes per block)
(define-constant MINIMUM_PROPOSAL_DURATION u144)   ;; 1 day minimum voting period
(define-constant MAXIMUM_PROPOSAL_DURATION u20160) ;; 14 days maximum voting period

;; PROTOCOL STATE VARIABLES

;; Total governance tokens in circulation
(define-data-var total-supply uint u0)

;; Minimum STX deposit required to participate (1 STX in microSTX)
(define-data-var minimum-deposit uint u1000000)

;; Time-lock period in blocks (~10 days at 10 minutes per block)
(define-data-var lock-period uint u1440)

;; Protocol initialization status - prevents usage before setup
(define-data-var protocol-initialized bool false)

;; Track last rebalance for potential future yield distribution
(define-data-var last-rebalance uint u0)

;; Incrementing counter for unique proposal IDs
(define-data-var proposal-counter uint u0)

;; DATA STORAGE MAPS

;; Governance Token Balances
;; Maps each principal to their governance token balance
;; These tokens represent voting power proportional to their STX stake
(define-map token-balances principal uint)

;; User Deposit Registry
;; Tracks each user's deposit details including time-lock information
;; Structure:
;; - amount: STX deposited (in microSTX)
;; - lock-until: Block height when tokens can be withdrawn
;; - last-reward-block: For potential future reward distribution
(define-map user-deposits
    principal
    {
        amount: uint,
        lock-until: uint,
        last-reward-block: uint
    }
)

;; Treasury Proposal Registry
;; Stores all governance proposals with their metadata and vote counts
;; Structure:
;; - proposer: Who submitted the proposal
;; - description: Text description of the proposal
;; - amount: STX amount to transfer if approved
;; - target: Recipient address for the funds
;; - expires-at: Block height when voting ends
;; - executed: Whether proposal has been executed
;; - yes-votes: Total governance tokens voting in favor
;; - no-votes: Total governance tokens voting against
(define-map treasury-proposals
    uint
    {
        proposer: principal,
        description: (string-ascii 256),
        amount: uint,
        target: principal,
        expires-at: uint,
        executed: bool,
        yes-votes: uint,
        no-votes: uint
    }
)

;; Vote Tracking Registry
;; Prevents double-voting by tracking who voted on which proposals
;; Key: {proposal-id, voter} -> Value: true (prevents duplicate entries)
(define-map proposal-votes {proposal-id: uint, voter: principal} bool)

;; PRIVATE UTILITY FUNCTIONS

;; Owner Permission Check
;; Returns true if the transaction sender is the contract owner
;; Used to restrict initialization to the deployer
(define-private (is-protocol-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

;; Protocol Initialization Check
;; Ensures the protocol has been properly initialized before use
;; Returns ok(true) if initialized, throws ERR_NOT_INITIALIZED otherwise
(define-private (assert-protocol-initialized)
    (ok (asserts! (var-get protocol-initialized) ERR_NOT_INITIALIZED))
)

;; Voting Power Query
;; Returns the governance token balance (voting power) for a given principal
;; Returns 0 if the principal has no tokens
(define-private (get-voting-power (voter principal))
    (default-to u0 (map-get? token-balances voter))
)

;; Internal Token Transfer
;; Safely transfers governance tokens between accounts with balance validation
;; Updates both sender and recipient balances atomically
;; @param sender: Account to debit tokens from
;; @param recipient: Account to credit tokens to  
;; @param amount: Number of tokens to transfer
(define-private (internal-token-transfer (sender principal) (recipient principal) (amount uint))
    (let (
        (sender-balance (default-to u0 (map-get? token-balances sender)))
        (recipient-balance (default-to u0 (map-get? token-balances recipient)))
    )
        (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
        (map-set token-balances sender (- sender-balance amount))
        (map-set token-balances recipient (+ recipient-balance amount))
        (ok true)
    )
)

;; Governance Token Minting
;; Creates new governance tokens and assigns them to an account
;; Updates both individual balance and total supply
;; @param account: Principal to receive newly minted tokens
;; @param amount: Number of tokens to create
(define-private (mint-governance-tokens (account principal) (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? token-balances account)))
    )
        (map-set token-balances account (+ current-balance amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)
    )
)

;; Governance Token Burning
;; Destroys governance tokens from an account's balance
;; Updates both individual balance and total supply
;; @param account: Principal to burn tokens from
;; @param amount: Number of tokens to destroy
(define-private (burn-governance-tokens (account principal) (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? token-balances account)))
    )
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        (map-set token-balances account (- current-balance amount))
        (var-set total-supply (- (var-get total-supply) amount))
        (ok true)
    )
)

;; CORE PROTOCOL FUNCTIONS

;; Protocol Initialization
;; One-time setup function that enables the treasury protocol
;; Can only be called by the contract owner
;; Prevents accidental usage before proper configuration
;; @returns: ok(true) on success
(define-public (initialize-protocol)
    (begin
        (asserts! (is-protocol-owner) ERR_OWNER_ONLY)
        (asserts! (not (var-get protocol-initialized)) ERR_ALREADY_INITIALIZED)
        (var-set protocol-initialized true)
        (ok true)
    )
)

;; Stake Deposit Function
;; Allows users to deposit STX and receive proportional governance tokens
;; Implements time-lock mechanism to prevent manipulation
;; 
;; Process:
;; 1. Validates deposit amount meets minimum threshold
;; 2. Transfers STX from user to treasury contract
;; 3. Records deposit with time-lock information
;; 4. Mints governance tokens equal to STX deposited (1:1 ratio)
;;
;; @param amount: STX amount to deposit (in microSTX)
;; @returns: ok(true) on successful deposit
(define-public (stake-deposit (amount uint))
    (begin
        (try! (assert-protocol-initialized))
        (asserts! (>= amount (var-get minimum-deposit)) ERR_BELOW_MINIMUM)
        
        ;; Secure STX transfer to treasury contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Register user deposit with time-lock
        (map-set user-deposits tx-sender {
            amount: amount,
            lock-until: (+ stacks-block-height (var-get lock-period)),
            last-reward-block: stacks-block-height
        })
        
        ;; Issue governance tokens proportional to deposit (1:1 ratio)
        (mint-governance-tokens tx-sender amount)
    )
)