;; Processing Verification Contract
;; Validates recycling operations

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-invalid-processor (err u302))
(define-constant err-unauthorized (err u303))

;; Processing status constants
(define-constant status-received u1)
(define-constant status-processing u2)
(define-constant status-completed u3)
(define-constant status-failed u4)

;; Data structures
(define-map certified-processors
  { processor: principal }
  {
    name: (string-ascii 100),
    location: (string-ascii 200),
    certification-date: uint,
    is-active: bool
  }
)

(define-map processing-records
  { processing-id: uint }
  {
    collection-id: uint,
    processor: principal,
    input-amount: uint, ;; in kg
    processing-method: (string-ascii 100),
    start-date: uint,
    end-date: (optional uint),
    status: uint,
    efficiency-rate: (optional uint), ;; percentage
    created-at: uint
  }
)

(define-map processing-counter { id: uint } { count: uint })

;; Initialize counter
(map-set processing-counter { id: u0 } { count: u0 })

;; Get next processing ID
(define-private (get-next-processing-id)
  (let ((current-count (default-to u0 (get count (map-get? processing-counter { id: u0 })))))
    (let ((next-id (+ current-count u1)))
      (map-set processing-counter { id: u0 } { count: next-id })
      next-id
    )
  )
)

;; Register a processor (admin only)
(define-public (register-processor
  (processor principal)
  (name (string-ascii 100))
  (location (string-ascii 200))
)
  (if (is-eq tx-sender contract-owner)
    (begin
      (map-set certified-processors
        { processor: processor }
        {
          name: name,
          location: location,
          certification-date: block-height,
          is-active: true
        }
      )
      (ok true)
    )
    err-owner-only
  )
)

;; Start processing
(define-public (start-processing
  (collection-id uint)
  (input-amount uint)
  (processing-method (string-ascii 100))
)
  (if (is-some (map-get? certified-processors { processor: tx-sender }))
    (let ((processing-id (get-next-processing-id)))
      (map-set processing-records
        { processing-id: processing-id }
        {
          collection-id: collection-id,
          processor: tx-sender,
          input-amount: input-amount,
          processing-method: processing-method,
          start-date: block-height,
          end-date: none,
          status: status-received,
          efficiency-rate: none,
          created-at: block-height
        }
      )
      (ok processing-id)
    )
    err-invalid-processor
  )
)

;; Update processing status
(define-public (update-processing-status
  (processing-id uint)
  (new-status uint)
  (efficiency-rate (optional uint))
)
  (match (map-get? processing-records { processing-id: processing-id })
    processing-data
    (if (is-eq tx-sender (get processor processing-data))
      (begin
        (map-set processing-records
          { processing-id: processing-id }
          (merge processing-data {
            status: new-status,
            efficiency-rate: efficiency-rate,
            end-date: (if (is-eq new-status status-completed) (some block-height) (get end-date processing-data))
          })
        )
        (ok true)
      )
      err-unauthorized
    )
    err-not-found
  )
)

;; Get processing record
(define-read-only (get-processing-record (processing-id uint))
  (map-get? processing-records { processing-id: processing-id })
)

;; Check if processor is certified
(define-read-only (is-processor-certified (processor principal))
  (match (map-get? certified-processors { processor: processor })
    processor-data (get is-active processor-data)
    false
  )
)

;; Get processor info
(define-read-only (get-processor-info (processor principal))
  (map-get? certified-processors { processor: processor })
)
