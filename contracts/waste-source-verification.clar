;; Waste Source Verification Contract
;; Validates and registers plastic waste generators

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-verified (err u101))
(define-constant err-not-found (err u102))
(define-constant err-unauthorized (err u103))

;; Data structures
(define-map verified-sources
  { source-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 200),
    waste-type: (string-ascii 50),
    verified-at: uint,
    is-active: bool
  }
)

(define-map source-counter { id: uint } { count: uint })

;; Initialize counter
(map-set source-counter { id: u0 } { count: u0 })

;; Get next source ID
(define-private (get-next-source-id)
  (let ((current-count (default-to u0 (get count (map-get? source-counter { id: u0 })))))
    (let ((next-id (+ current-count u1)))
      (map-set source-counter { id: u0 } { count: next-id })
      next-id
    )
  )
)

;; Register a new waste source
(define-public (register-source (name (string-ascii 100)) (location (string-ascii 200)) (waste-type (string-ascii 50)))
  (let ((source-id (get-next-source-id)))
    (map-set verified-sources
      { source-id: source-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        waste-type: waste-type,
        verified-at: block-height,
        is-active: true
      }
    )
    (ok source-id)
  )
)

;; Verify a source (admin only)
(define-public (verify-source (source-id uint))
  (if (is-eq tx-sender contract-owner)
    (match (map-get? verified-sources { source-id: source-id })
      source-data (begin
        (map-set verified-sources
          { source-id: source-id }
          (merge source-data { verified-at: block-height })
        )
        (ok true)
      )
      err-not-found
    )
    err-owner-only
  )
)

;; Get source information
(define-read-only (get-source (source-id uint))
  (map-get? verified-sources { source-id: source-id })
)

;; Check if source is verified and active
(define-read-only (is-source-active (source-id uint))
  (match (map-get? verified-sources { source-id: source-id })
    source-data (get is-active source-data)
    false
  )
)

;; Deactivate source
(define-public (deactivate-source (source-id uint))
  (match (map-get? verified-sources { source-id: source-id })
    source-data
    (if (or (is-eq tx-sender (get owner source-data)) (is-eq tx-sender contract-owner))
      (begin
        (map-set verified-sources
          { source-id: source-id }
          (merge source-data { is-active: false })
        )
        (ok true)
      )
      err-unauthorized
    )
    err-not-found
  )
)
