// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../governance/InitializableOwner.sol";
import "../base/BasicMetaTransaction.sol";
import "../interfaces/IDsgNft.sol";

contract TribeTickets is InitializableOwner, BasicMetaTransaction {
    using SafeMath for uint256;

    ERC20 _tickets_fragment;
    uint256 public _price;
    IDsgNft _ticketNFT;

    uint256 public max_tickets;

    constructor() public {
        max_tickets = 10000;
    }

    function initialize(
        ERC20 _token,
        IDsgNft nft,
        uint256 price
    ) public {
        super._initialize();
        _tickets_fragment = _token;
        _ticketNFT = nft;
        _price = price;
        max_tickets = 10000;
    }

    function settingPrice(uint256 price) public onlyOwner returns (bool) {
        _price = price;
        return true;
    }

    function setMaxTickets(uint256 max) public onlyOwner returns (bool) {
        max_tickets = max;
        return true;
    }

    function ExchangeTicketsNFT(uint256 amount) public returns (bool) {
        uint256 old_balance = _tickets_fragment.balanceOf(address(this));
        _tickets_fragment.transferFrom(msgSender(), address(this), amount);
        uint256 new_balance = _tickets_fragment.balanceOf(address(this));
        // real amount;
        uint256 balance = new_balance.sub(old_balance);

        uint256 num = balance.div(_price);

        for (uint256 i = 0; i < num; i++) {
            _ticketNFT.mint(
                msg.sender,
                "tribe ticket nft",
                0,
                0,
                "DSGADB",
                address(this)
            );
        }
        max_tickets = max_tickets.sub(num);

        return true;
    }
}
