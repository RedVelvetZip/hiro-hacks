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
;; (define-data-var subjectFeePercent (map principal uint) uint) ;; Subject-specific Fee Percent
(define-data-var protocolFeeDestination principal tx-sender) ;; Destination for protocol fees

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
      (protocolFee (var-get protocolFeePercent))
      (subjectFee (default-to u0 (map-get? subjectFeePercent { subject: subject })))
      (totalFee (+ (* price (/ protocolFee u10000)) (* price (/ subjectFee u10000))))
      (totalCost (+ price totalFee))
    )
    (if (or (> supply u0) (is-eq tx-sender subject))
      (begin
        ;; Transfer total cost from the buyer to the contract (or subject)
        (match (stx-transfer? totalCost tx-sender (as-contract tx-sender))
          success
          (begin
            ;; Distribute the fees
            (stx-transfer? (* price (/ protocolFee u10000)) tx-sender (var-get protocolFeeDestination))
            (if (> subjectFee u0)
              (stx-transfer? (* price (/ subjectFee u10000)) tx-sender subject)
              u0
            )
            ;; Update keys balance and supply
            (map-set keysBalance { subject: subject, holder: tx-sender }
              (+ (default-to u0 (map-get? keysBalance { subject: subject, holder: tx-sender })) amount)
            )
            (map-set keysSupply { subject: subject } (+ supply amount))
            (ok true)
          )
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
      (protocolFee (var-get protocolFeePercent))
      (subjectFee (default-to u0 (map-get? subjectFeePercent { subject: subject })))
      (totalFee (+ (* price (/ protocolFee u10000)) (* price (/ subjectFee u10000))))
      (totalRevenue (- price totalFee))
    )
    (if (and (>= balance amount) (or (> supply u0) (is-eq tx-sender subject)))
      (begin
        ;; Update keys balance and supply before transferring funds
        (map-set keysBalance { subject: subject, holder: tx-sender } (- balance amount))
        (map-set keysSupply { subject: subject } (- supply amount))
        
        ;; Transfer totalRevenue to the seller
        (match (as-contract (stx-transfer? totalRevenue (as-contract tx-sender) tx-sender))
          success
          (begin
            ;; Distribute the fees
            (stx-transfer? (* price (/ protocolFee u10000)) (as-contract tx-sender) (var-get protocolFeeDestination))
            (if (> subjectFee u0)
              (stx-transfer? (* price (/ subjectFee u10000)) (as-contract tx-sender) subject)
              u0
            )
            (ok true)
          )
          error
          (err u2)
        )
      )
      (err u1)
    )
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

