// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../governance/InitializableOwner.sol";

contract RewardTheAuthor is InitializableOwner {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct UserView {
        address[] tokens; // The token corresponding to the following value
        uint256[] pendingAmounts; // Amount of reward to be claimed
        uint256[] claimedAmounts; // Amount of rewards claimed
    }

    event Reward(
        uint256 indexed id,
        address indexed from,
        address indexed target,
        address token,
        uint256 postType,
        uint64 postId,
        uint256 amount,
        uint timestamp
    );
    event Claim(address indexed user, address token, uint256 amount);

    mapping(address => mapping(address => uint256)) private _userRewards; // user:token:amount
    mapping(address => mapping(address => uint256)) private _userClaimedRewards; // user:token:amount

    EnumerableSet.AddressSet private _supportTokens;
    uint256 _rewardId;

    constructor() public {}

    function initialize(address[] memory supportTokens) public {
        super._initialize();

        for (uint256 i = 0; i < supportTokens.length; ++i) {
            _supportTokens.add(supportTokens[i]);
        }
    }

    function addSupportToken(address token) public onlyOwner {
        require(token != address(0), "address is zero");
        require(!_supportTokens.contains(token), "already added");

        _supportTokens.add(token);
    }

    function delSupportToken(address token) public onlyOwner {
        require(_supportTokens.contains(token), "not added");

        _supportTokens.remove(token);
    }

    function isSupportToken(address token) public view returns (bool) {
        return _supportTokens.contains(token);
    }

    function getSupportTokens() public view returns (address[] memory ls) {
        uint256 len = _supportTokens.length();
        if (len == 0) {
            return ls;
        }

        ls = new address[](len);
        for (uint256 i = 0; i < len; ++i) {
            ls[i] = _supportTokens.at(i);
        }
        return ls;
    }

    /**
     * @dev Reward the designated author
     * @param target the author
     * @param token the token to be rewarded
     * @param postType the post type
     * @param postId the post id
     * @param amount Amount to be rewarded
     */
    function reward(
        address target,
        IERC20 token,
        uint256 postType,
        uint64 postId,
        uint256 amount
    ) public {
        require(_supportTokens.contains(address(token)), "Unsupported token");

        uint256 oldBal = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        amount = token.balanceOf(address(this)).sub(oldBal);

        uint256 pending = _userRewards[msg.sender][address(token)];
        _userRewards[msg.sender][address(token)] = pending.add(amount);

        _rewardId++;

        emit Reward(
            _rewardId,
            msg.sender,
            target,
            address(token),
            postType,
            postId,
            amount,
            block.timestamp
        );
    }

    function claim(address token) public {
        uint256 pending = _userRewards[msg.sender][token];
        if (pending == 0) return;

        _userRewards[msg.sender][token] = 0;
        _userClaimedRewards[msg.sender][address(token)] = _userClaimedRewards[msg.sender][address(token)].add(pending);

        IERC20(token).safeTransfer(msg.sender, pending);

        emit Claim(msg.sender, token, pending);
    }

    function claimAll() public {
        address[] memory supportTokens = getSupportTokens();

        for (uint256 i = 0; i < supportTokens.length; ++i) {
            claim(supportTokens[i]);
        }
    }

    function getUserView(address user) public view returns (UserView memory) {
        address[] memory supportTokens = getSupportTokens();
        uint256[] memory pendingAmounts = new uint256[](supportTokens.length);
        uint256[] memory claimedAmounts = new uint256[](supportTokens.length);

        for (uint256 i = 0; i < supportTokens.length; ++i) {
            pendingAmounts[i] = _userRewards[user][supportTokens[i]];
            claimedAmounts[i] = _userClaimedRewards[user][supportTokens[i]];
        }

        return
            UserView({
                tokens: supportTokens,
                pendingAmounts: pendingAmounts,
                claimedAmounts: claimedAmounts
            });
    }
}
