;; Efficiency Optimization Contract
;; Provides raking technique guidance and best practices

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_TECHNIQUE (err u501))
(define-constant ERR_INVALID_RATING (err u502))
(define-constant ERR_TIP_NOT_FOUND (err u503))

;; Data Variables
(define-data-var next-tip-id uint u1)
(define-data-var next-technique-id uint u1)

;; Data Maps
(define-map raking-techniques
  {technique-id: uint}
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    difficulty-level: uint,
    efficiency-rating: uint,
    best-conditions: (string-ascii 200),
    tools-required: (string-ascii 200),
    contributor: principal,
    votes-up: uint,
    votes-down: uint
  }
)

(define-map efficiency-tips
  {tip-id: uint}
  {
    title: (string-ascii 100),
    content: (string-ascii 800),
    category: (string-ascii 50),
    author: principal,
    creation-date: uint,
    helpfulness-score: uint,
    usage-count: uint,
    seasonal-relevance: (string-ascii 20)
  }
)

(define-map member-performance
  {member: principal}
  {
    total-raking-hours: uint,
    area-covered-sqft: uint,
    efficiency-score: uint,
    techniques-mastered: uint,
    tips-contributed: uint,
    community-rating: uint
  }
)

(define-map technique-ratings
  {member: principal, technique-id: uint}
  {
    rating: uint,
    difficulty-experienced: uint,
    time-to-master: uint,
    effectiveness: uint,
    notes: (string-ascii 300)
  }
)

(define-map best-practices
  {practice-id: uint}
  {
    title: (string-ascii 100),
    description: (string-ascii 600),
    safety-level: uint,
    environmental-impact: uint,
    time-efficiency: uint,
    endorsed-by-experts: bool,
    community-adoption: uint
  }
)

;; Private Functions
(define-private (calculate-efficiency-score (hours uint) (area uint))
  (if (> hours u0)
    (/ area hours)
    u0
  )
)

(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

;; Public Functions
(define-public (submit-raking-technique
  (name (string-ascii 100))
  (description (string-ascii 500))
  (difficulty uint)
  (conditions (string-ascii 200))
  (tools (string-ascii 200)))
  (let ((technique-id (var-get next-technique-id)))
    (asserts! (<= difficulty u5) ERR_INVALID_TECHNIQUE)
    (map-set raking-techniques
      {technique-id: technique-id}
      {
        name: name,
        description: description,
        difficulty-level: difficulty,
        efficiency-rating: u3, ;; Default neutral rating
        best-conditions: conditions,
        tools-required: tools,
        contributor: tx-sender,
        votes-up: u0,
        votes-down: u0
      }
    )
    (var-set next-technique-id (+ technique-id u1))
    (ok technique-id)
  )
)

(define-public (add-efficiency-tip
  (title (string-ascii 100))
  (content (string-ascii 800))
  (category (string-ascii 50))
  (seasonal-relevance (string-ascii 20)))
  (let ((tip-id (var-get next-tip-id)))
    (map-set efficiency-tips
      {tip-id: tip-id}
      {
        title: title,
        content: content,
        category: category,
        author: tx-sender,
        creation-date: block-height,
        helpfulness-score: u0,
        usage-count: u0,
        seasonal-relevance: seasonal-relevance
      }
    )
    (var-set next-tip-id (+ tip-id u1))
    (ok tip-id)
  )
)

(define-public (rate-technique
  (technique-id uint)
  (rating uint)
  (difficulty uint)
  (time-to-master uint)
  (effectiveness uint)
  (notes (string-ascii 300)))
  (begin
    (asserts! (is-some (map-get? raking-techniques {technique-id: technique-id})) ERR_INVALID_TECHNIQUE)
    (asserts! (is-valid-rating rating) ERR_INVALID_RATING)
    (asserts! (is-valid-rating effectiveness) ERR_INVALID_RATING)
    (ok (map-set technique-ratings
      {member: tx-sender, technique-id: technique-id}
      {
        rating: rating,
        difficulty-experienced: difficulty,
        time-to-master: time-to-master,
        effectiveness: effectiveness,
        notes: notes
      }
    ))
  )
)

(define-public (vote-on-technique (technique-id uint) (vote-up bool))
  (let ((technique (unwrap! (map-get? raking-techniques {technique-id: technique-id}) ERR_INVALID_TECHNIQUE)))
    (if vote-up
      (map-set raking-techniques
        {technique-id: technique-id}
        (merge technique {votes-up: (+ (get votes-up technique) u1)})
      )
      (map-set raking-techniques
        {technique-id: technique-id}
        (merge technique {votes-down: (+ (get votes-down technique) u1)})
      )
    )
    (ok vote-up)
  )
)

(define-public (update-member-performance
  (hours uint)
  (area uint)
  (techniques-count uint))
  (let ((current-performance (default-to
                               {
                                 total-raking-hours: u0,
                                 area-covered-sqft: u0,
                                 efficiency-score: u0,
                                 techniques-mastered: u0,
                                 tips-contributed: u0,
                                 community-rating: u3
                               }
                               (map-get? member-performance {member: tx-sender})))
        (new-hours (+ (get total-raking-hours current-performance) hours))
        (new-area (+ (get area-covered-sqft current-performance) area)))
    (ok (map-set member-performance
      {member: tx-sender}
      (merge current-performance {
        total-raking-hours: new-hours,
        area-covered-sqft: new-area,
        efficiency-score: (calculate-efficiency-score new-hours new-area),
        techniques-mastered: techniques-count
      })
    ))
  )
)

(define-public (mark-tip-helpful (tip-id uint))
  (let ((tip (unwrap! (map-get? efficiency-tips {tip-id: tip-id}) ERR_TIP_NOT_FOUND)))
    (ok (map-set efficiency-tips
      {tip-id: tip-id}
      (merge tip {
        helpfulness-score: (+ (get helpfulness-score tip) u1),
        usage-count: (+ (get usage-count tip) u1)
      })
    ))
  )
)

;; Read-only Functions
(define-read-only (get-raking-technique (technique-id uint))
  (map-get? raking-techniques {technique-id: technique-id})
)

(define-read-only (get-efficiency-tip (tip-id uint))
  (map-get? efficiency-tips {tip-id: tip-id})
)

(define-read-only (get-member-performance (member principal))
  (map-get? member-performance {member: member})
)

(define-read-only (get-technique-rating (member principal) (technique-id uint))
  (map-get? technique-ratings {member: member, technique-id: technique-id})
)

(define-read-only (calculate-member-efficiency (member principal))
  (match (map-get? member-performance {member: member})
    performance-data (get efficiency-score performance-data)
    u0
  )
)
