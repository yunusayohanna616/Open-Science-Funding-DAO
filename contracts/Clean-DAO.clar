(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))

(define-data-var dao-admin principal tx-sender)
(define-data-var proposal-count uint u0)
(define-data-var total-funds uint u0)

(define-map Proposals
    { proposal-id: uint }
    {
        researcher: principal,
        title: (string-ascii 100),
        funding-goal: uint,
        current-funding: uint,
        status: (string-ascii 20),
        created-at: uint,
    }
)

(define-map Funders
    {
        funder: principal,
        proposal-id: uint,
    }
    { amount: uint }
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? Proposals { proposal-id: proposal-id })
)

(define-read-only (get-funder-info
        (funder principal)
        (proposal-id uint)
    )
    (map-get? Funders {
        funder: funder,
        proposal-id: proposal-id,
    })
)

(define-public (create-proposal
        (title (string-ascii 100))
        (funding-goal uint)
    )
    (let ((proposal-id (+ (var-get proposal-count) u1)))
        (asserts! (> funding-goal u0) ERR-INVALID-AMOUNT)
        (map-set Proposals { proposal-id: proposal-id } {
            researcher: tx-sender,
            title: title,
            funding-goal: funding-goal,
            current-funding: u0,
            status: "ACTIVE",
            created-at: burn-block-height,
        })
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (fund-proposal
        (proposal-id uint)
        (amount uint)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (current-funding (default-to { amount: u0 } (get-funder-info tx-sender proposal-id)))
        )
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set Funders {
            funder: tx-sender,
            proposal-id: proposal-id,
        } { amount: (+ (get amount current-funding) amount) }
        )
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { current-funding: (+ (get current-funding proposal) amount) })
        )
        (var-set total-funds (+ (var-get total-funds) amount))
        (ok true)
    )
)

(define-public (release-funds (proposal-id uint))
    (let ((proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (try! (as-contract (stx-transfer? (get current-funding proposal) tx-sender (get researcher proposal))))
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { status: "FUNDED" })
        )
        (ok true)
    )
)

(define-public (update-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (var-set dao-admin new-admin)
        (ok true)
    )
)
