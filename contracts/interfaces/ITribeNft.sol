// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ITribeNFT is IERC721 {
    function mint(
        address to,
        string memory nftName,
        string memory info,
        string memory res,
        address author,
        uint256 endTime
    ) external returns (uint256 tokenId);
}
