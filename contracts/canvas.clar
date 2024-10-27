;; NFT Marketplace - Canvas
;; A decentralized marketplace for trading NFTs on Stacks blockchain

(define-data-var contract-owner principal tx-sender)
(define-map listings 
    { nft-id: uint, seller: principal } 
    { price: uint, is-active: bool })
(define-map sales
    { nft-id: uint }
    { buyer: principal, price: uint, timestamp: uint })

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-LISTING-NOT-FOUND (err u101))
(define-constant ERR-LISTING-NOT-ACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))

;; List an NFT for sale
(define-public (list-nft (nft-id uint) (price uint))
    (let ((seller tx-sender))
        (asserts! (is-eq (nft-get-owner? nft-id) (some seller)) ERR-NOT-AUTHORIZED)
        (map-set listings 
            { nft-id: nft-id, seller: seller }
            { price: price, is-active: true })
        (ok true)))

;; Cancel listing
(define-public (cancel-listing (nft-id uint))
    (let ((listing (map-get? listings { nft-id: nft-id, seller: tx-sender })))
        (asserts! (is-some listing) ERR-LISTING-NOT-FOUND)
        (map-set listings 
            { nft-id: nft-id, seller: tx-sender }
            { price: u0, is-active: false })
        (ok true)))

;; Purchase NFT
(define-public (purchase-nft (nft-id uint))
    (let ((listing (map-get? listings { nft-id: nft-id, seller: tx-sender }))
          (buyer tx-sender))
        (match listing
            l (begin
                (asserts! (get is-active l) ERR-LISTING-NOT-ACTIVE)
                (asserts! (>= (stx-get-balance buyer) (get price l)) ERR-INSUFFICIENT-FUNDS)
                ;; Transfer STX to seller
                (try! (stx-transfer? (get price l) buyer (get seller listing)))
                ;; Transfer NFT to buyer
                (try! (nft-transfer? nft-id (get seller listing) buyer))
                ;; Record sale
                (map-set sales 
                    { nft-id: nft-id }
                    { buyer: buyer, 
                      price: (get price l), 
                      timestamp: block-height })
                ;; Deactivate listing
                (map-set listings 
                    { nft-id: nft-id, seller: (get seller listing) }
                    { price: u0, is-active: false })
                (ok true)))
            ERR-LISTING-NOT-FOUND))

;; Get listing details
(define-read-only (get-listing (nft-id uint) (seller principal))
    (map-get? listings { nft-id: nft-id, seller: seller }))

;; Get sale details
(define-read-only (get-sale (nft-id uint))
    (map-get? sales { nft-id: nft-id }))

;; Update listing price
(define-public (update-listing-price (nft-id uint) (new-price uint))
    (let ((listing (map-get? listings { nft-id: nft-id, seller: tx-sender })))
        (asserts! (is-some listing) ERR-LISTING-NOT-FOUND)
        (asserts! (get is-active listing) ERR-LISTING-NOT-ACTIVE)
        (map-set listings 
            { nft-id: nft-id, seller: tx-sender }
            { price: new-price, is-active: true })
        (ok true)))