;; Define SIP-009 NFT trait
(define-trait nft-trait
    (
        ;; Last token ID, limited to uint range
        (get-last-token-id () (response uint uint))
        
        ;; URI for token metadata
        (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
        
        ;; Owner of a token
        (get-owner (uint) (response (optional principal) uint))
        
        ;; Transfer token
        (transfer (uint principal principal) (response bool uint))
    )
)

;; NFT Marketplace Contract
;; Allows users to list, buy, and delist NFTs

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-listed (err u101))
(define-constant err-wrong-price (err u102))
(define-constant err-already-listed (err u103))
(define-constant err-token-not-found (err u104))

;; Define data variables
(define-data-var platform-fee uint u25) ;; 2.5% fee
(define-map listings 
    { nft-contract: principal, token-id: uint }
    { price: uint, seller: principal }
)

;; Read-only functions
(define-read-only (get-listing (nft-contract principal) (token-id uint))
    (map-get? listings { nft-contract: nft-contract, token-id: token-id })
)

(define-read-only (get-platform-fee)
    (var-get platform-fee)
)

;; Public functions
(define-public (list-nft (nft-contract <nft-trait>) (token-id uint) (price uint))
    (let (
        (owner-response (try! (contract-call? nft-contract get-owner token-id)))
        (owner (unwrap! owner-response err-token-not-found))
    )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (asserts! (is-none (get-listing (contract-of nft-contract) token-id)) err-already-listed)
        (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
        (ok (map-set listings
            { nft-contract: (contract-of nft-contract), token-id: token-id }
            { price: price, seller: tx-sender }
        ))
    )
)

(define-public (unlist-nft (nft-contract <nft-trait>) (token-id uint))
    (let (
        (listing (unwrap! (get-listing (contract-of nft-contract) token-id) err-not-listed))
    )
        (asserts! (is-eq (get seller listing) tx-sender) err-not-owner)
        (try! (as-contract (contract-call? nft-contract transfer token-id (as-contract tx-sender) tx-sender)))
        (ok (map-delete listings { nft-contract: (contract-of nft-contract), token-id: token-id }))
    )
)

(define-public (buy-nft (nft-contract <nft-trait>) (token-id uint) (price uint))
    (let (
        (listing (unwrap! (get-listing (contract-of nft-contract) token-id) err-not-listed))
        (seller (get seller listing))
        (list-price (get price listing))
        (fee (/ (* price (var-get platform-fee)) u1000))
    )
        (asserts! (is-eq price list-price) err-wrong-price)
        ;; Transfer STX payment to seller
        (try! (stx-transfer? (- price fee) tx-sender seller))
        ;; Transfer platform fee
        (try! (stx-transfer? fee tx-sender contract-owner))
        ;; Transfer NFT to buyer
        (try! (as-contract (contract-call? nft-contract transfer token-id (as-contract tx-sender) tx-sender)))
        (ok (map-delete listings { nft-contract: (contract-of nft-contract), token-id: token-id }))
    )
)

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (ok (var-set platform-fee new-fee))
    )
)