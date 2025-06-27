;; WorkshopHub: Decentralized workshop booking system with skill-building sessions and instructor verification
;; Connects skilled instructors with learners for hands-on educational workshops and training sessions

(define-data-var workshop-administrator principal tx-sender)
(define-map instructor-profiles
  { instructor-id: uint }
  {
    facilitator: principal,
    workshop-price: uint,
    teaching-subject: (string-ascii 50),
    instructor-bio: (string-ascii 500),
    teaching-years: uint,
    approved: bool
  }
)

(define-map workshop-bookings
  { instructor-id: uint, booking-id: uint }
  {
    attendee: principal,
    registration-time: uint,
    workshop-type: (string-ascii 20)
  }
)

(define-data-var next-instructor-id uint u1)
(define-map booking-tracker 
  { instructor-id: uint }
  { bookings: uint }
)

;; Register as an instructor
(define-public (register-instructor (subject-input (string-ascii 50)) (bio-input (string-ascii 500)) (years-input uint) (price-input uint))
  (let
    (
      (instructor-id (var-get next-instructor-id))
      (booking-id u0)
      (subject subject-input)
      (bio bio-input)
      (years years-input)
      (price price-input)
    )
    ;; Input validation
    (asserts! (> price u0) (err u1))
    (asserts! (> (len subject) u0) (err u5))
    (asserts! (> (len bio) u0) (err u6))
    (asserts! (> years u0) (err u7))
    
    (map-set instructor-profiles
      { instructor-id: instructor-id }
      {
        facilitator: tx-sender,
        workshop-price: price,
        teaching-subject: subject,
        instructor-bio: bio,
        teaching-years: years,
        approved: false
      }
    )
    (map-set workshop-bookings
      { instructor-id: instructor-id, booking-id: booking-id }
      {
        attendee: tx-sender,
        registration-time: instructor-id,
        workshop-type: "registered"
      }
    )
    (map-set booking-tracker 
      { instructor-id: instructor-id }
      { bookings: u1 }
    )
    (var-set next-instructor-id (+ instructor-id u1))
    (ok instructor-id)
  )
)

;; Book a workshop
(define-public (book-workshop (instructor-id-input uint))
  (let
    (
      (instructor-id instructor-id-input)
      (instructor-info (unwrap! (map-get? instructor-profiles { instructor-id: instructor-id }) (err u2)))
      (price (get workshop-price instructor-info))
      (facilitator (get facilitator instructor-info))
      (booking-data (default-to { bookings: u0 } (map-get? booking-tracker { instructor-id: instructor-id })))
      (booking-id (get bookings booking-data))
      (new-booking-id (+ booking-id u1))
    )
    ;; Input validation
    (asserts! (> instructor-id u0) (err u8))
    (asserts! (not (is-eq tx-sender facilitator)) (err u3))
    
    (try! (stx-transfer? price tx-sender facilitator))
    (map-set workshop-bookings
      { instructor-id: instructor-id, booking-id: booking-id }
      {
        attendee: tx-sender,
        registration-time: (var-get next-instructor-id),
        workshop-type: "booked"
      }
    )
    (map-set booking-tracker 
      { instructor-id: instructor-id }
      { bookings: new-booking-id }
    )
    (ok true)
  )
)

;; Approve an instructor (administrator only)
(define-public (approve-instructor (instructor-id-input uint))
  (let
    (
      (instructor-id instructor-id-input)
      (instructor-info (unwrap! (map-get? instructor-profiles { instructor-id: instructor-id }) (err u2)))
      (booking-data (default-to { bookings: u0 } (map-get? booking-tracker { instructor-id: instructor-id })))
      (booking-id (get bookings booking-data))
      (new-booking-id (+ booking-id u1))
    )
    ;; Input validation
    (asserts! (> instructor-id u0) (err u8))
    (asserts! (is-eq tx-sender (var-get workshop-administrator)) (err u4))
    
    (map-set instructor-profiles
      { instructor-id: instructor-id }
      (merge instructor-info { approved: true })
    )
    (map-set workshop-bookings
      { instructor-id: instructor-id, booking-id: booking-id }
      {
        attendee: (get facilitator instructor-info),
        registration-time: (var-get next-instructor-id),
        workshop-type: "approved"
      }
    )
    (map-set booking-tracker 
      { instructor-id: instructor-id }
      { bookings: new-booking-id }
    )
    (ok true)
  )
)

;; Get instructor profile
(define-read-only (get-instructor (instructor-id uint))
  (map-get? instructor-profiles { instructor-id: instructor-id })
)

;; Get workshop booking record
(define-read-only (get-booking-record (instructor-id uint) (booking-id uint))
  (map-get? workshop-bookings { instructor-id: instructor-id, booking-id: booking-id })
)

;; Get total bookings for an instructor
(define-read-only (get-booking-count (instructor-id uint))
  (let
    (
      (booking-data (default-to { bookings: u0 } (map-get? booking-tracker { instructor-id: instructor-id })))
    )
    (get bookings booking-data)
  )
)
