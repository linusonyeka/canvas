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

;; Price constraints
(define-constant min-price u1000) ;; Minimum price in uSTX (micro STX)
(define-constant max-price u100000000000) ;; Maximum price in uSTX
(define-constant max-fee u100) ;; Maximum platform fee (10%)

;; Data variables
(define-data-var platform-fee uint u25) ;; 2.5% fee
(define-map listings 
    { nft-contract: principal, token-id: uint }
    { price: uint, seller: principal }
)

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

;; Read-only functions
(define-read-only (get-listing (nft-contract principal) (token-id uint))
    (map-get? listings { nft-contract: nft-contract, token-id: token-id })
)

(define-read-only (get-platform-fee)
    (var-get platform-fee)
)

(define-read-only (is-valid-price (price uint))
    (and (>= price min-price) (<= price max-price))
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
        ;; Check price validity
        (asserts! (is-valid-price price) err-invalid-price)
        ;; Check token validity
        (try! (check-nft-validity nft-contract token-id))
        
        (let (
            (owner-response (try! (contract-call? nft-contract get-owner token-id)))
            (owner (unwrap! owner-response err-token-not-found))
        )
            (asserts! (is-eq tx-sender owner) err-not-owner)
            (asserts! (is-none (get-listing (contract-of nft-contract) token-id)) err-already-listed)
            (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
            
            ;; Log the listing creation event
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
        ;; Check token validity
        (try! (check-nft-validity nft-contract token-id))
        
        (let (
            (listing (unwrap! (get-listing (contract-of nft-contract) token-id) err-not-listed))
        )
            (asserts! (is-eq (get seller listing) tx-sender) err-not-owner)
            (try! (as-contract (contract-call? nft-contract transfer token-id (as-contract tx-sender) tx-sender)))
            
            ;; Log the listing removal event
            (log-listing-removed (contract-of nft-contract) token-id tx-sender)
            
            (ok (map-delete listings { nft-contract: (contract-of nft-contract), token-id: token-id }))
        )
    )
)

(define-public (buy-nft (nft-contract <nft-trait>) (token-id uint) (price uint))
    (begin
        ;; Check token validity
        (try! (check-nft-validity nft-contract token-id))
        
        (let (
            (listing (unwrap! (get-listing (contract-of nft-contract) token-id) err-not-listed))
            (seller (get seller listing))
            (list-price (get price listing))
            (fee (/ (* price (var-get platform-fee)) u1000))
        )
            (asserts! (is-eq price list-price) err-wrong-price)
            (asserts! (is-valid-price price) err-invalid-price)
            ;; Transfer STX payment to seller
            (try! (stx-transfer? (- price fee) tx-sender seller))
            ;; Transfer platform fee
            (try! (stx-transfer? fee tx-sender contract-owner))
            ;; Transfer NFT to buyer
            (try! (as-contract (contract-call? nft-contract transfer token-id (as-contract tx-sender) tx-sender)))
            
            ;; Log the purchase event
            (log-nft-purchased (contract-of nft-contract) token-id price seller tx-sender fee)
            
            (ok (map-delete listings { nft-contract: (contract-of nft-contract), token-id: token-id }))
        )
    )
)

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (asserts! (<= new-fee max-fee) err-invalid-fee)
        
        ;; Log the fee update event
        (log-fee-updated (var-get platform-fee) new-fee)
        
        (ok (var-set platform-fee new-fee))
    )
)