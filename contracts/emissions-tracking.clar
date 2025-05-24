;; Emissions Tracking Contract
;; Monitors and tracks carbon reduction from fleet electrification

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-record-not-found (err u501))
(define-constant err-unauthorized (err u502))
(define-constant err-invalid-data (err u503))

;; Constants for emissions calculations (grams CO2 per km)
(define-constant diesel-emissions-per-km u800)
(define-constant gasoline-emissions-per-km u650)
(define-constant electric-emissions-per-km u150) ;; Including grid electricity

;; Data structures
(define-map emissions-records uint {
    fleet-operator: principal,
    vehicle-vin: (string-ascii 20),
    period-start: uint,
    period-end: uint,
    distance-traveled: uint,
    fuel-type: (string-ascii 20),
    emissions-produced: uint,
    emissions-saved: uint
})

(define-map fleet-emissions-summary principal {
    total-distance: uint,
    total-emissions: uint,
    total-savings: uint,
    electric-percentage: uint,
    last-updated: uint
})

(define-data-var record-counter uint u0)
(define-data-var total-emissions-saved uint u0)

;; Public functions
(define-public (record-emissions
    (fleet-operator principal)
    (vehicle-vin (string-ascii 20))
    (period-start uint)
    (period-end uint)
    (distance-traveled uint)
    (fuel-type (string-ascii 20)))
    (let ((record-id (var-get record-counter))
          (emissions (calculate-emissions distance-traveled fuel-type))
          (baseline-emissions (* distance-traveled diesel-emissions-per-km))
          (savings (if (> baseline-emissions emissions) (- baseline-emissions emissions) u0)))
        (map-set emissions-records record-id {
            fleet-operator: fleet-operator,
            vehicle-vin: vehicle-vin,
            period-start: period-start,
            period-end: period-end,
            distance-traveled: distance-traveled,
            fuel-type: fuel-type,
            emissions-produced: emissions,
            emissions-saved: savings
        })
        (var-set record-counter (+ record-id u1))
        (var-set total-emissions-saved (+ (var-get total-emissions-saved) savings))
        (update-fleet-summary fleet-operator distance-traveled emissions savings)
        (ok record-id)
    )
)

(define-public (update-emissions-record
    (record-id uint)
    (distance-traveled uint)
    (fuel-type (string-ascii 20)))
    (let ((record (unwrap! (map-get? emissions-records record-id) err-record-not-found))
          (emissions (calculate-emissions distance-traveled fuel-type))
          (baseline-emissions (* distance-traveled diesel-emissions-per-km))
          (savings (if (> baseline-emissions emissions) (- baseline-emissions emissions) u0)))
        (asserts! (is-eq tx-sender (get fleet-operator record)) err-unauthorized)
        (map-set emissions-records record-id (merge record {
            distance-traveled: distance-traveled,
            fuel-type: fuel-type,
            emissions-produced: emissions,
            emissions-saved: savings
        }))
        (ok true)
    )
)

;; Private functions
(define-private (calculate-emissions (distance uint) (fuel-type (string-ascii 20)))
    (if (is-eq fuel-type "electric")
        (* distance electric-emissions-per-km)
        (if (is-eq fuel-type "gasoline")
            (* distance gasoline-emissions-per-km)
            (* distance diesel-emissions-per-km)
        )
    )
)

(define-private (update-fleet-summary (operator principal) (distance uint) (emissions uint) (savings uint))
    (let ((current-summary (default-to
            {total-distance: u0, total-emissions: u0, total-savings: u0, electric-percentage: u0, last-updated: u0}
            (map-get? fleet-emissions-summary operator))))
        (map-set fleet-emissions-summary operator {
            total-distance: (+ (get total-distance current-summary) distance),
            total-emissions: (+ (get total-emissions current-summary) emissions),
            total-savings: (+ (get total-savings current-summary) savings),
            electric-percentage: (get electric-percentage current-summary),
            last-updated: block-height
        })
    )
)

;; Read-only functions
(define-read-only (get-emissions-record (record-id uint))
    (map-get? emissions-records record-id)
)

(define-read-only (get-fleet-summary (operator principal))
    (map-get? fleet-emissions-summary operator)
)

(define-read-only (get-total-emissions-saved)
    (var-get total-emissions-saved)
)

(define-read-only (calculate-carbon-credits (operator principal))
    (match (map-get? fleet-emissions-summary operator)
        summary (some (/ (get total-savings summary) u1000)) ;; 1 credit per ton CO2 saved
        none
    )
)

(define-read-only (get-emissions-rate (fuel-type (string-ascii 20)))
    (if (is-eq fuel-type "electric")
        electric-emissions-per-km
        (if (is-eq fuel-type "gasoline")
            gasoline-emissions-per-km
            diesel-emissions-per-km
        )
    )
)
