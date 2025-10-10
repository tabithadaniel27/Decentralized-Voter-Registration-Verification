(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_ELECTION_NOT_FOUND (err u103))
(define-constant ERR_ELECTION_ACTIVE (err u104))
(define-constant ERR_REGISTRATION_CLOSED (err u105))
(define-constant ERR_ALREADY_VERIFIED (err u106))
(define-constant ERR_INVALID_PROOF (err u107))

(define-constant ERR_DELEGATION_EXISTS (err u200))
(define-constant ERR_DELEGATION_NOT_FOUND (err u201))
(define-constant ERR_DELEGATION_EXPIRED (err u202))
(define-constant ERR_INVALID_DELEGATE (err u203))
(define-constant ERR_SELF_DELEGATION (err u204))

(define-constant ERR_VERIFIER_NOT_AUTHORIZED (err u300))
(define-constant ERR_VERIFIER_ALREADY_EXISTS (err u301))
(define-constant ERR_VERIFICATION_REQUEST_NOT_FOUND (err u302))
(define-constant ERR_THRESHOLD_NOT_MET (err u303))
(define-constant ERR_ALREADY_SIGNED (err u304))
(define-constant ERR_VERIFICATION_ALREADY_COMPLETE (err u305))

(define-map voters 
  { voter-id: (buff 32) }
  { 
    identity-hash: (buff 32),
    verified: bool,
    registration-block: uint,
    verification-block: (optional uint)
  }
)

(define-map elections
  { election-id: uint }
  {
    name: (string-ascii 50),
    start-block: uint,
    end-block: uint,
    registration-end: uint,
    total-registered: uint,
    admin: principal
  }
)

(define-map voter-eligibility
  { voter-id: (buff 32), election-id: uint }
  { eligible: bool }
)

(define-data-var election-counter uint u0)
(define-data-var total-voters uint u0)

(define-public (register-voter (voter-id (buff 32)) (identity-hash (buff 32)))
  (let 
    (
      (current-block stacks-block-height)
      (existing-voter (map-get? voters { voter-id: voter-id }))
    )
    (asserts! (is-none existing-voter) ERR_ALREADY_REGISTERED)
    (map-set voters 
      { voter-id: voter-id }
      {
        identity-hash: identity-hash,
        verified: false,
        registration-block: current-block,
        verification-block: none
      }
    )
    (var-set total-voters (+ (var-get total-voters) u1))
    (ok true)
  )
)

(define-public (verify-voter (voter-id (buff 32)) (verification-proof (buff 32)))
  (let 
    (
      (voter-data (unwrap! (map-get? voters { voter-id: voter-id }) ERR_NOT_REGISTERED))
      (current-block stacks-block-height)
    )
    (asserts! (not (get verified voter-data)) ERR_ALREADY_VERIFIED)
    (asserts! (is-eq (get identity-hash voter-data) verification-proof) ERR_INVALID_PROOF)
    (map-set voters
      { voter-id: voter-id }
      (merge voter-data { 
        verified: true,
        verification-block: (some current-block)
      })
    )
    (ok true)
  )
)

(define-public (create-election (name (string-ascii 50)) (duration uint) (registration-period uint))
  (let 
    (
      (election-id (+ (var-get election-counter) u1))
      (current-block stacks-block-height)
      (registration-end (+ current-block registration-period))
      (election-end (+ registration-end duration))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set elections
      { election-id: election-id }
      {
        name: name,
        start-block: registration-end,
        end-block: election-end,
        registration-end: registration-end,
        total-registered: u0,
        admin: tx-sender
      }
    )
    (var-set election-counter election-id)
    (ok election-id)
  )
)

(define-public (register-for-election (voter-id (buff 32)) (election-id uint))
  (let 
    (
      (voter-data (unwrap! (map-get? voters { voter-id: voter-id }) ERR_NOT_REGISTERED))
      (election-data (unwrap! (map-get? elections { election-id: election-id }) ERR_ELECTION_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (get verified voter-data) ERR_UNAUTHORIZED)
    (asserts! (< current-block (get registration-end election-data)) ERR_REGISTRATION_CLOSED)
    (map-set voter-eligibility
      { voter-id: voter-id, election-id: election-id }
      { eligible: true }
    )
    (map-set elections
      { election-id: election-id }
      (merge election-data { 
        total-registered: (+ (get total-registered election-data) u1)
      })
    )
    (ok true)
  )
)

(define-public (revoke-voter-eligibility (voter-id (buff 32)) (election-id uint))
  (let 
    (
      (election-data (unwrap! (map-get? elections { election-id: election-id }) ERR_ELECTION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get admin election-data)) ERR_UNAUTHORIZED)
    (map-set voter-eligibility
      { voter-id: voter-id, election-id: election-id }
      { eligible: false }
    )
    (ok true)
  )
)

(define-read-only (get-voter-info (voter-id (buff 32)))
  (map-get? voters { voter-id: voter-id })
)

(define-read-only (get-election-info (election-id uint))
  (map-get? elections { election-id: election-id })
)

(define-read-only (is-voter-eligible (voter-id (buff 32)) (election-id uint))
  (default-to 
    { eligible: false }
    (map-get? voter-eligibility { voter-id: voter-id, election-id: election-id })
  )
)

(define-read-only (verify-voter-identity (voter-id (buff 32)) (claimed-hash (buff 32)))
  (match (map-get? voters { voter-id: voter-id })
    voter-data (is-eq (get identity-hash voter-data) claimed-hash)
    false
  )
)

(define-read-only (get-election-status (election-id uint))
  (let 
    (
      (election-data (unwrap! (map-get? elections { election-id: election-id }) (err "Election not found")))
      (current-block stacks-block-height)
    )
    (if (< current-block (get registration-end election-data))
      (ok "registration")
      (if (< current-block (get end-block election-data))
        (ok "active")
        (ok "ended")
      )
    )
  )
)

(define-read-only (get-total-voters)
  (var-get total-voters)
)

(define-read-only (get-total-elections)
  (var-get election-counter)
)

(define-read-only (get-voter-verification-block (voter-id (buff 32)))
  (match (map-get? voters { voter-id: voter-id })
    voter-data (get verification-block voter-data)
    none
  )
)


(define-map voter-delegations
  { delegator: (buff 32) }
  { 
    delegate: (buff 32),
    delegation-proof: (buff 32),
    expiry-block: uint,
    created-block: uint,
    active: bool
  }
)

(define-map delegation-authorizations
  { delegate: (buff 32), delegator: (buff 32) }
  { authorized: bool, authorization-block: uint }
)

(define-data-var total-delegations uint u0)

(define-public (create-delegation (delegator-id (buff 32)) (delegate-id (buff 32)) 
                                 (delegation-proof (buff 32)) (duration uint))
  (let 
    (
      (delegator-data (unwrap! (map-get? voters { voter-id: delegator-id }) ERR_NOT_REGISTERED))
      (delegate-data (unwrap! (map-get? voters { voter-id: delegate-id }) ERR_NOT_REGISTERED))
      (current-block stacks-block-height)
      (expiry-block (+ current-block duration))
      (existing-delegation (map-get? voter-delegations { delegator: delegator-id }))
    )
    (asserts! (get verified delegator-data) ERR_UNAUTHORIZED)
    (asserts! (get verified delegate-data) ERR_INVALID_DELEGATE)
    (asserts! (not (is-eq delegator-id delegate-id)) ERR_SELF_DELEGATION)
    (asserts! (is-none existing-delegation) ERR_DELEGATION_EXISTS)
    (map-set voter-delegations
      { delegator: delegator-id }
      {
        delegate: delegate-id,
        delegation-proof: delegation-proof,
        expiry-block: expiry-block,
        created-block: current-block,
        active: true
      }
    )
    (map-set delegation-authorizations
      { delegate: delegate-id, delegator: delegator-id }
      { authorized: true, authorization-block: current-block }
    )
    (var-set total-delegations (+ (var-get total-delegations) u1))
    (ok true)
  )
)

(define-public (revoke-delegation (delegator-id (buff 32)))
  (let 
    (
      (delegation-data (unwrap! (map-get? voter-delegations { delegator: delegator-id }) ERR_DELEGATION_NOT_FOUND))
    )
    (map-set voter-delegations
      { delegator: delegator-id }
      (merge delegation-data { active: false })
    )
    (map-delete delegation-authorizations
      { delegate: (get delegate delegation-data), delegator: delegator-id }
    )
    (ok true)
  )
)

(define-read-only (get-delegation-info (delegator-id (buff 32)))
  (map-get? voter-delegations { delegator: delegator-id })
)

(define-read-only (is-delegation-valid (delegator-id (buff 32)))
  (match (map-get? voter-delegations { delegator: delegator-id })
    delegation-data 
      (and 
        (get active delegation-data)
        (< stacks-block-height (get expiry-block delegation-data))
      )
    false
  )
)

(define-read-only (verify-delegate-authorization (delegate-id (buff 32)) (delegator-id (buff 32)))
  (default-to 
    { authorized: false, authorization-block: u0 }
    (map-get? delegation-authorizations { delegate: delegate-id, delegator: delegator-id })
  )
)

(define-read-only (get-total-delegations)
  (var-get total-delegations)
)

(define-map participation-metrics
  { election-id: uint }
  {
    total-registrations: uint,
    peak-registration-block: uint,
    peak-registration-count: uint,
    average-registration-rate: uint,
    participation-score: uint
  }
)

(define-map time-period-analytics
  { period-start: uint, period-end: uint }
  {
    total-elections: uint,
    total-participants: uint,
    average-participation-rate: uint,
    peak-activity-block: uint
  }
)

(define-data-var analytics-enabled bool true)
(define-data-var total-participation-events uint u0)

(define-public (record-participation-event (election-id uint))
  (let
    (
      (election-data (unwrap! (map-get? elections { election-id: election-id }) ERR_ELECTION_NOT_FOUND))
      (current-metrics (default-to 
        { total-registrations: u0, peak-registration-block: u0, peak-registration-count: u0, 
          average-registration-rate: u0, participation-score: u0 }
        (map-get? participation-metrics { election-id: election-id })))
      (current-block stacks-block-height)
      (new-total (+ (get total-registrations current-metrics) u1))
      (is-peak (> new-total (get peak-registration-count current-metrics)))
    )
    (asserts! (var-get analytics-enabled) (ok true))
    (map-set participation-metrics
      { election-id: election-id }
      {
        total-registrations: new-total,
        peak-registration-block: (if is-peak current-block (get peak-registration-block current-metrics)),
        peak-registration-count: (if is-peak new-total (get peak-registration-count current-metrics)),
        average-registration-rate: (/ new-total (- current-block (get start-block election-data))),
        participation-score: (/ (* new-total u100) (get total-registered election-data))
      }
    )
    (var-set total-participation-events (+ (var-get total-participation-events) u1))
    (ok true)
  )
)

(define-public (update-period-analytics (period-start uint) (period-end uint))
  (let
    (
      (existing-analytics (default-to 
        { total-elections: u0, total-participants: u0, average-participation-rate: u0, peak-activity-block: u0 }
        (map-get? time-period-analytics { period-start: period-start, period-end: period-end })))
      (new-participants (+ (get total-participants existing-analytics) u1))
    )
    (asserts! (var-get analytics-enabled) (ok true))
    (map-set time-period-analytics
      { period-start: period-start, period-end: period-end }
      (merge existing-analytics {
        total-participants: new-participants,
        average-participation-rate: (/ new-participants (- period-end period-start))
      })
    )
    (ok true)
  )
)

(define-read-only (get-participation-metrics (election-id uint))
  (map-get? participation-metrics { election-id: election-id })
)

(define-read-only (get-period-analytics (period-start uint) (period-end uint))
  (map-get? time-period-analytics { period-start: period-start, period-end: period-end })
)

(define-read-only (calculate-engagement-ratio (election-id uint))
  (match (map-get? participation-metrics { election-id: election-id })
    metrics (/ (* (get participation-score metrics) u100) u100)
    u0
  )
)

(define-read-only (get-total-participation-events)
  (var-get total-participation-events)
)


(define-map authorized-verifiers
  { verifier: principal }
  { verifier-key: (buff 33), authorized: bool, authorization-block: uint }
)

(define-map verification-requests
  { request-id: uint }
  { 
    voter-id: (buff 32),
    required-signatures: uint,
    current-signatures: uint,
    verification-hash: (buff 32),
    completed: bool,
    request-block: uint
  }
)

(define-map verifier-signatures
  { request-id: uint, verifier: principal }
  { signature-hash: (buff 32), signature-block: uint }
)

(define-data-var request-counter uint u0)
(define-data-var total-verifiers uint u0)

(define-public (authorize-verifier (verifier principal) (verifier-key (buff 33)))
  (let
    (
      (current-block stacks-block-height)
      (existing-verifier (map-get? authorized-verifiers { verifier: verifier }))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none existing-verifier) ERR_VERIFIER_ALREADY_EXISTS)
    (map-set authorized-verifiers
      { verifier: verifier }
      { verifier-key: verifier-key, authorized: true, authorization-block: current-block }
    )
    (var-set total-verifiers (+ (var-get total-verifiers) u1))
    (ok true)
  )
)

(define-public (create-multisig-verification-request (voter-id (buff 32)) (verification-hash (buff 32)) (required-sigs uint))
  (let
    (
      (voter-data (unwrap! (map-get? voters { voter-id: voter-id }) ERR_NOT_REGISTERED))
      (request-id (+ (var-get request-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (not (get verified voter-data)) ERR_ALREADY_VERIFIED)
    (map-set verification-requests
      { request-id: request-id }
      {
        voter-id: voter-id,
        required-signatures: required-sigs,
        current-signatures: u0,
        verification-hash: verification-hash,
        completed: false,
        request-block: current-block
      }
    )
    (var-set request-counter request-id)
    (ok request-id)
  )
)

(define-public (submit-verifier-signature (request-id uint) (signature-hash (buff 32)))
  (let
    (
      (verifier-data (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_AUTHORIZED))
      (request-data (unwrap! (map-get? verification-requests { request-id: request-id }) ERR_VERIFICATION_REQUEST_NOT_FOUND))
      (existing-signature (map-get? verifier-signatures { request-id: request-id, verifier: tx-sender }))
      (current-block stacks-block-height)
      (new-sig-count (+ (get current-signatures request-data) u1))
      (threshold-met (>= new-sig-count (get required-signatures request-data)))
    )
    (asserts! (get authorized verifier-data) ERR_VERIFIER_NOT_AUTHORIZED)
    (asserts! (is-none existing-signature) ERR_ALREADY_SIGNED)
    (asserts! (not (get completed request-data)) ERR_VERIFICATION_ALREADY_COMPLETE)
    (map-set verifier-signatures
      { request-id: request-id, verifier: tx-sender }
      { signature-hash: signature-hash, signature-block: current-block }
    )
    (map-set verification-requests
      { request-id: request-id }
      (merge request-data { 
        current-signatures: new-sig-count,
        completed: threshold-met
      })
    )
    (if threshold-met
      (map-set voters
        { voter-id: (get voter-id request-data) }
        (merge (unwrap-panic (map-get? voters { voter-id: (get voter-id request-data) }))
          { verified: true, verification-block: (some current-block) }
        )
      )
      true
    )
    (ok threshold-met)
  )
)

(define-read-only (get-verifier-info (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)

(define-read-only (get-verification-request (request-id uint))
  (map-get? verification-requests { request-id: request-id })
)

(define-read-only (get-verifier-signature (request-id uint) (verifier principal))
  (map-get? verifier-signatures { request-id: request-id, verifier: verifier })
)

(define-read-only (is-verification-complete (request-id uint))
  (match (map-get? verification-requests { request-id: request-id })
    request-data (get completed request-data)
    false
  )
)

(define-read-only (get-total-verifiers)
  (var-get total-verifiers)
)