// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../governance/InitializableOwner.sol";
import "../interfaces/IBurnableERC20.sol";
import "../base/BasicMetaTransaction.sol";
import "../pools/MutiRewardPool.sol";

contract CashierDesk is InitializableOwner, BasicMetaTransaction {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

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

    event WithdrawToMutiRewardPool(
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

    mapping(address => uint256) public total_charge;
    mapping(address => uint256) public total_burn;

    // switch chain token.
    bool public allow_chain;

    constructor() public {
        initialize();
    }

    function initialize() public {
        super._initialize();
    }

    modifier onlyCaller() {
        require(_admin.contains(msgSender()) == true, "only caller.");
        _;
    }

    function addSupportToken(address token) public onlyOwner returns (bool) {
        require(token != address(0), "address is zero");
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

    function listAdmin() public view onlyOwner returns (address[] memory) {
        uint256 len = _admin.length();
        address[] memory ls = new address[](len);

        for (uint256 i = 0; i < len; ++i) {
            ls[i] = _admin.at(i);
        }
        return ls;
    }

    function chargeToken(address token, uint256 amount) public returns (bool) {
        require(_support_token.contains(token) == true, "cant support token.");

        IERC20 erc20 = IERC20(token);

        uint256 oldBal = erc20.balanceOf(address(this));
        erc20.safeTransferFrom(msgSender(), address(this), amount);
        amount = erc20.balanceOf(address(this)).sub(oldBal);

        total_charge[token] += amount;
        emit ChargeToken(msgSender(), token, amount, block.timestamp);

        return true;
    }

    function chargeChainToken() public payable returns (bool) {
        require(allow_chain == true, "dont allow.");
        require(msg.value > 0 , "value > 0.");
        // use 0x0000000000000000000000000000000000000001 .
        emit ChargeToken(msgSender(), address(1), msg.value, block.timestamp);
        return true;
    }

    function set_allow_chain(bool allow) public onlyOwner returns (bool) {
        allow_chain = allow;
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
            erc20.safeTransfer(users[i], values[i]);

            emit WithdrawToken(users[i], token, values[i], block.timestamp);
        }
        return true;
    }

    function WithdrawChain(address[] memory users, uint256[] memory values)
        public
        payable
        onlyCaller
        returns (bool)
    {
        require(allow_chain == true, "dont allow.");
        for (uint256 i = 0; i < users.length; i++) {
            address to_address = users[i];
            (bool success, ) = to_address.call{value: values[i]}("");
            require(success, "withdraw failed.");

            emit WithdrawToken(
                users[i],
                address(1),
                values[i],
                block.timestamp
            );
        }
        return true;
    }

    function burnToken(address token, uint256 total)
        public
        onlyCaller
        returns (bool)
    {
        require(_support_token.contains(token) == true, "cant support token.");

        IBurnableERC20 erc20 = IBurnableERC20(token);

        total_burn[token] += total;
        erc20.burn(total);
        return true;
    }

    function withdrawToMutiRewardPool(
        address token,
        address mulPool,
        uint256 amount,
        uint256 blockNumber
    ) public onlyCaller returns (bool) {
        require(_support_token.contains(token) == true, "cant support token.");

        IERC20 erc20 = IERC20(token);
        erc20.approve(address(mulPool), amount);

        MutiRewardPool pool = MutiRewardPool(mulPool);
        pool.addAdditionalRewards(erc20, amount, blockNumber);

        emit WithdrawToMutiRewardPool(
            msgSender(),
            token,
            amount,
            block.timestamp
        );
        return true;
    }
}
