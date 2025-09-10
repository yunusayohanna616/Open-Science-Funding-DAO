(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-MILESTONE-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-VOTING-CLOSED (err u107))
(define-constant ERR-INSUFFICIENT-VOTES (err u108))
(define-constant ERR-NOT-A-FUNDER (err u109))
(define-constant ERR-PUBLICATION-EXISTS (err u110))
(define-constant ERR-PUBLICATION-NOT-FOUND (err u111))
(define-constant ERR-NO-REWARDS-AVAILABLE (err u112))
(define-constant ERR-REWARDS-ALREADY-CLAIMED (err u113))
(define-constant ERR-DISPUTE-NOT-FOUND (err u114))
(define-constant ERR-DISPUTE-EXISTS (err u115))
(define-constant ERR-DISPUTE-RESOLVED (err u116))

(define-data-var dao-admin principal tx-sender)
(define-data-var proposal-count uint u0)
(define-data-var total-staked uint u0)
(define-data-var milestone-voting-period uint u144)
(define-data-var publication-count uint u0)
(define-data-var reward-pool uint u0)
(define-data-var base-reward-rate uint u5)
(define-data-var dispute-count uint u0)
(define-data-var dispute-voting-period uint u288)

(define-map Proposals
    { proposal-id: uint }
    {
        researcher: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        funding-goal: uint,
        current-funding: uint,
        milestones-count: uint,
        status: (string-ascii 20),
        created-at: uint,
        category: (string-ascii 50),
    }
)

(define-map Milestones
    {
        proposal-id: uint,
        milestone-id: uint,
    }
    {
        title: (string-ascii 100),
        description: (string-ascii 300),
        funding-amount: uint,
        status: (string-ascii 20),
        votes-for: uint,
        votes-against: uint,
        voting-deadline: uint,
        completed-at: uint,
    }
)

(define-map Funders
    {
        funder: principal,
        proposal-id: uint,
    }
    {
        amount: uint,
        funded-at: uint,
    }
)

(define-map MilestoneVotes
    {
        voter: principal,
        proposal-id: uint,
        milestone-id: uint,
    }
    {
        vote: bool,
        voting-power: uint,
    }
)

(define-map ResearcherProfile
    { researcher: principal }
    {
        total-proposals: uint,
        completed-projects: uint,
        total-funding-received: uint,
        reputation-score: uint,
        joined-at: uint,
    }
)

(define-map Publications
    { publication-id: uint }
    {
        researcher: principal,
        proposal-id: uint,
        doi: (string-ascii 100),
        title: (string-ascii 200),
        journal: (string-ascii 100),
        publication-date: uint,
        verified: bool,
        verifier: (optional principal),
        impact-score: uint,
        created-at: uint,
    }
)

(define-map PublicationVerifications
    {
        verifier: principal,
        publication-id: uint,
    }
    { verified: bool }
)

(define-map StakingRewards
    {
        funder: principal,
        proposal-id: uint,
    }
    {
        accumulated-rewards: uint,
        last-claim-block: uint,
        staking-multiplier: uint,
        claimed: bool,
    }
)

(define-map RewardHistory
    {
        funder: principal,
        claim-id: uint,
    }
    {
        amount: uint,
        claimed-at: uint,
        proposal-id: uint,
    }
)

(define-map Disputes
    { dispute-id: uint }
    {
        disputer: principal,
        proposal-id: uint,
        milestone-id: (optional uint),
        dispute-type: (string-ascii 50),
        reason: (string-ascii 300),
        evidence: (string-ascii 500),
        status: (string-ascii 20),
        votes-for: uint,
        votes-against: uint,
        voting-deadline: uint,
        resolution: (string-ascii 200),
        created-at: uint,
        resolved-at: (optional uint),
    }
)

(define-map DisputeVotes
    {
        voter: principal,
        dispute-id: uint,
    }
    {
        vote: bool,
        voting-power: uint,
    }
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

(define-read-only (get-funder-info
        (funder principal)
        (proposal-id uint)
    )
    (map-get? Funders {
        funder: funder,
        proposal-id: proposal-id,
    })
)

(define-read-only (get-researcher-profile (researcher principal))
    (map-get? ResearcherProfile { researcher: researcher })
)

(define-read-only (has-voted
        (voter principal)
        (proposal-id uint)
        (milestone-id uint)
    )
    (is-some (map-get? MilestoneVotes {
        voter: voter,
        proposal-id: proposal-id,
        milestone-id: milestone-id,
    }))
)

(define-read-only (get-publication (publication-id uint))
    (map-get? Publications { publication-id: publication-id })
)

(define-read-only (get-researcher-publication-count (researcher principal))
    (var-get publication-count)
)

(define-read-only (has-verified-publication
        (verifier principal)
        (publication-id uint)
    )
    (default-to false
        (get verified
            (map-get? PublicationVerifications {
                verifier: verifier,
                publication-id: publication-id,
            })
        ))
)

(define-read-only (get-staking-rewards
        (funder principal)
        (proposal-id uint)
    )
    (map-get? StakingRewards {
        funder: funder,
        proposal-id: proposal-id,
    })
)

(define-read-only (calculate-pending-rewards
        (funder principal)
        (proposal-id uint)
    )
    (let (
            (funder-info (unwrap! (get-funder-info funder proposal-id) (ok u0)))
            (reward-info (default-to {
                accumulated-rewards: u0,
                last-claim-block: u0,
                staking-multiplier: u100,
                claimed: false,
            }
                (get-staking-rewards funder proposal-id)
            ))
            (blocks-staked (- stacks-block-height (get funded-at funder-info)))
            (base-reward (/ (* (get amount funder-info) (var-get base-reward-rate)) u100))
            (multiplier-bonus (/ (* base-reward (get staking-multiplier reward-info)) u100))
        )
        (ok (/ (* blocks-staked multiplier-bonus) u1000))
    )
)

(define-read-only (get-total-claimable-rewards
        (funder principal)
        (proposal-id uint)
    )
    (let (
            (pending (unwrap! (calculate-pending-rewards funder proposal-id) (ok u0)))
            (accumulated (default-to u0
                (get accumulated-rewards (get-staking-rewards funder proposal-id))
            ))
        )
        (ok (+ pending accumulated))
    )
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? Disputes { dispute-id: dispute-id })
)

(define-read-only (get-dispute-vote
        (voter principal)
        (dispute-id uint)
    )
    (map-get? DisputeVotes {
        voter: voter,
        dispute-id: dispute-id,
    })
)

(define-read-only (has-voted-on-dispute
        (voter principal)
        (dispute-id uint)
    )
    (is-some (get-dispute-vote voter dispute-id))
)

(define-public (create-proposal
        (title (string-ascii 100))
        (description (string-ascii 500))
        (funding-goal uint)
        (milestones-count uint)
        (category (string-ascii 50))
    )
    (let ((proposal-id (+ (var-get proposal-count) u1)))
        (asserts! (> funding-goal u0) ERR-INVALID-AMOUNT)
        (asserts! (> milestones-count u0) ERR-INVALID-AMOUNT)
        (asserts! (<= milestones-count u10) ERR-INVALID-AMOUNT)
        (map-set Proposals { proposal-id: proposal-id } {
            researcher: tx-sender,
            title: title,
            description: description,
            funding-goal: funding-goal,
            current-funding: u0,
            milestones-count: milestones-count,
            status: "ACTIVE",
            created-at: stacks-block-height,
            category: category,
        })
        (update-researcher-stats tx-sender)
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
            (existing-funding (default-to {
                amount: u0,
                funded-at: u0,
            }
                (get-funder-info tx-sender proposal-id)
            ))
        )
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set Funders {
            funder: tx-sender,
            proposal-id: proposal-id,
        } {
            amount: (+ (get amount existing-funding) amount),
            funded-at: stacks-block-height,
        })
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { current-funding: (+ (get current-funding proposal) amount) })
        )
        (var-set total-staked (+ (var-get total-staked) amount))
        (initialize-staking-rewards tx-sender proposal-id amount)
        (ok true)
    )
)

(define-public (create-milestone
        (proposal-id uint)
        (milestone-id uint)
        (title (string-ascii 100))
        (description (string-ascii 300))
        (funding-amount uint)
    )
    (let ((proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (< milestone-id (get milestones-count proposal))
            ERR-INVALID-AMOUNT
        )
        (asserts! (> funding-amount u0) ERR-INVALID-AMOUNT)
        (map-set Milestones {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        } {
            title: title,
            description: description,
            funding-amount: funding-amount,
            status: "PENDING",
            votes-for: u0,
            votes-against: u0,
            voting-deadline: (+ stacks-block-height (var-get milestone-voting-period)),
            completed-at: u0,
        })
        (ok true)
    )
)

(define-public (vote-on-milestone
        (proposal-id uint)
        (milestone-id uint)
        (vote-for bool)
    )
    (let (
            (milestone (unwrap! (get-milestone proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
            (funder-info (unwrap! (get-funder-info tx-sender proposal-id) ERR-NOT-AUTHORIZED))
            (voting-power (get amount funder-info))
        )
        (asserts! (not (has-voted tx-sender proposal-id milestone-id))
            ERR-ALREADY-VOTED
        )
        (asserts! (< stacks-block-height (get voting-deadline milestone))
            ERR-VOTING-CLOSED
        )
        (asserts! (is-eq (get status milestone) "PENDING") ERR-INVALID-STATUS)
        (map-set MilestoneVotes {
            voter: tx-sender,
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        } {
            vote: vote-for,
            voting-power: voting-power,
        })
        (map-set Milestones {
            proposal-id: proposal-id,
            milestone-id: milestone-id,
        }
            (merge milestone {
                votes-for: (if vote-for
                    (+ (get votes-for milestone) voting-power)
                    (get votes-for milestone)
                ),
                votes-against: (if vote-for
                    (get votes-against milestone)
                    (+ (get votes-against milestone) voting-power)
                ),
            })
        )
        (ok true)
    )
)

(define-public (execute-milestone
        (proposal-id uint)
        (milestone-id uint)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (milestone (unwrap! (get-milestone proposal-id milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
        )
        (asserts! (>= stacks-block-height (get voting-deadline milestone))
            ERR-VOTING-CLOSED
        )
        (asserts! (is-eq (get status milestone) "PENDING") ERR-INVALID-STATUS)
        (asserts! (> (get votes-for milestone) (get votes-against milestone))
            ERR-INSUFFICIENT-VOTES
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
                completed-at: stacks-block-height,
            })
        )
        (update-researcher-funding (get researcher proposal)
            (get funding-amount milestone)
        )
        (ok true)
    )
)

(define-public (complete-project (proposal-id uint))
    (let ((proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { status: "COMPLETED" })
        )
        (update-researcher-completion (get researcher proposal))
        (ok true)
    )
)

(define-public (withdraw-unused-funds (proposal-id uint))
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (funder-info (unwrap! (get-funder-info tx-sender proposal-id) ERR-NOT-A-FUNDER))
        )
        (asserts!
            (or
                (is-eq (get status proposal) "COMPLETED")
                (is-eq (get status proposal) "CANCELLED")
            )
            ERR-INVALID-STATUS
        )
        (try! (as-contract (stx-transfer? (get amount funder-info) tx-sender tx-sender)))
        (map-delete Funders {
            funder: tx-sender,
            proposal-id: proposal-id,
        })
        (var-set total-staked (- (var-get total-staked) (get amount funder-info)))
        (ok true)
    )
)

(define-public (cancel-proposal (proposal-id uint))
    (let ((proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get current-funding proposal) u0) ERR-INVALID-STATUS)
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-INVALID-STATUS)
        (map-set Proposals { proposal-id: proposal-id }
            (merge proposal { status: "CANCELLED" })
        )
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

(define-public (register-publication
        (proposal-id uint)
        (doi (string-ascii 100))
        (title (string-ascii 200))
        (journal (string-ascii 100))
        (publication-date uint)
        (impact-score uint)
    )
    (let (
            (publication-id (+ (var-get publication-count) u1))
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get researcher proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "COMPLETED") ERR-INVALID-STATUS)
        (asserts! (> (len doi) u0) ERR-INVALID-AMOUNT)
        (asserts! (> (len title) u0) ERR-INVALID-AMOUNT)
        (asserts! (> publication-date u0) ERR-INVALID-AMOUNT)
        (map-set Publications { publication-id: publication-id } {
            researcher: tx-sender,
            proposal-id: proposal-id,
            doi: doi,
            title: title,
            journal: journal,
            publication-date: publication-date,
            verified: false,
            verifier: none,
            impact-score: impact-score,
            created-at: stacks-block-height,
        })
        (var-set publication-count publication-id)
        (ok publication-id)
    )
)

(define-public (verify-publication
        (publication-id uint)
        (verified bool)
    )
    (let ((publication (unwrap! (get-publication publication-id) ERR-PUBLICATION-NOT-FOUND)))
        (asserts!
            (is-some (get-funder-info tx-sender (get proposal-id publication)))
            ERR-NOT-A-FUNDER
        )
        (asserts! (not (has-verified-publication tx-sender publication-id))
            ERR-ALREADY-VOTED
        )
        (map-set PublicationVerifications {
            verifier: tx-sender,
            publication-id: publication-id,
        } { verified: verified }
        )
        (if verified
            (map-set Publications { publication-id: publication-id }
                (merge publication {
                    verified: true,
                    verifier: (some tx-sender),
                })
            )
            true
        )
        (ok true)
    )
)

(define-public (claim-staking-rewards (proposal-id uint))
    (let (
            (funder-info (unwrap! (get-funder-info tx-sender proposal-id) ERR-NOT-A-FUNDER))
            (reward-info (default-to {
                accumulated-rewards: u0,
                last-claim-block: u0,
                staking-multiplier: u100,
                claimed: false,
            }
                (get-staking-rewards tx-sender proposal-id)
            ))
            (total-rewards (unwrap! (get-total-claimable-rewards tx-sender proposal-id)
                ERR-NO-REWARDS-AVAILABLE
            ))
        )
        (asserts! (not (get claimed reward-info)) ERR-REWARDS-ALREADY-CLAIMED)
        (asserts! (> total-rewards u0) ERR-NO-REWARDS-AVAILABLE)
        (asserts! (<= total-rewards (var-get reward-pool)) ERR-INSUFFICIENT-FUNDS)
        (try! (as-contract (stx-transfer? total-rewards tx-sender tx-sender)))
        (map-set StakingRewards {
            funder: tx-sender,
            proposal-id: proposal-id,
        } {
            accumulated-rewards: u0,
            last-claim-block: stacks-block-height,
            staking-multiplier: (get staking-multiplier reward-info),
            claimed: true,
        })
        (var-set reward-pool (- (var-get reward-pool) total-rewards))
        (ok total-rewards)
    )
)

(define-public (update-staking-multiplier (proposal-id uint))
    (let (
            (funder-info (unwrap! (get-funder-info tx-sender proposal-id) ERR-NOT-A-FUNDER))
            (reward-info (default-to {
                accumulated-rewards: u0,
                last-claim-block: u0,
                staking-multiplier: u100,
                claimed: false,
            }
                (get-staking-rewards tx-sender proposal-id)
            ))
            (blocks-since-funding (- stacks-block-height (get funded-at funder-info)))
            (new-multiplier (+ u100 (/ blocks-since-funding u1000)))
        )
        (map-set StakingRewards {
            funder: tx-sender,
            proposal-id: proposal-id,
        }
            (merge reward-info { staking-multiplier: new-multiplier })
        )
        (ok new-multiplier)
    )
)

(define-public (fund-reward-pool (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set reward-pool (+ (var-get reward-pool) amount))
        (ok true)
    )
)

(define-public (create-dispute
        (proposal-id uint)
        (milestone-id (optional uint))
        (dispute-type (string-ascii 50))
        (reason (string-ascii 300))
        (evidence (string-ascii 500))
    )
    (let (
            (dispute-id (+ (var-get dispute-count) u1))
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
        )
        (asserts! (is-some (get-funder-info tx-sender proposal-id))
            ERR-NOT-A-FUNDER
        )
        (asserts! (> (len reason) u0) ERR-INVALID-AMOUNT)
        (asserts! (> (len dispute-type) u0) ERR-INVALID-AMOUNT)
        (map-set Disputes { dispute-id: dispute-id } {
            disputer: tx-sender,
            proposal-id: proposal-id,
            milestone-id: milestone-id,
            dispute-type: dispute-type,
            reason: reason,
            evidence: evidence,
            status: "ACTIVE",
            votes-for: u0,
            votes-against: u0,
            voting-deadline: (+ stacks-block-height (var-get dispute-voting-period)),
            resolution: "",
            created-at: stacks-block-height,
            resolved-at: none,
        })
        (var-set dispute-count dispute-id)
        (ok dispute-id)
    )
)

(define-public (vote-on-dispute
        (dispute-id uint)
        (vote-for bool)
    )
    (let (
            (dispute (unwrap! (get-dispute dispute-id) ERR-DISPUTE-NOT-FOUND))
            (total-voting-power (var-get total-staked))
            (voter-power (/ total-voting-power u100))
        )
        (asserts! (not (has-voted-on-dispute tx-sender dispute-id))
            ERR-ALREADY-VOTED
        )
        (asserts! (< stacks-block-height (get voting-deadline dispute))
            ERR-VOTING-CLOSED
        )
        (asserts! (is-eq (get status dispute) "ACTIVE") ERR-INVALID-STATUS)
        (map-set DisputeVotes {
            voter: tx-sender,
            dispute-id: dispute-id,
        } {
            vote: vote-for,
            voting-power: voter-power,
        })
        (map-set Disputes { dispute-id: dispute-id }
            (merge dispute {
                votes-for: (if vote-for
                    (+ (get votes-for dispute) voter-power)
                    (get votes-for dispute)
                ),
                votes-against: (if vote-for
                    (get votes-against dispute)
                    (+ (get votes-against dispute) voter-power)
                ),
            })
        )
        (ok true)
    )
)

(define-public (resolve-dispute
        (dispute-id uint)
        (resolution (string-ascii 200))
    )
    (let (
            (dispute (unwrap! (get-dispute dispute-id) ERR-DISPUTE-NOT-FOUND))
            (proposal (unwrap! (get-proposal (get proposal-id dispute))
                ERR-PROPOSAL-NOT-FOUND
            ))
        )
        (asserts! (>= stacks-block-height (get voting-deadline dispute))
            ERR-VOTING-CLOSED
        )
        (asserts! (is-eq (get status dispute) "ACTIVE") ERR-INVALID-STATUS)
        (asserts!
            (or
                (is-eq tx-sender (var-get dao-admin))
                (> (get votes-for dispute) (get votes-against dispute))
            )
            ERR-NOT-AUTHORIZED
        )
        (map-set Disputes { dispute-id: dispute-id }
            (merge dispute {
                status: "RESOLVED",
                resolution: resolution,
                resolved-at: (some stacks-block-height),
            })
        )
        (if (> (get votes-for dispute) (get votes-against dispute))
            (execute-dispute-resolution dispute)
            true
        )
        (ok true)
    )
)

(define-private (execute-dispute-resolution (dispute {
    disputer: principal,
    proposal-id: uint,
    milestone-id: (optional uint),
    dispute-type: (string-ascii 50),
    reason: (string-ascii 300),
    evidence: (string-ascii 500),
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    resolution: (string-ascii 200),
    created-at: uint,
    resolved-at: (optional uint),
}))
    (let ((proposal (unwrap-panic (get-proposal (get proposal-id dispute)))))
        (if (is-eq (get dispute-type dispute) "PROJECT_ABANDONMENT")
            (map-set Proposals { proposal-id: (get proposal-id dispute) }
                (merge proposal { status: "CANCELLED" })
            )
            true
        )
    )
)

(define-private (initialize-staking-rewards
        (funder principal)
        (proposal-id uint)
        (amount uint)
    )
    (let ((existing-rewards (get-staking-rewards funder proposal-id)))
        (if (is-none existing-rewards)
            (map-set StakingRewards {
                funder: funder,
                proposal-id: proposal-id,
            } {
                accumulated-rewards: u0,
                last-claim-block: stacks-block-height,
                staking-multiplier: u100,
                claimed: false,
            })
            true
        )
    )
)

(define-private (update-researcher-stats (researcher principal))
    (let ((profile (default-to {
            total-proposals: u0,
            completed-projects: u0,
            total-funding-received: u0,
            reputation-score: u0,
            joined-at: stacks-block-height,
        }
            (get-researcher-profile researcher)
        )))
        (map-set ResearcherProfile { researcher: researcher }
            (merge profile { total-proposals: (+ (get total-proposals profile) u1) })
        )
    )
)

(define-private (update-researcher-funding
        (researcher principal)
        (amount uint)
    )
    (let ((profile (unwrap-panic (get-researcher-profile researcher))))
        (map-set ResearcherProfile { researcher: researcher }
            (merge profile {
                total-funding-received: (+ (get total-funding-received profile) amount),
                reputation-score: (calculate-reputation-score (get completed-projects profile)
                    (get total-proposals profile)
                ),
            })
        )
    )
)

(define-private (update-researcher-completion (researcher principal))
    (let ((profile (unwrap-panic (get-researcher-profile researcher))))
        (map-set ResearcherProfile { researcher: researcher }
            (merge profile {
                completed-projects: (+ (get completed-projects profile) u1),
                reputation-score: (calculate-reputation-score
                    (+ (get completed-projects profile) u1)
                    (get total-proposals profile)
                ),
            })
        )
    )
)

(define-private (calculate-reputation-score
        (completed uint)
        (total uint)
    )
    (if (is-eq total u0)
        u0
        (/ (* completed u100) total)
    )
)
