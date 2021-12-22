// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

interface IUserProfile {
    function checkNickname(string memory nickname) external view returns (bool);
    function createProfile(string memory nickname, address nftAddress, uint256 tokenID, address superior) external;
    function createProfileToUser(address to, string memory nickname, address nftAddress, uint256 tokenID, address superior) external;
    function withdraw() external returns(bool);
    function replaceNFT(address toNFT, uint256 tokenID) external returns(bool);
    function updateNickname(string memory nickname) external;
    function getSupportNFT() external view returns(address[] memory sup);
    function pauseUser(address user) external;
    function reactivateUser(address user) external;
    function getUserView(address user) external view returns(string memory nickname, address nftAddress, uint256 tokenId, bool isAcctive, address superior);
}