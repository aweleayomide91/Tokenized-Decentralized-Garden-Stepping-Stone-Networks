;; Aesthetic Enhancement Contract
;; Provides decorative stone selection and arrangement

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u500))
(define-constant ERR-NOT-FOUND (err u501))
(define-constant ERR-ALREADY-EXISTS (err u502))
(define-constant ERR-INVALID-RATING (err u503))
(define-constant ERR-NOT-AUTHORIZED (err u504))

;; Data Variables
(define-data-var next-enhancement-id uint u1)
(define-data-var next-theme-id uint u1)

;; Data Maps
(define-map aesthetic-enhancements
  { enhancement-id: uint }
  {
    designer: principal,
    pathway-id: uint,
    theme-id: uint,
    enhancement-type: (string-ascii 50),
    color-scheme: (string-ascii 100),
    pattern-type: (string-ascii 50),
    aesthetic-rating: uint,
    installation-cost: uint,
    created-at: uint,
    active: bool
  }
)

(define-map enhancement-owners
  { enhancement-id: uint }
  { owner: principal }
)

(define-map design-themes
  { theme-id: uint }
  {
    theme-name: (string-ascii 50),
    creator: principal,
    base-colors: (string-ascii 100),
    style-description: (string-ascii 200),
    popularity-score: uint,
    usage-count: uint,
    created-at: uint
  }
)

(define-map aesthetic-ratings
  { enhancement-id: uint, rater: principal }
  { rating: uint, comment: (string-ascii 200), rated-at: uint }
)

(define-map enhancement-vote-totals
  { enhancement-id: uint }
  { total-rating: uint, vote-count: uint, average-rating: uint }
)

(define-map designer-portfolio
  { designer: principal }
  {
    enhancements-created: uint,
    average-rating: uint,
    total-earnings: uint,
    reputation-score: uint,
    specialization: (string-ascii 50)
  }
)

(define-map color-combinations
  { primary-color: (string-ascii 20), secondary-color: (string-ascii 20) }
  { compatibility-score: uint, usage-count: uint }
)

;; Public Functions

;; Create design theme
(define-public (create-design-theme (theme-name (string-ascii 50)) (base-colors (string-ascii 100)) (style-description (string-ascii 200)))
  (let
    (
      (theme-id (var-get next-theme-id))
    )
    (map-set design-themes
      { theme-id: theme-id }
      {
        theme-name: theme-name,
        creator: tx-sender,
        base-colors: base-colors,
        style-description: style-description,
        popularity-score: u0,
        usage-count: u0,
        created-at: block-height
      }
    )

    (var-set next-theme-id (+ theme-id u1))
    (ok theme-id)
  )
)

;; Create aesthetic enhancement
(define-public (create-aesthetic-enhancement (pathway-id uint) (theme-id uint) (enhancement-type (string-ascii 50)) (color-scheme (string-ascii 100)) (pattern-type (string-ascii 50)) (installation-cost uint))
  (let
    (
      (enhancement-id (var-get next-enhancement-id))
      (theme (unwrap! (map-get? design-themes { theme-id: theme-id }) ERR-NOT-FOUND))
      (designer-stats (default-to
        { enhancements-created: u0, average-rating: u0, total-earnings: u0, reputation-score: u50, specialization: "general" }
        (map-get? designer-portfolio { designer: tx-sender })
      ))
    )
    ;; Create enhancement NFT
    (map-set aesthetic-enhancements
      { enhancement-id: enhancement-id }
      {
        designer: tx-sender,
        pathway-id: pathway-id,
        theme-id: theme-id,
        enhancement-type: enhancement-type,
        color-scheme: color-scheme,
        pattern-type: pattern-type,
        aesthetic-rating: u0,
        installation-cost: installation-cost,
        created-at: block-height,
        active: true
      }
    )

    ;; Set initial owner as designer
    (map-set enhancement-owners
      { enhancement-id: enhancement-id }
      { owner: tx-sender }
    )

    ;; Update designer portfolio
    (map-set designer-portfolio
      { designer: tx-sender }
      (merge designer-stats {
        enhancements-created: (+ (get enhancements-created designer-stats) u1)
      })
    )

    ;; Update theme usage
    (map-set design-themes
      { theme-id: theme-id }
      (merge theme { usage-count: (+ (get usage-count theme) u1) })
    )

    (var-set next-enhancement-id (+ enhancement-id u1))
    (ok enhancement-id)
  )
)

;; Rate aesthetic enhancement
(define-public (rate-enhancement (enhancement-id uint) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (enhancement (unwrap! (map-get? aesthetic-enhancements { enhancement-id: enhancement-id }) ERR-NOT-FOUND))
      (existing-rating (map-get? aesthetic-ratings { enhancement-id: enhancement-id, rater: tx-sender }))
      (vote-totals (default-to
        { total-rating: u0, vote-count: u0, average-rating: u0 }
        (map-get? enhancement-vote-totals { enhancement-id: enhancement-id })
      ))
    )
    (asserts! (and (>= rating u1) (<= rating u10)) ERR-INVALID-RATING)
    (asserts! (is-none existing-rating) ERR-ALREADY-EXISTS)
    (asserts! (get active enhancement) ERR-NOT-FOUND)

    ;; Record rating
    (map-set aesthetic-ratings
      { enhancement-id: enhancement-id, rater: tx-sender }
      { rating: rating, comment: comment, rated-at: block-height }
    )

    ;; Update vote totals
    (let
      (
        (new-total-rating (+ (get total-rating vote-totals) rating))
        (new-vote-count (+ (get vote-count vote-totals) u1))
        (new-average-rating (/ new-total-rating new-vote-count))
      )
      (map-set enhancement-vote-totals
        { enhancement-id: enhancement-id }
        {
          total-rating: new-total-rating,
          vote-count: new-vote-count,
          average-rating: new-average-rating
        }
      )

      ;; Update enhancement rating
      (map-set aesthetic-enhancements
        { enhancement-id: enhancement-id }
        (merge enhancement { aesthetic-rating: new-average-rating })
      )
    )

    (ok true)
  )
)

;; Transfer enhancement ownership
(define-public (transfer-enhancement (enhancement-id uint) (new-owner principal))
  (let
    (
      (current-owner (unwrap! (map-get? enhancement-owners { enhancement-id: enhancement-id }) ERR-NOT-FOUND))
      (enhancement (unwrap! (map-get? aesthetic-enhancements { enhancement-id: enhancement-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner current-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (get active enhancement) ERR-NOT-FOUND)

    (map-set enhancement-owners
      { enhancement-id: enhancement-id }
      { owner: new-owner }
    )

    (ok true)
  )
)

;; Set color combination compatibility
(define-public (set-color-compatibility (primary-color (string-ascii 20)) (secondary-color (string-ascii 20)) (compatibility-score uint))
  (let
    (
      (current-combo (default-to
        { compatibility-score: u0, usage-count: u0 }
        (map-get? color-combinations { primary-color: primary-color, secondary-color: secondary-color })
      ))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (and (>= compatibility-score u1) (<= compatibility-score u10)) ERR-INVALID-RATING)

    (map-set color-combinations
      { primary-color: primary-color, secondary-color: secondary-color }
      (merge current-combo { compatibility-score: compatibility-score })
    )

    (ok true)
  )
)

;; Update designer specialization
(define-public (update-specialization (specialization (string-ascii 50)))
  (let
    (
      (designer-stats (default-to
        { enhancements-created: u0, average-rating: u0, total-earnings: u0, reputation-score: u50, specialization: "general" }
        (map-get? designer-portfolio { designer: tx-sender })
      ))
    )
    (map-set designer-portfolio
      { designer: tx-sender }
      (merge designer-stats { specialization: specialization })
    )

    (ok true)
  )
)

;; Deactivate enhancement
(define-public (deactivate-enhancement (enhancement-id uint))
  (let
    (
      (enhancement (unwrap! (map-get? aesthetic-enhancements { enhancement-id: enhancement-id }) ERR-NOT-FOUND))
      (owner (unwrap! (map-get? enhancement-owners { enhancement-id: enhancement-id }) ERR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get owner owner)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    (map-set aesthetic-enhancements
      { enhancement-id: enhancement-id }
      (merge enhancement { active: false })
    )

    (ok true)
  )
)

;; Read-only Functions

(define-read-only (get-aesthetic-enhancement (enhancement-id uint))
  (map-get? aesthetic-enhancements { enhancement-id: enhancement-id })
)

(define-read-only (get-enhancement-owner (enhancement-id uint))
  (map-get? enhancement-owners { enhancement-id: enhancement-id })
)

(define-read-only (get-design-theme (theme-id uint))
  (map-get? design-themes { theme-id: theme-id })
)

(define-read-only (get-aesthetic-rating (enhancement-id uint) (rater principal))
  (map-get? aesthetic-ratings { enhancement-id: enhancement-id, rater: rater })
)

(define-read-only (get-enhancement-vote-totals (enhancement-id uint))
  (map-get? enhancement-vote-totals { enhancement-id: enhancement-id })
)

(define-read-only (get-designer-portfolio (designer principal))
  (map-get? designer-portfolio { designer: designer })
)

(define-read-only (get-color-compatibility (primary-color (string-ascii 20)) (secondary-color (string-ascii 20)))
  (map-get? color-combinations { primary-color: primary-color, secondary-color: secondary-color })
)

(define-read-only (is-enhancement-active (enhancement-id uint))
  (match (map-get? aesthetic-enhancements { enhancement-id: enhancement-id })
    enhancement (get active enhancement)
    false
  )
)
