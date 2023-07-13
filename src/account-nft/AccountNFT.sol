// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract AccountNFT is ERC721, Ownable {
    constructor() ERC721("Zaros Accounts", "ZRS-ACC") { }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }
}
