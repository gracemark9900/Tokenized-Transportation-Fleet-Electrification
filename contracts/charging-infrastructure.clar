;; Charging Infrastructure Contract
;; Manages charging stations and their operations

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-station-exists (err u301))
(define-constant err-station-not-found (err u302))
(define-constant err-station-offline (err u303))
(define-constant err-insufficient-capacity (err u304))

;; Data structures
(define-map charging-stations (string-ascii 20) {
    operator: principal,
    location: (string-ascii 100),
    power-rating: uint,
    connector-type: (string-ascii 20),
    price-per-kwh: uint,
    status: (string-ascii 15),
    installation-date: uint
})

(define-map station-usage (string-ascii 20) {
    total-sessions: uint,
    total-energy-delivered: uint,
    revenue-generated: uint,
    uptime-percentage: uint
})

(define-map charging-sessions {station-id: (string-ascii 20), session-id: uint} {
    vehicle-vin: (string-ascii 20),
    start-time: uint,
    end-time: uint,
    energy-delivered: uint,
    cost: uint
})

(define-data-var session-counter uint u0)

;; Public functions
(define-public (register-station
    (station-id (string-ascii 20))
    (operator principal)
    (location (string-ascii 100))
    (power-rating uint)
    (connector-type (string-ascii 20))
    (price-per-kwh uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? charging-stations station-id)) err-station-exists)
        (map-set charging-stations station-id {
            operator: operator,
            location: location,
            power-rating: power-rating,
            connector-type: connector-type,
            price-per-kwh: price-per-kwh,
            status: "online",
            installation-date: block-height
        })
        (map-set station-usage station-id {
            total-sessions: u0,
            total-energy-delivered: u0,
            revenue-generated: u0,
            uptime-percentage: u100
        })
        (ok true)
    )
)

(define-public (start-charging-session
    (station-id (string-ascii 20))
    (vehicle-vin (string-ascii 20)))
    (let ((station (unwrap! (map-get? charging-stations station-id) err-station-not-found))
          (session-id (var-get session-counter)))
        (asserts! (is-eq (get status station) "online") err-station-offline)
        (map-set charging-sessions {station-id: station-id, session-id: session-id} {
            vehicle-vin: vehicle-vin,
            start-time: block-height,
            end-time: u0,
            energy-delivered: u0,
            cost: u0
        })
        (var-set session-counter (+ session-id u1))
        (ok session-id)
    )
)

(define-public (end-charging-session
    (station-id (string-ascii 20))
    (session-id uint)
    (energy-delivered uint))
    (let ((station (unwrap! (map-get? charging-stations station-id) err-station-not-found))
          (session (unwrap! (map-get? charging-sessions {station-id: station-id, session-id: session-id}) err-station-not-found))
          (cost (* energy-delivered (get price-per-kwh station))))
        (map-set charging-sessions {station-id: station-id, session-id: session-id}
            (merge session {
                end-time: block-height,
                energy-delivered: energy-delivered,
                cost: cost
            }))
        (let ((usage (unwrap-panic (map-get? station-usage station-id))))
            (map-set station-usage station-id {
                total-sessions: (+ (get total-sessions usage) u1),
                total-energy-delivered: (+ (get total-energy-delivered usage) energy-delivered),
                revenue-generated: (+ (get revenue-generated usage) cost),
                uptime-percentage: (get uptime-percentage usage)
            }))
        (ok cost)
    )
)

;; Read-only functions
(define-read-only (get-station-info (station-id (string-ascii 20)))
    (map-get? charging-stations station-id)
)

(define-read-only (get-station-usage (station-id (string-ascii 20)))
    (map-get? station-usage station-id)
)

(define-read-only (get-charging-session (station-id (string-ascii 20)) (session-id uint))
    (map-get? charging-sessions {station-id: station-id, session-id: session-id})
)
