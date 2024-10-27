import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mocking contract calls and environment setup
const mockContractCall = vi.fn();
const mockStxTransfer = vi.fn();
const mockPlatformFee = vi.fn(() => 25); // 2.5%
const clarity = {
  call: mockContractCall,
  transferStx: mockStxTransfer,
  getPlatformFee: mockPlatformFee,
};

// Sample setup data for tests
const nftContractPrincipal = 'ST1234NFTCONTRACT';
const validTokenId = 1;
const invalidTokenId = 9999;
const price = 5000;
const seller = 'STSELLER1';
const buyer = 'STBUYER1';
const minPrice = 1000;
const maxPrice = 100000;
const platformOwner = 'STOWNER';
const newFee = 50;
const feePercentage = 2.5;

describe('NFT Marketplace Contract', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Listing NFTs', () => {
    it('should allow the owner to list an NFT at a valid price', async () => {
      // Arrange
      mockContractCall.mockResolvedValueOnce({ ok: { value: seller } }); // Owner check
      mockContractCall.mockResolvedValueOnce({ ok: true }); // Transfer NFT to marketplace

      // Act
      const result = await mockContractCall('list-nft', [
        nftContractPrincipal,
        validTokenId,
        price,
      ]);

      // Assert
      expect(result.ok).toBe(true);
      expect(mockContractCall).toHaveBeenNthCalledWith(1,
        'get-owner',
        [nftContractPrincipal, validTokenId]
      );
      expect(mockContractCall).toHaveBeenNthCalledWith(2,
        'transfer',
        [nftContractPrincipal, validTokenId, seller, 'marketplace']
      );
    });

    it('should prevent listing if price is below the minimum', async () => {
      // Arrange
      const lowPrice = minPrice - 1;
      mockContractCall.mockResolvedValueOnce({ error: 'err-invalid-price' });

      // Act
      const result = await mockContractCall('list-nft', [
        nftContractPrincipal,
        validTokenId,
        lowPrice,
      ]);

      // Assert
      expect(result.error).toBe('err-invalid-price');
    });

    it('should prevent non-owner from listing the NFT', async () => {
      // Arrange
      mockContractCall.mockResolvedValueOnce({ ok: { value: 'STOTHER' } });
      mockContractCall.mockResolvedValueOnce({ error: 'err-not-owner' });

      // Act
      const result = await mockContractCall('list-nft', [
        nftContractPrincipal,
        validTokenId,
        price,
      ]);

      // Assert
      expect(result.error).toBe('err-not-owner');
    });
  });

  describe('Unlisting NFTs', () => {
    it('should allow the owner to unlist an active listing', async () => {
      // Arrange
      mockContractCall.mockResolvedValueOnce({ ok: { seller, price } }); // Get listing
      mockContractCall.mockResolvedValueOnce({ ok: true }); // NFT transfer back to seller

      // Act
      const result = await mockContractCall('unlist-nft', [
        nftContractPrincipal,
        validTokenId,
      ]);

      // Assert
      expect(result.ok).toBe(true);
      expect(mockContractCall).toHaveBeenNthCalledWith(2,
        'transfer',
        [nftContractPrincipal, validTokenId, 'marketplace', seller]
      );
    });

    it('should prevent unlisting by non-owner', async () => {
      // Arrange
      mockContractCall.mockResolvedValueOnce({ ok: { seller: 'STOTHER', price } });
      mockContractCall.mockResolvedValueOnce({ error: 'err-not-owner' });

      // Act
      const result = await mockContractCall('unlist-nft', [
        nftContractPrincipal,
        validTokenId,
      ]);

      // Assert
      expect(result.error).toBe('err-not-owner');
    });
  });

  describe('Purchasing NFTs', () => {
    it('should allow the purchase of an NFT at the listed price', async () => {
      // Arrange
      const platformFee = Math.floor((price * feePercentage) / 100);
      mockContractCall.mockResolvedValueOnce({ ok: { seller, price } }); // Get listing
      mockStxTransfer.mockResolvedValueOnce({ ok: true }); // STX transfer to seller
      mockStxTransfer.mockResolvedValueOnce({ ok: true }); // STX transfer for platform fee
      mockContractCall.mockResolvedValueOnce({ ok: true }); // NFT transfer to buyer

      // Act
      const result = await mockContractCall('buy-nft', [
        nftContractPrincipal,
        validTokenId,
        price,
      ]);

      // Assert
      expect(result.ok).toBe(true);
      expect(mockStxTransfer).toHaveBeenCalledWith(price - platformFee, buyer, seller);
      expect(mockStxTransfer).toHaveBeenCalledWith(platformFee, buyer, platformOwner);
      expect(mockContractCall).toHaveBeenCalledWith(
        'transfer',
        [nftContractPrincipal, validTokenId, 'marketplace', buyer]
      );
    });

    it('should reject purchase if the price is incorrect', async () => {
      // Arrange
      const incorrectPrice = price + 1;
      mockContractCall.mockResolvedValueOnce({ ok: { seller, price } });
      mockContractCall.mockResolvedValueOnce({ error: 'err-wrong-price' });

      // Act
      const result = await mockContractCall('buy-nft', [
        nftContractPrincipal,
        validTokenId,
        incorrectPrice,
      ]);

      // Assert
      expect(result.error).toBe('err-wrong-price');
    });
  });

  describe('Admin: Setting Platform Fee', () => {
    it('should allow contract owner to update the platform fee', async () => {
      // Arrange
      mockContractCall.mockResolvedValueOnce({ ok: true });
      mockPlatformFee.mockReturnValueOnce(newFee);

      // Act
      const result = await mockContractCall('set-platform-fee', [newFee]);

      // Assert
      expect(result.ok).toBe(true);
      expect(mockPlatformFee).toHaveBeenCalledWith(newFee);
    });

    it('should reject fee updates by non-owner', async () => {
      // Arrange
      const nonOwner = 'STNOTOWNER';
      mockContractCall.mockResolvedValueOnce({ error: 'err-not-owner' });

      // Act
      const result = await mockContractCall('set-platform-fee', [newFee], { sender: nonOwner });

      // Assert
      expect(result.error).toBe('err-not-owner');
    });

    it('should reject invalid platform fees', async () => {
      // Arrange
      const invalidFee = maxPrice + 1;
      mockContractCall.mockResolvedValueOnce({ error: 'err-invalid-fee' });

      // Act
      const result = await mockContractCall('set-platform-fee', [invalidFee]);

      // Assert
      expect(result.error).toBe('err-invalid-fee');
    });
  });
});