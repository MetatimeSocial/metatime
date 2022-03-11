// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../governance/InitializableOwner.sol";

contract TribeNFT is ERC721, InitializableOwner, ReentrancyGuard {
    event Minted(
        uint256 indexed id,
        address to,
        string name,
        string info,
        string res,
        address author,
        uint256 endTime,
        uint256 timestamp
    );

    struct NFTInfo {
        string name;
        string info;
        string res;
        address author;
        uint256 endTime;
    }

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;

    string private _baseURIVar;
    uint256 private _tokenId = 1000;

    mapping(uint256 => NFTInfo) private _nfts;

    constructor() public ERC721("Social Tribe NFT", "STN") {}

    function initialize() public {
        super._initialize();
        _tokenId = 1000;
    }

    function baseURI() public view override returns (string memory) {
        return _baseURIVar;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        _baseURIVar = uri;
    }

    function mint(
        address to,
        string memory nftName,
        string memory info,
        string memory res,
        address author,
        uint256 endTime
    ) public onlyMinter nonReentrant returns (uint256 tokenId) {
        return _doMint(to, nftName, info, res, author, endTime);
    }

    function _doMint(
        address to,
        string memory nftName,
        string memory info,
        string memory res,
        address author,
        uint256 endTime
    ) internal returns (uint256) {
        _tokenId++;

        if (bytes(nftName).length == 0) {
            nftName = name();
        }

        _mint(to, _tokenId);

        NFTInfo storage _nft_info = _nfts[_tokenId];
        _nft_info.name = nftName;
        _nft_info.info = info;
        _nft_info.res = res;
        _nft_info.author = author;
        _nft_info.endTime = endTime;

        emit Minted(
            _tokenId,
            to,
            nftName,
            info,
            res,
            author,
            endTime,
            block.timestamp
        );

        return _tokenId;
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    // modifier for mint function
    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

    function addMinter(address _addMinter) public onlyOwner returns (bool) {
        require(
            _addMinter != address(0),
            "Token: _addMinter is the zero address"
        );
        return EnumerableSet.add(_minters, _addMinter);
    }

    function delMinter(address _delMinter) public onlyOwner returns (bool) {
        require(
            _delMinter != address(0),
            "Token: _delMinter is the zero address"
        );
        return EnumerableSet.remove(_minters, _delMinter);
    }
}
