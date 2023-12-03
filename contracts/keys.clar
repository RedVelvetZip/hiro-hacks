;; title: keys
;; version: 0.1
;; summary: friend.tech key mgmt
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;
;; constants
(define-data-var protocolFeePercent uint u200) ;; Protocol Fee Percent, set to 2%
(define-data-var protocolFeeDestination principal tx-sender) ;; Destination for protocol fees
(define-data-var contractOwner principal tx-sender)

;; data vars
;;

;; data maps
;;
(define-map keysBalance { subject: principal, holder: principal } uint)
(define-map keysSupply { subject: principal } uint)
(define-map subjectFeePercent { subject: principal } uint)

;; public functions
;;
(define-public (buy-keys (subject principal) (amount uint))
  (let
    (
      (supply (default-to u0 (map-get? keysSupply { subject: subject })))
      (price (get-price supply amount))
      (protocolFee (calculate-fee price (var-get protocolFeePercent)))
      (subjectFee (calculate-fee price (default-to u0 (map-get? subjectFeePercent { subject: subject }))))
      (totalCost (+ price protocolFee subjectFee))
    )
    (if (or (> supply u0) (is-eq tx-sender subject))
      (begin
        (match (stx-transfer? totalCost tx-sender (as-contract tx-sender))
          success
          (distribute-fees protocolFee subjectFee subject amount)
          error
          (err u2)
        )
      )
      (err u1)
    )
  )
)

(define-public (sell-keys (subject principal) (amount uint))
  (let
    (
      (balance (default-to u0 (map-get? keysBalance { subject: subject, holder: tx-sender })))
      (supply (default-to u0 (map-get? keysSupply { subject: subject })))
      (price (get-price supply amount))
      (protocolFee (calculate-fee price (var-get protocolFeePercent)))
      (subjectFee (calculate-fee price (default-to u0 (map-get? subjectFeePercent { subject: subject }))))
      (totalCost (+ price protocolFee subjectFee))
    )
    (if (and (>= balance amount) (or (> supply u0) (is-eq tx-sender subject)))
      (begin
        (match (as-contract (stx-transfer? totalCost (var-get protocolFeeDestination) tx-sender))
          success
          (distribute-fees protocolFee subjectFee subject amount)
          error
          (err u4)
        )
      )
      (err u1)
    )
  )
)


;; owner-only functions
;;
(define-public (set-contract-owner (newOwner principal))
  (begin
    (if (is-eq tx-sender (var-get contractOwner))
      (begin
        (var-set contractOwner newOwner)
        (ok true)
      )
      (err u1) ;; Unauthorized access
    )
  )
)

(define-public (set-protocol-fee-percent (feePercent uint))
  (if (is-eq tx-sender (var-get contractOwner))
    (begin
      (var-set protocolFeePercent feePercent)
      (ok true)
    )
    (err u1) ;; Unauthorized access
  )
)

;; read only functions
;;
(define-read-only (get-price (supply uint) (amount uint))
  (let
    (
      (base-price u10)
      (price-change-factor u100)
      (adjusted-supply (+ supply amount))
    )
    (+ base-price (* amount (/ (* adjusted-supply adjusted-supply) price-change-factor)))
  )
)

(define-read-only (is-keyholder (subject principal) (holder principal))
  (>= (default-to u0 (map-get? keysBalance { subject: subject, holder: holder })) u1)
)

(define-read-only (get-keys-supply (subject principal))
  (map-get? keysSupply { subject: subject })
)

(define-read-only (get-keys-balance (subject principal) (holder principal))
  (map-get? keysBalance { subject: subject, holder: holder})
)

(define-read-only (get-buy-price (subject principal) (amount uint))
  (let
    ((current-supply (default-to u0 (get-keys-supply subject))))
    (let
      ((new-supply (+ current-supply amount)))
      (/ (* new-supply new-supply) u1000)
    )
  )
)

(define-read-only (get-sell-price (subject principal) (amount uint))
  (let
    ((current-supply (default-to u0 (get-keys-supply subject))))
    (if (>= current-supply amount)
      (let
        ((new-supply (- current-supply amount)))
        (/ (* new-supply new-supply) u1000) ;; TODO: 1000 was arbitrarily chosen as a divisor. Look at sats values and readjust
      )
      u0 ;; return 0 if the supply is less than the amount to sell
    )
  )
)

;; private functions
;;
(define-private (calculate-fee (price uint) (feePercent uint))
  (/ (* price feePercent) u10000)
)

(define-private (distribute-fees (protocolFee uint) (subjectFee uint) (subject principal) (amount uint))
  (match (stx-transfer? protocolFee tx-sender (var-get protocolFeeDestination))
    protocolFeeSuccess
    (if (> subjectFee u0)
      (match (stx-transfer? subjectFee tx-sender subject)
        subjectFeeSuccess
        (update-keys-balance-and-supply subject amount) ;; Corrected call with two arguments
        subjectFeeError
        (err u3) ;; Handle subject fee transfer error
      )
      (update-keys-balance-and-supply subject amount) ;; Corrected call with two arguments
    )
    protocolFeeError
    (err u4) ;; Handle protocol fee transfer error
  )
)

(define-private (update-keys-balance-and-supply (subject principal) (amount uint))
  (let
    (
      (currentBalance (default-to u0 (map-get? keysBalance { subject: subject, holder: tx-sender })))
      (newBalance (+ currentBalance amount))
      (currentSupply (default-to u0 (map-get? keysSupply { subject: subject })))
      (newSupply (+ currentSupply amount))
    )
    (begin
      ;; Update the balance of the buyer in keysBalance map
      (map-set keysBalance { subject: subject, holder: tx-sender } newBalance)

      ;; Update the total supply of keys in keysSupply map
      (map-set keysSupply { subject: subject } newSupply)

      (ok true) ;; Return true to indicate successful update
    )
  )
)
