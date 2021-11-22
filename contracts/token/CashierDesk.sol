// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../governance/InitializableOwner.sol";
import "../interfaces/IBurnableERC20.sol";

contract CashierDesk is InitializableOwner {
    using SafeERC20 for IERC20;

    event ChargeToken(
        address indexed sender,
        address indexed token,
        uint256 value,
        uint256 timestamp
    );
    
    event WithdrawToken(
        address indexed sender,
        address indexed token,
        uint256 value,
        uint256 timestamp
    );

    event UserCostToken(
        address indexed sender,
        address indexed token,
        uint256 value,
        uint256 timestamp
    );

    event AddSupportToken(address Token, uint256 timestamp);

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _admin;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _support_token;

    // user => token => amount;
    mapping(address => mapping(address => uint256)) public _balanceOf;

    constructor() public {
        initialize();
    }

    function initialize() public {
        super._initialize();
    }

    modifier onlyCaller() {
        require(_admin.contains(msg.sender) == true, "only caller.");
        _;
    }

    function addSupportToken(address token) public onlyOwner returns (bool) {
        require(_support_token.contains(token) == false, "ready support.");
        _support_token.add(token);

        emit AddSupportToken(token, block.timestamp);

        return true;
    }

    function addAdmin(address ad) public onlyOwner returns (bool) {
        _admin.add(ad);
    }

    function removeAdmin(address ad) public onlyOwner returns (bool) {
        _admin.remove(ad);
    }

    function chargeToken(address token, uint256 amount) public returns (bool) {
        require(_support_token.contains(token) == true, "cant support token.");

        IERC20 erc20 = IERC20(token);

        erc20.safeTransferFrom(msg.sender, address(this), amount);

        _balanceOf[msg.sender][token] += amount;

        emit ChargeToken(msg.sender, token, amount, block.timestamp);

        return true;
    }

    function Withdraw(
        address token,
        address[] memory users,
        uint256[] memory values
    ) public onlyCaller returns (bool) {
        require(_support_token.contains(token) == true, "cant support token.");
        require(users.length == values.length, "bad length");

        IERC20 erc20 = IERC20(token);

        for (uint256 i = 0; i < users.length; i++) {
            require(
                _balanceOf[users[i]][token] >= values[i],
                "enougth amount."
            );

            _balanceOf[users[i]][token] -= values[i];
            erc20.safeTransfer(users[i], values[i]);

            emit WithdrawToken(users[i], token, values[i], block.timestamp);
        }
        return true;
    }

    function burnToken(
        address token,
        address[] memory users,
        uint256[] memory values
    ) public onlyCaller returns (bool) {
        require(_support_token.contains(token) == true, "cant support token.");
        require(users.length == values.length, "bad length");

        IBurnableERC20 erc20 = IBurnableERC20(token);

        uint256 total_burn = 0;
        for (uint256 i = 0; i < users.length; i++) {
            require(
                _balanceOf[users[i]][token] >= values[i],
                "enougth amount."
            );

            _balanceOf[users[i]][token] -= values[i];
            total_burn += values[i];

            emit UserCostToken(users[i], token, values[i], block.timestamp);
        }

        erc20.burn(total_burn);
        return true;
    }
}
