;; alpha-heap health vault core contract
;; 
;; This contract serves as the central health data management system,
;; facilitating secure, user-controlled access to personal health information.
;; It provides a decentralized framework for managing health data sharing,
;; ensuring privacy, consent, and granular access control.
;;
;; Key features:
;; - User and device registration
;; - Verified consumer management
;; - Granular data access permissions
;; - Comprehensive access audit logging

;; Error codes
(define-constant err-unauthorized u1)
(define-constant err-user-already-exists u2)
(define-constant err-user-does-not-exist u3)
(define-constant err-device-already-registered u4)
(define-constant err-device-not-registered u5)
(define-constant err-consumer-not-verified u6)
(define-constant err-consumer-already-verified u7)
(define-constant err-access-not-granted u8)
(define-constant err-invalid-data-type u9)
(define-constant err-invalid-expiry u10)

;; Data types for health information categories
(define-constant data-type-heart-rate "cardio-rate")
(define-constant data-type-blood-pressure "blood-pressure")
(define-constant data-type-sleep "rest-metrics")
(define-constant data-type-activity "fitness-activity")
(define-constant data-type-glucose "metabolic-glucose")
(define-constant data-type-oxygen "oxygen-saturation")
(define-constant data-type-temperature "body-temperature")
(define-constant data-type-weight "body-weight")

;; Data maps

;; Stores registered users 
(define-map account-registry 
  { user: principal } 
  { registered: bool, registration-time: uint }
)

;; Maps users to their registered devices
(define-map device-registry 
  { user: principal, device-id: (string-ascii 64) } 
  { registered: bool, device-type: (string-ascii 64), registration-time: uint }
)

;; Stores verified data consumers (healthcare providers, research institutions, etc.)
(define-map verified-entities
  { consumer: principal }
  { verified: bool, consumer-type: (string-ascii 64), verification-time: uint }
)

;; Maps data access permissions granted by users to consumers
(define-map access-control
  { user: principal, consumer: principal, data-type: (string-ascii 64) }
  { granted: bool, expiry: (optional uint), grant-time: uint }
)

;; Tracks access history for audit purposes
(define-map access-audit
  { access-id: uint }
  { 
    user: principal, 
    consumer: principal, 
    data-type: (string-ascii 64), 
    access-time: uint,
    purpose: (string-ascii 128)
  }
)

;; Counter for access history entries
(define-data-var access-log-counter uint u0)

;; Private helper functions

;; Validates if a data type is supported
(define-private (validate-data-category (data-type (string-ascii 64)))
  (or
    (is-eq data-type data-type-heart-rate)
    (is-eq data-type data-type-blood-pressure)
    (is-eq data-type data-type-sleep)
    (is-eq data-type data-type-activity)
    (is-eq data-type data-type-glucose)
    (is-eq data-type data-type-oxygen)
    (is-eq data-type data-type-temperature)
    (is-eq data-type data-type-weight)
  )
)

;; Checks if user exists
(define-private (is-registered-user (user principal))
  (default-to false (get registered (map-get? account-registry { user: user })))
)

;; Checks if device is registered to user
(define-private (is-registered-device (user principal) (device-id (string-ascii 64)))
  (default-to false (get registered (map-get? device-registry { user: user, device-id: device-id })))
)

;; Checks if consumer is verified
(define-private (is-verified-entity (consumer principal))
  (default-to false (get verified (map-get? verified-entities { consumer: consumer })))
)

;; Checks if user has granted access to consumer for specific data type
(define-private (check-access-permission (user principal) (consumer principal) (data-type (string-ascii 64)))
  (let ((permission (map-get? access-control { user: user, consumer: consumer, data-type: data-type })))
    (if (is-none permission)
      false
      (let ((permission-value (unwrap-panic permission)))
        (if (not (get granted permission-value))
          false
          (match (get expiry permission-value)
            expiry-time (< block-height expiry-time)
            true  ;; No expiry means permanent access
          )
        )
      )
    )
  )
)

;; Increments and returns the next access history ID
(define-private (generate-access-log-id)
  (let ((current (var-get access-log-counter)))
    (var-set access-log-counter (+ current u1))
    current
  )
)

;; Record a data access event
(define-private (log-data-access (user principal) (consumer principal) (data-type (string-ascii 64)) (purpose (string-ascii 128)))
  (let ((access-id (generate-access-log-id)))
    (map-set access-audit
      { access-id: access-id }
      {
        user: user,
        consumer: consumer,
        data-type: data-type,
        access-time: block-height,
        purpose: purpose
      }
    )
    (ok access-id)
  )
)

;; Read-only functions for querying system state

;; Check if a user is registered
(define-read-only (query-user-registration (user principal))
  (ok (is-registered-user user))
)

;; Check if a consumer is verified
(define-read-only (query-entity-verification (consumer principal))
  (ok (is-verified-entity consumer))
)

;; Check if consumer has access to user's data
(define-read-only (verify-data-access (user principal) (consumer principal) (data-type (string-ascii 64)))
  (ok (check-access-permission user consumer data-type))
)

;; Get access details for audit
(define-read-only (retrieve-access-details (access-id uint))
  (ok (map-get? access-audit { access-id: access-id }))
)

;; Get access history for a user
(define-read-only (fetch-user-access-history (user principal))
  ;; Note: In a production system, this would use advanced indexing
  (ok (var-get access-log-counter))
)

;; Public functions for system interactions

;; Register as a user in the alpha-heap health system
(define-public (onboard-user)
  (let ((sender tx-sender))
    (asserts! (not (is-registered-user sender)) (err err-user-already-exists))
    
    (map-set account-registry
      { user: sender }
      { registered: true, registration-time: block-height }
    )
    
    (ok true)
  )
)

;; Register a device for a user
(define-public (link-user-device (device-id (string-ascii 64)) (device-type (string-ascii 64)))
  (let ((sender tx-sender))
    (asserts! (is-registered-user sender) (err err-user-does-not-exist))
    (asserts! (not (is-registered-device sender device-id)) (err err-device-already-registered))
    
    (map-set device-registry
      { user: sender, device-id: device-id }
      { registered: true, device-type: device-type, registration-time: block-height }
    )
    
    (ok true)
  )
)

;; Remove a device for a user
(define-public (unlink-user-device (device-id (string-ascii 64)))
  (let ((sender tx-sender))
    (asserts! (is-registered-user sender) (err err-user-does-not-exist))
    (asserts! (is-registered-device sender device-id) (err err-device-not-registered))
    
    (map-set device-registry
      { user: sender, device-id: device-id }
      { registered: false, device-type: "", registration-time: u0 }
    )
    
    (ok true)
  )
)

;; Register as a verified data consumer
(define-public (register-data-entity (consumer principal) (consumer-type (string-ascii 64)))
  (let ((sender tx-sender))
    ;; Restricted to contract deployer for security
    (asserts! (is-eq sender (as-contract tx-sender)) (err err-unauthorized))
    (asserts! (not (is-verified-entity consumer)) (err err-consumer-already-verified))
    
    (map-set verified-entities
      { consumer: consumer }
      { verified: true, consumer-type: consumer-type, verification-time: block-height }
    )
    
    (ok true)
  )
)

;; Grant data access to a verified consumer
(define-public (authorize-data-access 
  (consumer principal) 
  (data-type (string-ascii 64)) 
  (expiry (optional uint)))
  (let ((sender tx-sender))
    (asserts! (is-registered-user sender) (err err-user-does-not-exist))
    (asserts! (is-verified-entity consumer) (err err-consumer-not-verified))
    (asserts! (validate-data-category data-type) (err err-invalid-data-type))
    
    ;; If expiry is provided, ensure it's in the future
    (match expiry
      expiry-time (asserts! (> expiry-time block-height) (err err-invalid-expiry))
      true
    )
    
    (map-set access-control
      { user: sender, consumer: consumer, data-type: data-type }
      { granted: true, expiry: expiry, grant-time: block-height }
    )
    
    (ok true)
  )
)

;; Revoke data access from a consumer
(define-public (revoke-data-access (consumer principal) (data-type (string-ascii 64)))
  (let ((sender tx-sender))
    (asserts! (is-registered-user sender) (err err-user-does-not-exist))
    (asserts! (validate-data-category data-type) (err err-invalid-data-type))
    
    (map-set access-control
      { user: sender, consumer: consumer, data-type: data-type }
      { granted: false, expiry: none, grant-time: block-height }
    )
    
    (ok true)
  )
)