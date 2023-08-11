// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { ERC721, ERC721Enumerable } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract AccountNFT is ERC721Enumerable, Ownable {
    constructor() ERC721("Zaros Accounts", "ZRS-ACC") { }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    function isApprovedOrOwner(address spender, uint256 tokenId) external view virtual returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }
}
