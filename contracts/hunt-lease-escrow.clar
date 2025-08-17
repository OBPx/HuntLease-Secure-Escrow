;; hunt-lease-escrow.clar
;; This contract facilitates the leasing of hunting land between landowners and hunters.
;; It acts as a neutral third-party escrow, holding STX payments until the terms of the
;; lease are successfully completed and confirmed by both parties.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and Contract Owner
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u101)
(define-constant ERR_LEASE_NOT_FOUND u102)
(define-constant ERR_INVALID_LEASE_STATE u103)
(define-constant ERR_INVALID_AMOUNT u104)
(define-constant ERR_FUNDS_NOT_RECEIVED u105)
(define-constant ERR_LEASE_ALREADY_CONFIRMED u106)
(define-constant ERR_LEASE_EXPIRED u107) ;; Placeholder for future time-based logic
(define-constant ERR_PAYMENT_FAILED u108)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Storage
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Lease Statuses
(define-constant STATUS_LISTED u0)
(define-constant STATUS_FUNDED u1)
(define-constant STATUS_ACTIVE u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_DISPUTED u4)
(define-constant STATUS_CANCELED u5)

(define-map leases uint {
  landowner: principal,
  hunter: principal,
  amount: uint,
  status: uint,
  landowner-confirmed: bool,
  hunter-confirmed: bool,
  details-uri: (string-ascii 128)
})

(define-data-var last-lease-id uint u0)
(define-data-var service-fee-percent uint u2) ;; 2% service fee

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Administrative Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- Set Service Fee ---
;; Allows the contract owner to adjust the service fee percentage.
(define-public (set-service-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= new-fee-percent u10) (err ERR_INVALID_AMOUNT)) ;; Max 10%
    (ok (var-set service-fee-percent new-fee-percent))
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- List a new Lease Property ---
;; A landowner lists a property for lease.
(define-public (list-lease (amount-ustx uint) (details-uri (string-ascii 128)))
  (begin
    (asserts! (> amount-ustx u0) (err ERR_INVALID_AMOUNT))
    (let ((lease-id (+ u1 (var-get last-lease-id))))
      (map-set leases lease-id {
        landowner: tx-sender,
        hunter: tx-sender, ;; Placeholder until funded
        amount: amount-ustx,
        status: STATUS_LISTED,
        landowner-confirmed: false,
        hunter-confirmed: false,
        details-uri: details-uri
      })
      (var-set last-lease-id lease-id)
      (print { message: "lease listed", id: lease-id })
      (ok lease-id)
    )
  )
)

;; --- Fund a Lease (Hunter's action) ---
;; A hunter funds a listed lease, moving it to the FUNDED state.
(define-public (fund-lease (lease-id uint))
  (let ((lease (unwrap! (map-get? leases lease-id) (err ERR_LEASE_NOT_FOUND))))
    (asserts! (is-eq (get status lease) STATUS_LISTED) (err ERR_INVALID_LEASE_STATE))

    (let ((amount (get amount lease)))
      (stx-transfer? amount tx-sender (as-contract tx-sender))
      (map-set leases lease-id (merge lease { hunter: tx-sender, status: STATUS_FUNDED }))
      (print { message: "lease funded", id: lease-id })
      (ok true)
    )
  )
)

;; --- Activate Lease (Landowner's action) ---
;; Landowner acknowledges funding and activates the lease period.
(define-public (activate-lease (lease-id uint))
  (let ((lease (unwrap! (map-get? leases lease-id) (err ERR_LEASE_NOT_FOUND))))
    (asserts! (is-eq tx-sender (get landowner lease)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (get status lease) STATUS_FUNDED) (err ERR_INVALID_LEASE_STATE))

    (map-set leases lease-id (merge lease { status: STATUS_ACTIVE }))
    (print { message: "lease activated", id: lease-id })
    (ok true)
  )
)

;; --- Confirm Completion ---
;; Landowner or hunter confirms the lease was completed successfully.
(define-public (confirm-completion (lease-id uint))
  (let ((lease (unwrap! (map-get? leases lease-id) (err ERR_LEASE_NOT_FOUND)))
        (sender tx-sender))

    (asserts! (or (is-eq sender (get landowner lease)) (is-eq sender (get hunter lease))) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (get status lease) STATUS_ACTIVE) (err ERR_INVALID_LEASE_STATE))

    (let ((is-landowner (is-eq sender (get landowner lease)))
          (is-hunter (is-eq sender (get hunter lease)))
          (updated-lease
            (if is-landowner
              (merge lease { landowner-confirmed: true })
              (merge lease { hunter-confirmed: true }))))

      (map-set leases lease-id updated-lease)
      (try! (release-funds-if-confirmed lease-id))
      (ok true)
    )
  )
)

;; --- Cancel Lease (Before Activation) ---
;; Either party can cancel before the lease is active. Hunter gets a full refund.
(define-public (cancel-lease (lease-id uint))
  (let ((lease (unwrap! (map-get? leases lease-id) (err ERR_LEASE_NOT_FOUND))))
    (asserts! (or (is-eq tx-sender (get landowner lease)) (is-eq tx-sender (get hunter lease))) (err ERR_NOT_AUTHORIZED))
    (asserts! (or (is-eq (get status lease) STATUS_LISTED) (is-eq (get status lease) STATUS_FUNDED)) (err ERR_INVALID_LEASE_STATE))

    (if (is-eq (get status lease) STATUS_FUNDED)
      (begin
        (as-contract (stx-transfer? (get amount lease) tx-sender (get hunter lease)))
        (map-set leases lease-id (merge lease { status: STATUS_CANCELED }))
        (ok true)
      )
      (begin
        (map-set leases lease-id (merge lease { status: STATUS_CANCELED }))
        (ok true)
      )
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Private Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- Release funds when both parties have confirmed ---
(define-private (release-funds-if-confirmed (lease-id uint))
  (let ((lease (unwrap! (map-get? leases lease-id) (err ERR_LEASE_NOT_FOUND))))
    (if (and (get landowner-confirmed lease) (get hunter-confirmed lease))
      (begin
        (asserts! (is-eq (get status lease) STATUS_ACTIVE) (err ERR_INVALID_LEASE_STATE))
        (let ((total-amount (get amount lease))
              (fee-percent (var-get service-fee-percent))
              (service-fee (/ (* total-amount fee-percent) u100))
              (payout-amount (- total-amount service-fee)))

          (asserts! (> payout-amount u0) (err ERR_INVALID_AMOUNT))

          ;; Transfer service fee to contract owner
          (as-contract (try! (stx-transfer? service-fee tx-sender CONTRACT_OWNER)))
          ;; Transfer payout to landowner
          (as-contract (try! (stx-transfer? payout-amount tx-sender (get landowner lease))))

          (map-set leases lease-id (merge lease { status: STATUS_COMPLETED }))
          (print { message: "funds released", id: lease-id, amount: payout-amount })
          (ok true)
        )
      )
      (ok false) ;; Not fully confirmed yet
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-Only Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-lease-details (lease-id uint))
  (map-get? leases lease-id)
)

(define-read-only (get-last-lease-id)
  (var-get last-lease-id)
)

(define-read-only (get-service-fee)
  (var-get service-fee-percent)
)