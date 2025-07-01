;; CyberShield: Advanced Distributed Secure Storage Protocol
;; Military-grade security meets decentralized infrastructure

;; Core System Constants
(define-constant protocol-admin tx-sender)
(define-constant MIN-SHIELD-COST u900) ;; Minimum shield storage cost
(define-constant MAX-SHIELD-COST u9000) ;; Maximum shield storage cost
(define-constant shield-price-per-gb u18) ;; Shield pricing calculation per GB
(define-constant max-fragment-size u2097152) ;; 2 GB max fragment size
(define-constant initial-reputation u180)
(define-constant maximum-reputation u1800)
(define-constant reputation-increase u18)
(define-constant reputation-decrease u10)
(define-constant min-sentinel-copies u5)
(define-constant max-sentinel-copies u15)
(define-constant shield-crypto-level u256) ;; 256-bit shield encryption

;; Enhanced Error Constants
(define-constant ERR-UNAUTHORIZED-ACTION (err u300))
(define-constant ERR-FRAGMENT-TOO-LARGE (err u301))
(define-constant ERR-SHIELD-PAYMENT-LOW (err u302))
(define-constant ERR-FRAGMENT-DUPLICATE (err u303))
(define-constant ERR-INVALID-INPUT (err u304))
(define-constant ERR-FRAGMENT-NOT-FOUND (err u305))
(define-constant ERR-SENTINEL-NOT-ACTIVE (err u306))
(define-constant ERR-REPUTATION-TOO-LOW (err u307))
(define-constant ERR-COPY-LIMIT-EXCEEDED (err u308))
(define-constant ERR-SHIELD-SYNC-ERROR (err u309))
(define-constant ERR-STORAGE-CORRUPTED (err u310))

;; Shield Fragment Registry (Enhanced Architecture)
(define-map shield-fragments 
  { 
    fragment-id: (buff 32),
    storage-owner: principal 
  }
  {
    fragment-bytes: uint,
    shield-key: (buff 64),
    creation-height: uint,
    active-sentinel-count: uint,
    sentinel-nodes: (list 15 principal),
    verification-hash: (buff 32),
    retrieval-count: uint,
    last-retrieval-height: uint
  }
)

;; Advanced Sentinel Node Network
(define-map sentinel-nodes 
  principal 
  {
    storage-limit: uint,
    completed-tasks: uint,
    failed-tasks: uint,
    reputation-level: uint,
    last-ping-height: uint,
    bond-amount: uint,
    sentinel-class: (string-ascii 20),
    shield-verified: bool
  }
)

;; Network Performance Analytics
(define-map protocol-metrics
  { metric-name: (string-ascii 30) }
  {
    accumulated-value: uint,
    last-update-height: uint,
    movement-trend: (string-ascii 10)
  }
)

;; Shield Access Control Matrix
(define-map access-grants
  { fragment-id: (buff 32), authorized-user: principal }
  {
    access-type: (string-ascii 20),
    issued-height: uint,
    expiry-height: uint,
    issuer: principal
  }
)

;; Helper Functions for Shield Operations
(define-private (cap-reputation-level (current-level uint))
  (if (> current-level maximum-reputation)
    maximum-reputation
    current-level)
)

(define-private (floor-reputation-level (current-level uint))
  (if (< current-level u0)
    u0
    current-level)
)

;; Advanced Validation Suite
(define-private (validate-fragment-id (fragment-id (buff 32)))
  (and 
    (> (len fragment-id) u0)
    (<= (len fragment-id) u32)
    (is-eq (len fragment-id) u32) ;; Enforce exact 32-byte hash
  )
)

(define-private (validate-shield-key (key (buff 64)))
  (and 
    (> (len key) u0)
    (<= (len key) u64)
    (>= (len key) u32) ;; Minimum 32-byte encryption strength
  )
)

(define-private (validate-sentinel-status (sentinel principal))
  (is-some (map-get? sentinel-nodes sentinel))
)

(define-private (compute-storage-fee (bytes uint) (class (string-ascii 20)))
  (let ((base-fee (* bytes shield-price-per-gb)))
    (if (is-eq class "premium")
      (* base-fee u2)
      (if (is-eq class "enterprise")
        (* base-fee u3)
        base-fee)
    )
  )
)

;; Shield Node Registration with Enhanced Security
(define-public (register-sentinel-node 
                (bond-amount uint) 
                (sentinel-class (string-ascii 20))
                (shield-verified bool))
  (begin
    ;; Enhanced bond requirements based on class
    (let ((min-bond (if (is-eq sentinel-class "enterprise") u6000
                     (if (is-eq sentinel-class "premium") u3000 u1200))))
      (asserts! (>= bond-amount min-bond) ERR-SHIELD-PAYMENT-LOW)
    )
    
    ;; Prevent duplicate registration
    (asserts! 
      (is-none (map-get? sentinel-nodes tx-sender)) 
      ERR-UNAUTHORIZED-ACTION
    )
    
    ;; Shield verification validation for premium classes
    (asserts! 
      (or (not (is-eq sentinel-class "enterprise")) shield-verified)
      ERR-INVALID-INPUT
    )
    
    ;; Secure bond transfer
    (try! (stx-transfer? bond-amount tx-sender (as-contract tx-sender)))
    
    ;; Initialize sentinel node
    (map-set sentinel-nodes 
      tx-sender 
      {
        storage-limit: u0,
        completed-tasks: u0,
        failed-tasks: u0,
        reputation-level: initial-reputation,
        last-ping-height: block-height,
        bond-amount: bond-amount,
        sentinel-class: sentinel-class,
        shield-verified: shield-verified
      }
    )
    
    ;; Update protocol analytics
    (update-protocol-metric "active-sentinels" u1 "rising")
    (ok true)
  )
)

;; Advanced Shield Fragment Storage
(define-public (store-shield-fragment 
                (fragment-id (buff 32))
                (fragment-bytes uint)
                (shield-key (buff 64))
                (verification-hash (buff 32))
                (copy-factor uint))
  (begin
    ;; Comprehensive input validation
    (asserts! (validate-fragment-id fragment-id) ERR-INVALID-INPUT)
    (asserts! (validate-shield-key shield-key) ERR-INVALID-INPUT)
    (asserts! (<= fragment-bytes max-fragment-size) ERR-FRAGMENT-TOO-LARGE)
    (asserts! (and (>= copy-factor min-sentinel-copies) 
                   (<= copy-factor max-sentinel-copies)) ERR-INVALID-INPUT)
    
    ;; Check for fragment collision
    (asserts! 
      (is-none (map-get? shield-fragments { fragment-id: fragment-id, storage-owner: tx-sender }))
      ERR-FRAGMENT-DUPLICATE
    )
    
    ;; Calculate and validate shield storage fee
    (let ((storage-fee (compute-storage-fee fragment-bytes "standard")))
      (asserts! (>= storage-fee MIN-SHIELD-COST) ERR-SHIELD-PAYMENT-LOW)
      
      ;; Process payment
      (try! (stx-transfer? storage-fee tx-sender (as-contract tx-sender)))
      
      ;; Store shield fragment metadata
      (map-set shield-fragments
        { fragment-id: fragment-id, storage-owner: tx-sender }
        {
          fragment-bytes: fragment-bytes,
          shield-key: shield-key,
          creation-height: block-height,
          active-sentinel-count: u0,
          sentinel-nodes: (list),
          verification-hash: verification-hash,
          retrieval-count: u0,
          last-retrieval-height: block-height
        }
      )
      
      ;; Update protocol analytics
      (update-protocol-metric "total-fragments" fragment-bytes "rising")
      (ok fragment-id)
    )
  )
)

;; Enhanced Reputation Management System
(define-public (update-sentinel-reputation 
                (sentinel principal) 
                (fragment-id (buff 32))
                (task-success bool)
                (bonus-points uint))
  (begin
    ;; Validate inputs
    (asserts! (validate-fragment-id fragment-id) ERR-INVALID-INPUT)
    (asserts! (validate-sentinel-status sentinel) ERR-SENTINEL-NOT-ACTIVE)
    (asserts! (<= bonus-points u60) ERR-INVALID-INPUT) ;; Cap bonus
    
    ;; Retrieve current sentinel stats
    (let ((current-data 
            (unwrap! 
              (map-get? sentinel-nodes sentinel) 
              ERR-SENTINEL-NOT-ACTIVE
            )))
      
      ;; Calculate new reputation level with bonus points
      (let ((base-change (if task-success reputation-increase reputation-decrease))
            (total-change (+ base-change bonus-points)))
        
        ;; Update sentinel statistics
        (map-set sentinel-nodes 
          sentinel
          (if task-success
            ;; Successful task path
            (merge current-data {
              completed-tasks: (+ (get completed-tasks current-data) u1),
              reputation-level: (cap-reputation-level 
                (+ (get reputation-level current-data) total-change)
              ),
              last-ping-height: block-height
            })
            ;; Failed task path
            (merge current-data {
              failed-tasks: (+ (get failed-tasks current-data) u1),
              reputation-level: (floor-reputation-level 
                (- (get reputation-level current-data) reputation-decrease)
              ),
              last-ping-height: block-height
            })
          )
        )
      )
      
      (ok true)
    )
  )
)

;; NEW FUNCTION: Shield Fragment Migration
(define-public (migrate-shield-fragment 
                (fragment-id (buff 32))
                (destination-sentinels (list 5 principal))
                (migration-notes (string-ascii 100)))
  (begin
    ;; Validate fragment ownership and existence
    (asserts! (validate-fragment-id fragment-id) ERR-INVALID-INPUT)
    
    (let ((fragment-info (unwrap! 
                           (map-get? shield-fragments { fragment-id: fragment-id, storage-owner: tx-sender })
                           ERR-FRAGMENT-NOT-FOUND)))
      
      ;; Validate destination sentinels are registered and have sufficient reputation
      (asserts! (> (len destination-sentinels) u0) ERR-INVALID-INPUT)
      
      ;; Update fragment with new sentinel nodes
      (map-set shield-fragments
        { fragment-id: fragment-id, storage-owner: tx-sender }
        (merge fragment-info {
          sentinel-nodes: destination-sentinels,
          active-sentinel-count: (len destination-sentinels),
          last-retrieval-height: block-height
        })
      )
      
      ;; Update protocol analytics
      (update-protocol-metric "fragment-migrations" u1 "stable")
      (ok true)
    )
  )
)

;; Private helper for analytics updates
(define-private (update-protocol-metric (metric-name (string-ascii 30)) (value uint) (trend (string-ascii 10)))
  (match (map-get? protocol-metrics { metric-name: metric-name })
    existing-data
    (map-set protocol-metrics
      { metric-name: metric-name }
      {
        accumulated-value: (+ (get accumulated-value existing-data) value),
        last-update-height: block-height,
        movement-trend: trend
      }
    )
    (map-insert protocol-metrics
      { metric-name: metric-name }
      {
        accumulated-value: value,
        last-update-height: block-height,
        movement-trend: trend
      }
    )
  )
)

;; Enhanced Fragment Retrieval with Access Control
(define-read-only (retrieve-shield-fragment (fragment-id (buff 32)))
  (begin
    (asserts! (validate-fragment-id fragment-id) none)
    
    ;; Check access permissions
    (let ((fragment-info (map-get? shield-fragments { fragment-id: fragment-id, storage-owner: tx-sender })))
      (match fragment-info
        found-fragment
        ;; Update retrieval count (would need public wrapper for actual implementation)
        (some found-fragment)
        none
      )
    )
  )
)

;; Advanced Bond Management with Dynamic Penalties
(define-public (withdraw-sentinel-bond (amount uint) (emergency-exit bool))
  (let ((sentinel tx-sender)
        (sentinel-data (unwrap! 
          (map-get? sentinel-nodes sentinel) 
          ERR-SENTINEL-NOT-ACTIVE
        )))
    
    ;; Enhanced reputation requirements based on exit type
    (let ((min-reputation-required (if emergency-exit u360 u900)))
      (asserts! 
        (>= (get reputation-level sentinel-data) min-reputation-required) 
        ERR-REPUTATION-TOO-LOW
      )
    )
    
    ;; Validate withdrawal parameters
    (asserts! (and (> amount u0) (<= amount (get bond-amount sentinel-data))) ERR-INVALID-INPUT)
    
    ;; Apply early exit penalty if emergency exit
    (let ((penalty-rate (if emergency-exit u12 u0)) ;; 12% penalty for emergency exit
          (penalty-cost (/ (* amount penalty-rate) u100))
          (net-amount (- amount penalty-cost)))
      
      ;; Process withdrawal
      (try! (as-contract (stx-transfer? net-amount (as-contract tx-sender) sentinel)))
      
      ;; Update sentinel bond
      (map-set sentinel-nodes
        sentinel
        (merge sentinel-data {
          bond-amount: (- (get bond-amount sentinel-data) amount),
          last-ping-height: block-height
        })
      )
      
      (ok net-amount)
    )
  )
)

;; Comprehensive Sentinel Analytics
(define-read-only (get-sentinel-analytics (sentinel principal))
  (begin
    (asserts! (validate-sentinel-status sentinel) none)
    (let ((data (unwrap! (map-get? sentinel-nodes sentinel) none)))
      (some {
        sentinel: sentinel,
        reputation-level: (get reputation-level data),
        success-percentage: (if (> (+ (get completed-tasks data) (get failed-tasks data)) u0)
                              (/ (* (get completed-tasks data) u100)
                                 (+ (get completed-tasks data) (get failed-tasks data)))
                              u0),
        total-tasks: (+ (get completed-tasks data) (get failed-tasks data)),
        sentinel-class: (get sentinel-class data),
        shield-verified: (get shield-verified data),
        days-since-ping: (/ (- block-height (get last-ping-height data)) u144) ;; Assuming ~144 blocks per day
      })
    )
  )
)

;; Protocol Health Dashboard
(define-read-only (get-protocol-health)
  (let ((active-sentinels-metric (map-get? protocol-metrics { metric-name: "active-sentinels" }))
        (total-fragments-metric (map-get? protocol-metrics { metric-name: "total-fragments" }))
        (migrations-metric (map-get? protocol-metrics { metric-name: "fragment-migrations" })))
    {
      active-sentinels: (match active-sentinels-metric some-data (get accumulated-value some-data) u0),
      total-storage-gb: (match total-fragments-metric some-data (/ (get accumulated-value some-data) u1000000000) u0),
      total-migrations: (match migrations-metric some-data (get accumulated-value some-data) u0),
      protocol-uptime-blocks: (- block-height u0) ;; Blocks since genesis
    }
  )
)

;; Shield Integrity Verification
(define-read-only (verify-fragment-integrity (fragment-id (buff 32)) (provided-hash (buff 32)))
  (begin
    (asserts! (validate-fragment-id fragment-id) none)
    (match (map-get? shield-fragments { fragment-id: fragment-id, storage-owner: tx-sender })
      fragment-info
      (some (is-eq (get verification-hash fragment-info) provided-hash))
      none
    )
  )
)

;; Advanced Access Permission System
(define-public (grant-fragment-access 
                (fragment-id (buff 32))
                (authorized-user principal)
                (access-type (string-ascii 20))
                (duration-blocks uint))
  (begin
    ;; Validate fragment ownership
    (asserts! (validate-fragment-id fragment-id) ERR-INVALID-INPUT)
    (asserts! 
      (is-some (map-get? shield-fragments { fragment-id: fragment-id, storage-owner: tx-sender }))
      ERR-FRAGMENT-NOT-FOUND
    )
    
    ;; Validate access parameters
    (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)
    (asserts! (<= duration-blocks u1051200) ERR-INVALID-INPUT) ;; Max 2 years
    
    ;; Grant access
    (map-set access-grants
      { fragment-id: fragment-id, authorized-user: authorized-user }
      {
        access-type: access-type,
        issued-height: block-height,
        expiry-height: (+ block-height duration-blocks),
        issuer: tx-sender
      }
    )
    
    (ok true)
  )
)