// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { ILiquidityEngine } from "@zaros/liquidity/interfaces/ILiquidityEngine.sol";

// Open Zeppelin dependencies
import { ERC721, ERC721Enumerable } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract AccountNFT is ERC721Enumerable, Ownable {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) { }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    )
        internal
        virtual
        override
    {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);

        ILiquidityEngine(owner()).notifyAccountTransfer(to, uint128(firstTokenId));
    }
}
