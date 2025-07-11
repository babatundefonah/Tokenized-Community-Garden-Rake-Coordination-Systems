;; Sharing Rotation Contract
;; Organizes rake lending among neighborhood participants

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_RAKE_UNAVAILABLE (err u301))
(define-constant ERR_INVALID_BORROWER (err u302))
(define-constant ERR_ALREADY_BORROWED (err u303))
(define-constant ERR_NOT_BORROWED (err u304))

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var max-loan-duration uint u7) ;; 7 days

;; Data Maps
(define-map community-members
  {member: principal}
  {
    reputation-score: uint,
    total-borrows: uint,
    total-lends: uint,
    late-returns: uint,
    join-date: uint,
    active-status: bool
  }
)

(define-map rake-availability
  {rake-id: uint}
  {
    owner: principal,
    available: bool,
    current-borrower: (optional principal),
    loan-start-date: uint,
    loan-end-date: uint,
    lending-conditions: (string-ascii 200)
  }
)

(define-map loan-history
  {loan-id: uint}
  {
    rake-id: uint,
    lender: principal,
    borrower: principal,
    start-date: uint,
    expected-return: uint,
    actual-return: (optional uint),
    condition-before: uint,
    condition-after: (optional uint),
    status: (string-ascii 20)
  }
)

(define-map borrowing-queue
  {rake-id: uint, position: uint}
  {
    member: principal,
    request-date: uint,
    priority-score: uint,
    duration-requested: uint
  }
)

;; Private Functions
(define-private (calculate-priority-score (member principal))
  (match (map-get? community-members {member: member})
    member-data
      (let ((reputation (get reputation-score member-data))
            (lend-ratio (if (> (get total-borrows member-data) u0)
                          (/ (* (get total-lends member-data) u100) (get total-borrows member-data))
                          u100))
            (late-penalty (* (get late-returns member-data) u10)))
        (if (> (+ reputation lend-ratio) late-penalty)
          (- (+ reputation lend-ratio) late-penalty)
          u0))
    u50 ;; Default score for new members
  )
)

(define-private (is-member-active (member principal))
  (match (map-get? community-members {member: member})
    member-data (get active-status member-data)
    false
  )
)

;; Public Functions
(define-public (register-member)
  (ok (map-set community-members
    {member: tx-sender}
    {
      reputation-score: u100,
      total-borrows: u0,
      total-lends: u0,
      late-returns: u0,
      join-date: block-height,
      active-status: true
    }
  ))
)

(define-public (make-rake-available (rake-id uint) (conditions (string-ascii 200)))
  (begin
    (asserts! (is-member-active tx-sender) ERR_UNAUTHORIZED)
    (ok (map-set rake-availability
      {rake-id: rake-id}
      {
        owner: tx-sender,
        available: true,
        current-borrower: none,
        loan-start-date: u0,
        loan-end-date: u0,
        lending-conditions: conditions
      }
    ))
  )
)

(define-public (request-rake-loan (rake-id uint) (duration uint))
  (let ((availability (unwrap! (map-get? rake-availability {rake-id: rake-id}) ERR_RAKE_UNAVAILABLE))
        (priority (calculate-priority-score tx-sender)))
    (asserts! (is-member-active tx-sender) ERR_INVALID_BORROWER)
    (asserts! (get available availability) ERR_RAKE_UNAVAILABLE)
    (asserts! (<= duration (var-get max-loan-duration)) ERR_UNAUTHORIZED)

    ;; Add to queue (simplified - position 1 for now)
    (map-set borrowing-queue
      {rake-id: rake-id, position: u1}
      {
        member: tx-sender,
        request-date: block-height,
        priority-score: priority,
        duration-requested: duration
      }
    )
    (ok priority)
  )
)

(define-public (approve-loan (rake-id uint) (borrower principal))
  (let ((availability (unwrap! (map-get? rake-availability {rake-id: rake-id}) ERR_RAKE_UNAVAILABLE))
        (loan-id (var-get next-loan-id)))
    (asserts! (is-eq tx-sender (get owner availability)) ERR_UNAUTHORIZED)
    (asserts! (get available availability) ERR_RAKE_UNAVAILABLE)
    (asserts! (is-member-active borrower) ERR_INVALID_BORROWER)

    ;; Update availability
    (map-set rake-availability
      {rake-id: rake-id}
      (merge availability {
        available: false,
        current-borrower: (some borrower),
        loan-start-date: block-height,
        loan-end-date: (+ block-height (var-get max-loan-duration))
      })
    )

    ;; Create loan record
    (map-set loan-history
      {loan-id: loan-id}
      {
        rake-id: rake-id,
        lender: tx-sender,
        borrower: borrower,
        start-date: block-height,
        expected-return: (+ block-height (var-get max-loan-duration)),
        actual-return: none,
        condition-before: u100,
        condition-after: none,
        status: "active"
      }
    )

    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (return-rake (loan-id uint) (condition-after uint))
  (let ((loan (unwrap! (map-get? loan-history {loan-id: loan-id}) ERR_NOT_BORROWED)))
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR_NOT_BORROWED)

    ;; Update loan record
    (map-set loan-history
      {loan-id: loan-id}
      (merge loan {
        actual-return: (some block-height),
        condition-after: (some condition-after),
        status: "completed"
      })
    )

    ;; Update rake availability
    (map-set rake-availability
      {rake-id: (get rake-id loan)}
      {
        owner: (get lender loan),
        available: true,
        current-borrower: none,
        loan-start-date: u0,
        loan-end-date: u0,
        lending-conditions: ""
      }
    )

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-member-info (member principal))
  (map-get? community-members {member: member})
)

(define-read-only (get-rake-availability (rake-id uint))
  (map-get? rake-availability {rake-id: rake-id})
)

(define-read-only (get-loan-info (loan-id uint))
  (map-get? loan-history {loan-id: loan-id})
)

(define-read-only (get-queue-position (rake-id uint) (position uint))
  (map-get? borrowing-queue {rake-id: rake-id, position: position})
)

(define-read-only (calculate-member-priority (member principal))
  (calculate-priority-score member)
)
