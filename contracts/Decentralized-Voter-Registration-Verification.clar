(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_ELECTION_NOT_FOUND (err u103))
(define-constant ERR_ELECTION_ACTIVE (err u104))
(define-constant ERR_REGISTRATION_CLOSED (err u105))
(define-constant ERR_ALREADY_VERIFIED (err u106))
(define-constant ERR_INVALID_PROOF (err u107))

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
