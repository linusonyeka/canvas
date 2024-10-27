# Canvas - NFT Marketplace

A decentralized NFT marketplace built on the Stacks blockchain, enabling users to list, buy, and sell NFTs using STX tokens.

## 🌟 Features

- List NFTs for sale with custom pricing
- Purchase NFTs using STX tokens
- Cancel active listings
- Update listing prices
- View detailed listing information
- Track sales history
- Secure ownership verification
- Automated STX and NFT transfers

## 📋 Prerequisites

- [Stacks Wallet](https://www.hiro.so/wallet)
- [Clarinet](https://github.com/hirosystems/clarinet) for local development
- Basic understanding of Clarity smart contracts

## 🚀 Getting Started

1. Clone the repository:
```bash
git clone https://github.com/yourusername/stackart-exchange.git
cd stackart-exchange
```

2. Install dependencies:
```bash
clarinet install
```

3. Test the smart contract:
```bash
clarinet test
```

## 📝 Smart Contract Functions

### List NFT
```clarity
(list-nft (nft-id uint) (price uint))
```
Lists an NFT for sale at the specified price.

### Purchase NFT
```clarity
(purchase-nft (nft-id uint))
```
Purchases a listed NFT by transferring STX to the seller.

### Cancel Listing
```clarity
(cancel-listing (nft-id uint))
```
Cancels an active NFT listing.

### Update Listing Price
```clarity
(update-listing-price (nft-id uint) (new-price uint))
```
Updates the price of an active listing.

### View Functions
```clarity
(get-listing (nft-id uint) (seller principal))
(get-sale (nft-id uint))
```
Retrieve listing and sale information.

## 🔒 Security Features

- Ownership verification before listing
- Balance checks before purchase
- Atomic transactions for safe transfers
- Principal-based authorization

## 🛣️ Roadmap

- [ ] Implement bidding system
- [ ] Add creator royalties
- [ ] Enable bulk operations
- [ ] Implement time-limited auctions
- [ ] Add collection-specific features
- [ ] Integrate with popular NFT standards

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 📜 Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: User not authorized for the operation
- `ERR-LISTING-NOT-FOUND (u101)`: Listing does not exist
- `ERR-LISTING-NOT-ACTIVE (u102)`: Listing is not active
- `ERR-INSUFFICIENT-FUNDS (u103)`: Insufficient STX balance for purchase

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

- Discord: [Join our community](#)
- Twitter: [@StackArtExchange](#)
- Email: support@stackartexchange.com

## 🙏 Acknowledgments

- Stacks Foundation
- Hiro Systems
- NFT Community

---
Built with ❤️ for the Stacks ecosystem