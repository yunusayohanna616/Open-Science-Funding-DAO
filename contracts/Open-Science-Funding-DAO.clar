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

(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-VOTING-CLOSED (err u107))
(define-constant VOTING-PERIOD u144)

(define-map MilestoneVotes
    {
        proposal-id: uint,
        milestone-id: uint,
    }
    {
        yes-votes: uint,
        no-votes: uint,
        total-voters: uint,
        voting-deadline: uint,
        executed: bool,
    }
)

(define-map VoterRecord
    {
        voter: principal,
        proposal-id: uint,
        milestone-id: uint,
    }
    { voted: bool }
)

(define-read-only (get-milestone-votes
        (proposal-id uint)
        (milestone-id uint)
    )
    (map-get? MilestoneVotes {
        proposal-id: proposal-id,
        milestone-id: milestone-id,
    })
)

(define-read-only (has-voted
        (voter principal)
        (proposal-id uint)
        (milestone-id uint)
    )
    (default-to false
        (get voted
            (map-get? VoterRecord {
                voter: voter,
                proposal-id: proposal-id,
                milestone-id: milestone-id,
            })
        ))
)

(define-public (start-milestone-vote
        (proposal-id uint)
        (milestone-id uint)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (milestone (unwrap! (get-milestone proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status milestone) "PENDING") ERR-INVALID-STATUS)
        (map-set MilestoneVotes {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        } {
            yes-votes: u0,
            no-votes: u0,
            total-voters: u0,
            voting-deadline: (+ burn-block-height VOTING-PERIOD),
            executed: false,
        })
        (ok true)
    )
)

(define-public (vote-on-milestone
        (proposal-id uint)
        (milestone-id uint)
        (vote-yes bool)
    )
    (let (
            (staker-info (unwrap! (get-staker-info tx-sender proposal-id) ERR-NOT-AUTHORIZED))
            (vote-data (unwrap! (get-milestone-votes proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
            (stake-amount (get amount staker-info))
        )
        (asserts! (not (has-voted tx-sender proposal-id milestone-id))
            ERR-ALREADY-VOTED
        )
        (asserts! (< burn-block-height (get voting-deadline vote-data))
            ERR-VOTING-CLOSED
        )
        (map-set VoterRecord {
            voter: tx-sender,
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        } { voted: true }
        )
        (map-set MilestoneVotes {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        } {
            yes-votes: (if vote-yes
                (+ (get yes-votes vote-data) stake-amount)
                (get yes-votes vote-data)
            ),
            no-votes: (if vote-yes
                (get no-votes vote-data)
                (+ (get no-votes vote-data) stake-amount)
            ),
            total-voters: (+ (get total-voters vote-data) u1),
            voting-deadline: (get voting-deadline vote-data),
            executed: (get executed vote-data),
        })
        (ok true)
    )
)

(define-public (execute-milestone-vote
        (proposal-id uint)
        (milestone-id uint)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (milestone (unwrap! (get-milestone proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
            (vote-data (unwrap! (get-milestone-votes proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
        )
        (asserts! (>= burn-block-height (get voting-deadline vote-data))
            ERR-VOTING-CLOSED
        )
        (asserts! (not (get executed vote-data)) ERR-INVALID-STATUS)
        (asserts! (> (get yes-votes vote-data) (get no-votes vote-data))
            ERR-INVALID-STATUS
        )
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
        (map-set MilestoneVotes {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        }
            (merge vote-data { executed: true })
        )
        (ok true)
    )
)

(define-map ResearcherReputation
    { researcher: principal }
    {
        total-projects: uint,
        completed-projects: uint,
        total-milestones: uint,
        completed-milestones: uint,
        reputation-score: uint,
        last-updated: uint,
    }
)

(define-map ProjectOutcomes
    { proposal-id: uint }
    {
        outcome-reported: bool,
        success-rating: uint,
        impact-score: uint,
        peer-reviews: uint,
    }
)

(define-read-only (get-researcher-reputation (researcher principal))
    (default-to {
        total-projects: u0,
        completed-projects: u0,
        total-milestones: u0,
        completed-milestones: u0,
        reputation-score: u0,
        last-updated: u0,
    }
        (map-get? ResearcherReputation { researcher: researcher })
    )
)

(define-read-only (get-project-outcome (proposal-id uint))
    (map-get? ProjectOutcomes { proposal-id: proposal-id })
)

(define-read-only (calculate-reputation-score
        (total-projects uint)
        (completed-projects uint)
        (total-milestones uint)
        (completed-milestones uint)
    )
    (if (is-eq total-projects u0)
        u0
        (let (
                (project-completion-rate (/ (* completed-projects u100) total-projects))
                (milestone-completion-rate (if (is-eq total-milestones u0)
                    u0
                    (/ (* completed-milestones u100) total-milestones)
                ))
            )
            (/ (+ project-completion-rate milestone-completion-rate) u2)
        )
    )
)

(define-private (update-researcher-reputation-on-milestone
        (researcher principal)
        (milestone-completed bool)
    )
    (let ((current-rep (get-researcher-reputation researcher)))
        (map-set ResearcherReputation { researcher: researcher } {
            total-projects: (get total-projects current-rep),
            completed-projects: (get completed-projects current-rep),
            total-milestones: (+ (get total-milestones current-rep) u1),
            completed-milestones: (if milestone-completed
                (+ (get completed-milestones current-rep) u1)
                (get completed-milestones current-rep)
            ),
            reputation-score: (calculate-reputation-score (get total-projects current-rep)
                (get completed-projects current-rep)
                (+ (get total-milestones current-rep) u1)
                (if milestone-completed
                    (+ (get completed-milestones current-rep) u1)
                    (get completed-milestones current-rep)
                )),
            last-updated: burn-block-height,
        })
    )
)

(define-private (update-researcher-reputation-on-project
        (researcher principal)
        (project-completed bool)
    )
    (let ((current-rep (get-researcher-reputation researcher)))
        (map-set ResearcherReputation { researcher: researcher } {
            total-projects: (+ (get total-projects current-rep) u1),
            completed-projects: (if project-completed
                (+ (get completed-projects current-rep) u1)
                (get completed-projects current-rep)
            ),
            total-milestones: (get total-milestones current-rep),
            completed-milestones: (get completed-milestones current-rep),
            reputation-score: (calculate-reputation-score (+ (get total-projects current-rep) u1)
                (if project-completed
                    (+ (get completed-projects current-rep) u1)
                    (get completed-projects current-rep)
                )
                (get total-milestones current-rep)
                (get completed-milestones current-rep)
            ),
            last-updated: burn-block-height,
        })
    )
)

(define-public (report-project-outcome
        (proposal-id uint)
        (success-rating uint)
        (impact-score uint)
    )
    (let ((proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (asserts! (<= success-rating u10) ERR-INVALID-AMOUNT)
        (asserts! (<= impact-score u10) ERR-INVALID-AMOUNT)
        (map-set ProjectOutcomes { proposal-id: proposal-id } {
            outcome-reported: true,
            success-rating: success-rating,
            impact-score: impact-score,
            peer-reviews: u0,
        })
        (update-researcher-reputation-on-project (get researcher proposal)
            (>= success-rating u7)
        )
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { status: "COMPLETED" })
        )
        (ok true)
    )
)

(define-public (peer-review-project
        (proposal-id uint)
        (review-score uint)
    )
    (let (
            (outcome (unwrap! (get-project-outcome proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (staker-info (unwrap! (get-staker-info tx-sender proposal-id) ERR-NOT-AUTHORIZED))
        )
        (asserts! (get outcome-reported outcome) ERR-INVALID-STATUS)
        (asserts! (<= review-score u10) ERR-INVALID-AMOUNT)
        (asserts! (> (get amount staker-info) u0) ERR-NOT-AUTHORIZED)
        (map-set ProjectOutcomes { proposal-id: proposal-id }
            (merge outcome {
                peer-reviews: (+ (get peer-reviews outcome) u1),
                impact-score: (/ (+ (get impact-score outcome) review-score) u2),
            })
        )
        (ok true)
    )
)
