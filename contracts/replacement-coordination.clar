;; Replacement Coordination Contract
;; Handles cracked or damaged stone substitution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-ALREADY-EXISTS (err u402))
(define-constant ERR-INVALID-CONDITION (err u403))
(define-constant ERR-NOT-AUTHORIZED (err u404))

;; Data Variables
(define-data-var next-stone-id uint u1)
(define-data-var next-replacement-id uint u1)

;; Data Maps
(define-map replacement-stones
  { stone-id: uint }
  {
    stone-type: (string-ascii 50),
    size: uint,
    color: (string-ascii 30),
    material: (string-ascii 50),
    condition: uint,
    location-x: uint,
    location-y: uint,
    pathway-id: uint,
    installed-at: uint,
    last-inspected: uint
  }
)

(define-map stone-owners
  { stone-id: uint }
  { owner: principal }
)

(define-map replacement-requests
  { replacement-id: uint }
  {
    requester: principal,
    old-stone-id: uint,
    reason: (string-ascii 200),
    urgency: uint,
    requested-at: uint,
    status: (string-ascii 20),
    assigned-to: (optional principal),
    completed-at: (optional uint)
  }
)

(define-map stone-inventory
  { stone-type: (string-ascii 50), size: uint }
  { available-count: uint, reserved-count: uint }
)

(define-map replacement-history
  { stone-id: uint, replacement-id: uint }
  {
    old-condition: uint,
    new-condition: uint,
    replaced-at: uint,
    replaced-by: principal
  }
)

(define-map authorized-installers
  { installer: principal }
  { authorized: bool, installations-completed: uint }
)

;; Public Functions

;; Authorize stone installer
(define-public (authorize-installer (installer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set authorized-installers
      { installer: installer }
      { authorized: true, installations-completed: u0 }
    )
    (ok true)
  )
)

;; Add stone to inventory
(define-public (add-stone-to-inventory (stone-type (string-ascii 50)) (size uint) (count uint))
  (let
    (
      (current-inventory (default-to
        { available-count: u0, reserved-count: u0 }
        (map-get? stone-inventory { stone-type: stone-type, size: size })
      ))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)

    (map-set stone-inventory
      { stone-type: stone-type, size: size }
      {
        available-count: (+ (get available-count current-inventory) count),
        reserved-count: (get reserved-count current-inventory)
      }
    )

    (ok true)
  )
)

;; Install new replacement stone
(define-public (install-replacement-stone (stone-type (string-ascii 50)) (size uint) (color (string-ascii 30)) (material (string-ascii 50)) (location-x uint) (location-y uint) (pathway-id uint))
  (let
    (
      (stone-id (var-get next-stone-id))
      (installer-auth (map-get? authorized-installers { installer: tx-sender }))
    )
    (asserts! (is-some installer-auth) ERR-NOT-AUTHORIZED)
    (asserts! (get authorized (unwrap-panic installer-auth)) ERR-NOT-AUTHORIZED)

    ;; Create stone NFT
    (map-set replacement-stones
      { stone-id: stone-id }
      {
        stone-type: stone-type,
        size: size,
        color: color,
        material: material,
        condition: u10,
        location-x: location-x,
        location-y: location-y,
        pathway-id: pathway-id,
        installed-at: block-height,
        last-inspected: block-height
      }
    )

    ;; Set owner as installer initially
    (map-set stone-owners
      { stone-id: stone-id }
      { owner: tx-sender }
    )

    ;; Update installer stats
    (map-set authorized-installers
      { installer: tx-sender }
      {
        authorized: true,
        installations-completed: (+ (get installations-completed (unwrap-panic installer-auth)) u1)
      }
    )

    (var-set next-stone-id (+ stone-id u1))
    (ok stone-id)
  )
)

;; Request stone replacement
(define-public (request-replacement (stone-id uint) (reason (string-ascii 200)) (urgency uint))
  (let
    (
      (replacement-id (var-get next-replacement-id))
      (stone (unwrap! (map-get? replacement-stones { stone-id: stone-id }) ERR-NOT-FOUND))
    )
    (asserts! (and (>= urgency u1) (<= urgency u5)) ERR-INVALID-CONDITION)

    (map-set replacement-requests
      { replacement-id: replacement-id }
      {
        requester: tx-sender,
        old-stone-id: stone-id,
        reason: reason,
        urgency: urgency,
        requested-at: block-height,
        status: "pending",
        assigned-to: none,
        completed-at: none
      }
    )

    (var-set next-replacement-id (+ replacement-id u1))
    (ok replacement-id)
  )
)

;; Assign replacement request to installer
(define-public (assign-replacement (replacement-id uint) (installer principal))
  (let
    (
      (request (unwrap! (map-get? replacement-requests { replacement-id: replacement-id }) ERR-NOT-FOUND))
      (installer-auth (map-get? authorized-installers { installer: installer }))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-some installer-auth) ERR-NOT-AUTHORIZED)
    (asserts! (get authorized (unwrap-panic installer-auth)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "pending") ERR-ALREADY-EXISTS)

    (map-set replacement-requests
      { replacement-id: replacement-id }
      (merge request {
        status: "assigned",
        assigned-to: (some installer)
      })
    )

    (ok true)
  )
)

;; Complete stone replacement
(define-public (complete-replacement (replacement-id uint) (new-stone-id uint))
  (let
    (
      (request (unwrap! (map-get? replacement-requests { replacement-id: replacement-id }) ERR-NOT-FOUND))
      (old-stone (unwrap! (map-get? replacement-stones { stone-id: (get old-stone-id request) }) ERR-NOT-FOUND))
      (new-stone (unwrap! (map-get? replacement-stones { stone-id: new-stone-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq (some tx-sender) (get assigned-to request)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "assigned") ERR-INVALID-CONDITION)

    ;; Update old stone condition to 0 (removed)
    (map-set replacement-stones
      { stone-id: (get old-stone-id request) }
      (merge old-stone { condition: u0 })
    )

    ;; Mark replacement as completed
    (map-set replacement-requests
      { replacement-id: replacement-id }
      (merge request {
        status: "completed",
        completed-at: (some block-height)
      })
    )

    ;; Record replacement history
    (map-set replacement-history
      { stone-id: new-stone-id, replacement-id: replacement-id }
      {
        old-condition: (get condition old-stone),
        new-condition: (get condition new-stone),
        replaced-at: block-height,
        replaced-by: tx-sender
      }
    )

    (ok true)
  )
)

;; Update stone condition
(define-public (update-stone-condition (stone-id uint) (new-condition uint))
  (let
    (
      (stone (unwrap! (map-get? replacement-stones { stone-id: stone-id }) ERR-NOT-FOUND))
      (stone-owner (unwrap! (map-get? stone-owners { stone-id: stone-id }) ERR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get owner stone-owner)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-condition u0) (<= new-condition u10)) ERR-INVALID-CONDITION)

    (map-set replacement-stones
      { stone-id: stone-id }
      (merge stone {
        condition: new-condition,
        last-inspected: block-height
      })
    )

    (ok true)
  )
)

;; Transfer stone ownership
(define-public (transfer-stone (stone-id uint) (new-owner principal))
  (let
    (
      (current-owner (unwrap! (map-get? stone-owners { stone-id: stone-id }) ERR-NOT-FOUND))
      (stone (unwrap! (map-get? replacement-stones { stone-id: stone-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner current-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> (get condition stone) u0) ERR-INVALID-CONDITION)

    (map-set stone-owners
      { stone-id: stone-id }
      { owner: new-owner }
    )

    (ok true)
  )
)

;; Read-only Functions

(define-read-only (get-replacement-stone (stone-id uint))
  (map-get? replacement-stones { stone-id: stone-id })
)

(define-read-only (get-stone-owner (stone-id uint))
  (map-get? stone-owners { stone-id: stone-id })
)

(define-read-only (get-replacement-request (replacement-id uint))
  (map-get? replacement-requests { replacement-id: replacement-id })
)

(define-read-only (get-stone-inventory (stone-type (string-ascii 50)) (size uint))
  (map-get? stone-inventory { stone-type: stone-type, size: size })
)

(define-read-only (get-replacement-history (stone-id uint) (replacement-id uint))
  (map-get? replacement-history { stone-id: stone-id, replacement-id: replacement-id })
)

(define-read-only (is-installer-authorized (installer principal))
  (default-to false (get authorized (map-get? authorized-installers { installer: installer })))
)

(define-read-only (get-installer-stats (installer principal))
  (map-get? authorized-installers { installer: installer })
)
