;; Define SIP-009 NFT trait
(define-trait nft-trait
    (
        (get-last-token-id () (response uint uint))
        (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
        (get-owner (uint) (response (optional principal) uint))
        (transfer (uint principal principal) (response bool uint))
    )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-listed (err u101))
(define-constant err-wrong-price (err u102))
(define-constant err-already-listed (err u103))
(define-constant err-token-not-found (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-invalid-fee (err u106))
(define-constant err-invalid-token (err u107))
(define-constant err-not-admin (err u108))
(define-constant err-already-admin (err u109))
(define-constant err-cannot-remove-owner (err u110))
(define-constant err-invalid-price-range (err u111))

;; Price constraints as variables instead of constants
(define-data-var min-price uint u1000)
(define-data-var max-price uint u100000000000)
(define-constant max-fee u100)

;; Data variables
(define-data-var platform-fee uint u25)
(define-map listings 
    { nft-contract: principal, token-id: uint }
    { price: uint, seller: principal }
)

;; Admin management
(define-map admins principal bool)

;; Initialize contract owner as first admin
(map-set admins contract-owner true)

;; Event logging functions
(define-private (log-listing-created (nft-contract principal) (token-id uint) (price uint) (seller principal))
    (print {
        event: "listing-created",
        nft-contract: nft-contract,
        token-id: token-id,
        price: price,
        seller: seller
    })
)

(define-private (log-listing-removed (nft-contract principal) (token-id uint) (seller principal))
    (print {
        event: "listing-removed",
        nft-contract: nft-contract,
        token-id: token-id,
        seller: seller
    })
)

(define-private (log-nft-purchased (nft-contract principal) (token-id uint) (price uint) (seller principal) (buyer principal) (fee uint))
    (print {
        event: "nft-purchased",
        nft-contract: nft-contract,
        token-id: token-id,
        price: price,
        seller: seller,
        buyer: buyer,
        platform-fee: fee
    })
)

(define-private (log-fee-updated (old-fee uint) (new-fee uint))
    (print {
        event: "fee-updated",
        old-fee: old-fee,
        new-fee: new-fee,
        updated-by: tx-sender
    })
)

(define-private (log-admin-added (new-admin principal))
    (print {
        event: "admin-added",
        admin: new-admin,
        added-by: tx-sender
    })
)

(define-private (log-admin-removed (removed-admin principal))
    (print {
        event: "admin-removed",
        admin: removed-admin,
        removed-by: tx-sender
    })
)

(define-private (log-price-range-updated (old-min uint) (old-max uint) (new-min uint) (new-max uint))
    (print {
        event: "price-range-updated",
        old-min-price: old-min,
        old-max-price: old-max,
        new-min-price: new-min,
        new-max-price: new-max,
        updated-by: tx-sender
    })
)

;; Admin management functions
(define-read-only (is-admin (address principal))
    (default-to false (map-get? admins address))
)

(define-private (assert-is-admin)
    (ok (asserts! (is-admin tx-sender) err-not-admin))
)

(define-public (add-admin (new-admin principal))
    (begin
        (try! (assert-is-admin))
        (asserts! (not (is-admin new-admin)) err-already-admin)
        (map-set admins new-admin true)
        (log-admin-added new-admin)
        (ok true)
    )
)

(define-public (remove-admin (admin-to-remove principal))
    (begin
        (try! (assert-is-admin))
        (asserts! (not (is-eq admin-to-remove contract-owner)) err-cannot-remove-owner)
        (asserts! (is-admin admin-to-remove) err-not-admin)
        (map-delete admins admin-to-remove)
        (log-admin-removed admin-to-remove)
        (ok true)
    )
)

;; Price range management functions
(define-read-only (get-price-range)
    (ok {
        min-price: (var-get min-price),
        max-price: (var-get max-price)
    })
)

(define-public (set-price-range (new-min uint) (new-max uint))
    (begin
        (try! (assert-is-admin))
        ;; Ensure new min is less than new max
        (asserts! (< new-min new-max) err-invalid-price-range)
        ;; Store old values for event logging
        (let (
            (old-min (var-get min-price))
            (old-max (var-get max-price))
        )
            ;; Update values
            (var-set min-price new-min)
            (var-set max-price new-max)
            ;; Log the changes
            (log-price-range-updated old-min old-max new-min new-max)
            (ok true)
        )
    )
)

;; Read-only functions
(define-read-only (get-listing (nft-contract principal) (token-id uint))
    (map-get? listings { nft-contract: nft-contract, token-id: token-id })
)

(define-read-only (get-platform-fee)
    (var-get platform-fee)
)

(define-read-only (is-valid-price (price uint))
    (and 
        (>= price (var-get min-price)) 
        (<= price (var-get max-price))
    )
)

;; Private functions
(define-private (check-nft-validity (nft-contract <nft-trait>) (token-id uint))
    (match (contract-call? nft-contract get-last-token-id)
        success (ok (>= success token-id))
        error (err error)
    )
)

;; Public functions
(define-public (list-nft (nft-contract <nft-trait>) (token-id uint) (price uint))
    (begin
        (asserts! (is-valid-price price) err-invalid-price)
        (try! (check-nft-validity nft-contract token-id))
        
        (let (
            (owner-response (try! (contract-call? nft-contract get-owner token-id)))
            (owner (unwrap! owner-response err-token-not-found))
        )
            (asserts! (is-eq tx-sender owner) err-not-owner)
            (asserts! (is-none (get-listing (contract-of nft-contract) token-id)) err-already-listed)
            (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
            
            (log-listing-created (contract-of nft-contract) token-id price tx-sender)
            
            (ok (map-set listings
                { nft-contract: (contract-of nft-contract), token-id: token-id }
                { price: price, seller: tx-sender }
            ))
        )
    )
)

(define-public (unlist-nft (nft-contract <nft-trait>) (token-id uint))
    (begin
        (try! (check-nft-validity nft-contract token-id))
        
        (let (
            (listing (unwrap! (get-listing (contract-of nft-contract) token-id) err-not-listed))
        )
            (asserts! (is-eq (get seller listing) tx-sender) err-not-owner)
            (try! (as-contract (contract-call? nft-contract transfer token-id (as-contract tx-sender) tx-sender)))
            
            (log-listing-removed (contract-of nft-contract) token-id tx-sender)
            
            (ok (map-delete listings { nft-contract: (contract-of nft-contract), token-id: token-id }))
        )
    )
)

(define-public (buy-nft (nft-contract <nft-trait>) (token-id uint) (price uint))
    (begin
        (try! (check-nft-validity nft-contract token-id))
        
        (let (
            (listing (unwrap! (get-listing (contract-of nft-contract) token-id) err-not-listed))
            (seller (get seller listing))
            (list-price (get price listing))
            (fee (/ (* price (var-get platform-fee)) u1000))
        )
            (asserts! (is-eq price list-price) err-wrong-price)
            (asserts! (is-valid-price price) err-invalid-price)
            (try! (stx-transfer? (- price fee) tx-sender seller))
            (try! (stx-transfer? fee tx-sender contract-owner))
            (try! (as-contract (contract-call? nft-contract transfer token-id (as-contract tx-sender) tx-sender)))
            
            (log-nft-purchased (contract-of nft-contract) token-id price seller tx-sender fee)
            
            (ok (map-delete listings { nft-contract: (contract-of nft-contract), token-id: token-id }))
        )
    )
)

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
    (begin
        (try! (assert-is-admin))
        (asserts! (<= new-fee max-fee) err-invalid-fee)
        
        (log-fee-updated (var-get platform-fee) new-fee)
        
        (ok (var-set platform-fee new-fee))
    )
)