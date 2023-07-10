// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * @title Module with custom NFT logic for the account token.
 */
// solhint-disable-next-line no-empty-blocks
interface IAccountTokenModule {
    function mint(address to, uint256 tokenId) external;
}
