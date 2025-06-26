(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-MILESTONE-NOT-FOUND (err u105))

(define-data-var dao-admin principal tx-sender)
(define-data-var proposal-count uint u0)
(define-data-var total-staked uint u0)

(define-map Proposals
    { proposal-id: uint }
    {
        researcher: principal,
        title: (string-ascii 100),
        funding-goal: uint,
        current-funding: uint,
        status: (string-ascii 20),
        milestone-count: uint,
        created-at: uint,
    }
)

(define-map Milestones
    {
        proposal-id: uint,
        milestone-id: uint,
    }
    {
        description: (string-ascii 200),
        funding-amount: uint,
        status: (string-ascii 20),
        completed-at: uint,
    }
)

(define-map StakerInfo
    {
        staker: principal,
        proposal-id: uint,
    }
    { amount: uint }
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? Proposals { proposal-id: proposal-id })
)

(define-read-only (get-milestone
        (proposal-id uint)
        (milestone-id uint)
    )
    (map-get? Milestones {
        proposal-id: proposal-id,
        milestone-id: milestone-id,
    })
)

(define-read-only (get-staker-info
        (staker principal)
        (proposal-id uint)
    )
    (map-get? StakerInfo {
        staker: staker,
        proposal-id: proposal-id,
    })
)

(define-public (create-proposal
        (title (string-ascii 100))
        (funding-goal uint)
        (milestone-count uint)
    )
    (let ((proposal-id (+ (var-get proposal-count) u1)))
        (asserts! (> funding-goal u0) ERR-INVALID-AMOUNT)
        (asserts! (> milestone-count u0) ERR-INVALID-AMOUNT)
        (map-set Proposals { proposal-id: proposal-id } {
            researcher: tx-sender,
            title: title,
            funding-goal: funding-goal,
            current-funding: u0,
            status: "ACTIVE",
            milestone-count: milestone-count,
            created-at: burn-block-height,
        })
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (add-milestone
        (proposal-id uint)
        (milestone-id uint)
        (description (string-ascii 200))
        (funding-amount uint)
    )
    (let ((proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (< milestone-id (get milestone-count proposal))
            ERR-INVALID-AMOUNT
        )
        (map-set Milestones {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        } {
            description: description,
            funding-amount: funding-amount,
            status: "PENDING",
            completed-at: u0,
        })
        (ok true)
    )
)

(define-public (stake-tokens
        (proposal-id uint)
        (amount uint)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (current-stake (default-to { amount: u0 } (get-staker-info tx-sender proposal-id)))
        )
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set StakerInfo {
            staker: tx-sender,
            proposal-id: proposal-id,
        } { amount: (+ (get amount current-stake) amount) }
        )
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { current-funding: (+ (get current-funding proposal) amount) })
        )
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

(define-public (complete-milestone
        (proposal-id uint)
        (milestone-id uint)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (milestone (unwrap! (get-milestone proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
        )
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status milestone) "PENDING") ERR-INVALID-STATUS)
        (try! (as-contract (stx-transfer? (get funding-amount milestone) tx-sender
            (get researcher proposal)
        )))
        (map-set Milestones {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        }
            (merge milestone {
                status: "COMPLETED",
                completed-at: burn-block-height,
            })
        )
        (ok true)
    )
)

(define-public (withdraw-stake (proposal-id uint))
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (staker-info (unwrap! (get-staker-info tx-sender proposal-id)
                ERR-INSUFFICIENT-FUNDS
            ))
        )
        (asserts! (is-eq (get status proposal) "COMPLETED") ERR-INVALID-STATUS)
        (try! (as-contract (stx-transfer? (get amount staker-info) tx-sender tx-sender)))
        (map-delete StakerInfo {
            staker: tx-sender,
            proposal-id: proposal-id,
        })
        (var-set total-staked (- (var-get total-staked) (get amount staker-info)))
        (ok true)
    )
)

(define-public (update-dao-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (var-set dao-admin new-admin)
        (ok true)
    )
)
