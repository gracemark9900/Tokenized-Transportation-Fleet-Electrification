;; Vehicle Registration Contract
;; Records and manages electric vehicles in the fleet

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-vehicle-exists (err u201))
(define-constant err-vehicle-not-found (err u202))
(define-constant err-unauthorized (err u203))

;; Data structures
(define-map registered-vehicles (string-ascii 20) {
    owner: principal,
    make: (string-ascii 30),
    model: (string-ascii 30),
    year: uint,
    battery-capacity: uint,
    range-km: uint,
    registration-date: uint,
    status: (string-ascii 15)
})

(define-map vehicle-metrics (string-ascii 20) {
    total-distance: uint,
    energy-consumed: uint,
    charging-sessions: uint,
    last-service: uint
})

(define-data-var total-registered-vehicles uint u0)

;; Public functions
(define-public (register-vehicle
    (vin (string-ascii 20))
    (owner principal)
    (make (string-ascii 30))
    (model (string-ascii 30))
    (year uint)
    (battery-capacity uint)
    (range-km uint))
    (begin
        (asserts! (is-none (map-get? registered-vehicles vin)) err-vehicle-exists)
        (map-set registered-vehicles vin {
            owner: owner,
            make: make,
            model: model,
            year: year,
            battery-capacity: battery-capacity,
            range-km: range-km,
            registration-date: block-height,
            status: "active"
        })
        (map-set vehicle-metrics vin {
            total-distance: u0,
            energy-consumed: u0,
            charging-sessions: u0,
            last-service: u0
        })
        (var-set total-registered-vehicles (+ (var-get total-registered-vehicles) u1))
        (ok true)
    )
)

(define-public (update-vehicle-status (vin (string-ascii 20)) (status (string-ascii 15)))
    (let ((vehicle (unwrap! (map-get? registered-vehicles vin) err-vehicle-not-found)))
        (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get owner vehicle))) err-unauthorized)
        (map-set registered-vehicles vin (merge vehicle {status: status}))
        (ok true)
    )
)

(define-public (update-vehicle-metrics
    (vin (string-ascii 20))
    (distance uint)
    (energy uint)
    (charging-sessions uint))
    (let ((vehicle (unwrap! (map-get? registered-vehicles vin) err-vehicle-not-found)))
        (asserts! (is-eq tx-sender (get owner vehicle)) err-unauthorized)
        (map-set vehicle-metrics vin {
            total-distance: distance,
            energy-consumed: energy,
            charging-sessions: charging-sessions,
            last-service: block-height
        })
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-vehicle-info (vin (string-ascii 20)))
    (map-get? registered-vehicles vin)
)

(define-read-only (get-vehicle-metrics (vin (string-ascii 20)))
    (map-get? vehicle-metrics vin)
)

(define-read-only (get-total-vehicles)
    (var-get total-registered-vehicles)
)
