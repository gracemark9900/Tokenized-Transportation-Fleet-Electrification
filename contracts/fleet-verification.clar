;; Fleet Verification Contract
;; Validates and manages transportation operators

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-verified (err u101))
(define-constant err-not-verified (err u102))
(define-constant err-invalid-operator (err u103))

;; Data structures
(define-map verified-fleets principal {
    name: (string-ascii 50),
    license-number: (string-ascii 20),
    vehicle-count: uint,
    verified-at: uint,
    status: (string-ascii 10)
})

(define-map fleet-stats principal {
    total-vehicles: uint,
    electric-vehicles: uint,
    verification-score: uint
})

;; Public functions
(define-public (verify-fleet (operator principal) (name (string-ascii 50)) (license (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? verified-fleets operator)) err-already-verified)
        (map-set verified-fleets operator {
            name: name,
            license-number: license,
            vehicle-count: u0,
            verified-at: block-height,
            status: "active"
        })
        (ok true)
    )
)

(define-public (update-fleet-status (operator principal) (status (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? verified-fleets operator)) err-not-verified)
        (map-set verified-fleets operator
            (merge (unwrap-panic (map-get? verified-fleets operator)) {status: status}))
        (ok true)
    )
)

(define-public (update-vehicle-count (operator principal) (count uint))
    (begin
        (asserts! (is-some (map-get? verified-fleets operator)) err-not-verified)
        (map-set verified-fleets operator
            (merge (unwrap-panic (map-get? verified-fleets operator)) {vehicle-count: count}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-fleet-info (operator principal))
    (map-get? verified-fleets operator)
)

(define-read-only (is-verified-fleet (operator principal))
    (is-some (map-get? verified-fleets operator))
)

(define-read-only (get-fleet-stats (operator principal))
    (map-get? fleet-stats operator)
)
