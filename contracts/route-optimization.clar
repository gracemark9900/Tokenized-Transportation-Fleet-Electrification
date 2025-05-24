;; Route Optimization Contract
;; Plans and manages efficient electric vehicle routes

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-route-not-found (err u401))
(define-constant err-unauthorized (err u402))
(define-constant err-invalid-route (err u403))

;; Data structures
(define-map optimized-routes uint {
    fleet-operator: principal,
    vehicle-vin: (string-ascii 20),
    start-location: (string-ascii 100),
    end-location: (string-ascii 100),
    distance-km: uint,
    estimated-energy: uint,
    charging-stops: uint,
    route-efficiency: uint,
    created-at: uint
})

(define-map route-performance uint {
    actual-distance: uint,
    actual-energy: uint,
    actual-time: uint,
    efficiency-score: uint,
    completed-at: uint
})

(define-data-var route-counter uint u0)

;; Public functions
(define-public (create-route
    (fleet-operator principal)
    (vehicle-vin (string-ascii 20))
    (start-location (string-ascii 100))
    (end-location (string-ascii 100))
    (distance-km uint)
    (estimated-energy uint)
    (charging-stops uint))
    (let ((route-id (var-get route-counter))
          (efficiency (if (> distance-km u0) (/ (* estimated-energy u100) distance-km) u0)))
        (map-set optimized-routes route-id {
            fleet-operator: fleet-operator,
            vehicle-vin: vehicle-vin,
            start-location: start-location,
            end-location: end-location,
            distance-km: distance-km,
            estimated-energy: estimated-energy,
            charging-stops: charging-stops,
            route-efficiency: efficiency,
            created-at: block-height
        })
        (var-set route-counter (+ route-id u1))
        (ok route-id)
    )
)

(define-public (complete-route
    (route-id uint)
    (actual-distance uint)
    (actual-energy uint)
    (actual-time uint))
    (let ((route (unwrap! (map-get? optimized-routes route-id) err-route-not-found))
          (efficiency-score (if (> actual-distance u0) (/ (* actual-energy u100) actual-distance) u0)))
        (asserts! (is-eq tx-sender (get fleet-operator route)) err-unauthorized)
        (map-set route-performance route-id {
            actual-distance: actual-distance,
            actual-energy: actual-energy,
            actual-time: actual-time,
            efficiency-score: efficiency-score,
            completed-at: block-height
        })
        (ok true)
    )
)

(define-public (update-route-efficiency (route-id uint) (new-efficiency uint))
    (let ((route (unwrap! (map-get? optimized-routes route-id) err-route-not-found)))
        (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get fleet-operator route))) err-unauthorized)
        (map-set optimized-routes route-id (merge route {route-efficiency: new-efficiency}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-route-info (route-id uint))
    (map-get? optimized-routes route-id)
)

(define-read-only (get-route-performance (route-id uint))
    (map-get? route-performance route-id)
)

(define-read-only (get-total-routes)
    (var-get route-counter)
)

(define-read-only (calculate-route-savings (route-id uint))
    (match (map-get? route-performance route-id)
        performance (let ((route (unwrap-panic (map-get? optimized-routes route-id))))
            (if (> (get estimated-energy route) (get actual-energy performance))
                (some (- (get estimated-energy route) (get actual-energy performance)))
                (some u0)))
        none
    )
)
