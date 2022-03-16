// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../governance/InitializableOwner.sol";
import "../base/BasicMetaTransaction.sol";
import "../interfaces/ITribeNft.sol";

contract Tribe is
    ERC721Holder,
    InitializableOwner,
    BasicMetaTransaction,
    ReentrancyGuard
{
    using SafeMath for uint256;

    struct TribeInfo {
        string name;
        string logo;
        string introduction;
        address feeToken;
        uint256 feeAmount;
        uint256 validDate; // day
        uint256 perTime;
        uint256 ownerPercent; // 0-100
        uint256 authorPercent; // 0-100
        uint256 memberPercent; // 0-100
        address creator;
    }

    struct TribeInfoExtra {
        address owner;
        uint256 owner_nft_id;
        uint256 invitationRate;
        bool created;
        bool claimOwnerNFT;
        bool initMemberNFT;
        bool deny;
    }

    struct TribeNftInfo {
        string ownerNFTName;
        string ownerNFTIntroduction;
        string ownerNFTImage;
        string memberNFTName;
        string memberNFTIntroduction;
        string memberNFTImage;
    }

    struct TribeNFTCreate {
        address creator;
        address user;
        uint256 startTime;
        uint256 validDate;
        address feeToken;
        uint256 feeAmount;
        uint256 tribe_id;
    }

    event CreateTribe(
        uint256 indexed createID,
        uint256 timestamp,
        TribeInfo info
    );

    // event Stake
    event StakeNFT(
        address indexed sender,
        uint256 indexed tribed_id,
        uint256 nft_id,
        uint256 timestamp
    );
    event UnStakeNFT(
        address indexed sender,
        uint256 indexed tribed_id,
        uint256 nft_id,
        uint256 timestamp
    );

    event ClaimNFT(
        address indexed sender,
        uint256 indexed tribe_id,
        uint256 nft_id,
        address fee_token,
        uint256 fee_amount,
        uint256 nft_type,
        uint256 outOfTime,
        address invitationAddress,
        uint256 rate,
        uint256 timestamp
    );

    event UpdateTribeInfo(
        address indexed sender,
        uint256 indexed tribe_id,
        string introduction
    );

    event DeleteTribeNFT(
        address indexed sender,
        uint256 indexed nft_id,
        uint256 timestamp
    );

    event UpdateTribeSetting(
        address indexed sender,
        uint256 indexed tribe_id,
        TribeInfo info
    );

    event UpdateTribeInvitation(
        address indexed sender,
        uint256 indexed tribe_id,
        uint256 indexed rate
    );

    event InitMemberNFT(
        address indexed sender,
        uint256 indexed tribe_id,
        TribeNftInfo info
    );

    /// nft address: create tribe
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private supportsNFTForCreate;

    /// token address: for join tribe.
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private supportsFeeToken;

    // π
    uint256 startID = 0x54655307;

    bool public create_switch = false;

    // tribe-id -> info
    mapping(uint256 => TribeInfo) public tribesInfo;
    // tribe-id -> extra info
    mapping(uint256 => TribeInfoExtra) public extraTribesInfo;
    // tribe-id -> tribe nft info
    mapping(uint256 => TribeNftInfo) public extraTribesNFTInfo;

    mapping(string => bool) public unique_name;

    /// nftid -> tribeid.
    mapping(uint256 => TribeNFTCreate) public nft_claim_contracts;
    /// address => tribe => nftid.
    mapping(address => mapping(uint256 => uint256)) public user_tribe_nftid;
    //
    ITribeNFT public _tribe_nft;
    // matter
    ERC20 public _matter_token;
    uint256 public _join_matter;

    constructor(address tribeNFT, address matterToken) public {
        initialize(tribeNFT, matterToken);
    }

    function initialize(address tribeNFT, address matterToken) public {
        super._initialize();
        create_switch = true;
        _tribe_nft = ITribeNFT(tribeNFT);
        _matter_token = ERC20(matterToken);
        startID = 0x54655307;
        _join_matter = 1 * (10**18);

        addSupportFeeToken(address(1));
    }

    /// create nft.
    function listViewNFTToken() public view returns (address[] memory sup) {
        uint256 length = supportsNFTForCreate.length();
        sup = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            sup[i] = supportsNFTForCreate.at(i);
        }
    }

    function addSupportCreateToken(address nftToken) public onlyOwner {
        supportsNFTForCreate.add(nftToken);
    }

    function listViewFeeToken()
        public
        view
        returns (
            address[] memory sup,
            string[] memory names,
            uint256[] memory decimals
        )
    {
        uint256 length = supportsFeeToken.length();
        sup = new address[](length);
        names = new string[](length);
        decimals = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            address sup_token = supportsFeeToken.at(i);

            if (sup_token == address(1)) {
                sup[i] = sup_token;
                names[i] = "BNB";
                decimals[i] = 18;
                continue;
            }

            ERC20 erc20_token = ERC20(sup_token);
            sup[i] = sup_token;
            names[i] = erc20_token.symbol();
            decimals[i] = erc20_token.decimals();
        }
    }

    /// fee nft.
    function addSupportFeeToken(address nftToken) public onlyOwner {
        supportsFeeToken.add(nftToken);
    }

    function removeSupportFeeToken(address token) public onlyOwner {
        if (supportsFeeToken.contains(token)){
            supportsFeeToken.remove(token);
        }
    }

    ///
    modifier canCreate() {
        require(create_switch == true, "cant create.");
        _;
    }

    modifier checkTribeOwner(uint256 tribe_id) {
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        require(extra.owner == msgSender(), "not owner.");
        _;
    }

    function supportNFT(address nft) public view returns (bool) {
        return supportsNFTForCreate.contains(nft);
    }

    function supportFeeToken(address feeToken) public view returns (bool) {
        return supportsFeeToken.contains(feeToken);
    }

    function updateJoinMatterAmount(uint256 value) public onlyOwner {
        _join_matter = value;
    }

    function denyTribe(uint256 tribe_id) public onlyOwner {
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        extra.deny = true;
    }

    /// create tribe
    function createTribe(
        string memory name,
        string memory logo,
        string memory information,
        address feeToken,
        uint256 feeAmount,
        uint256 validDate,
        uint256 perTime,
        uint256 ownerPercent,
        uint256 authorPercent,
        uint256 memberPercent,
        address nftAddress,
        uint256 nftid
    ) public canCreate {
        // pro
        if (address(_matter_token) != feeToken) {
            require(
                supportFeeToken(feeToken) == true,
                "cant support fee token."
            );
        } else {
            // basic
            require(feeAmount == 0, "feeAmount must 0.");
            require(validDate == 0, "validDate must 0.");
        }
        if (validDate > 0){
            /// 10 years
            require(validDate <= 315360000, "out of max.");
        }

        require(supportNFT(nftAddress) == true, "cant support nft token.");

        {
            require(unique_name[name] == false, "unique name.");
            bytes memory bt = bytes(name);
            require(bt.length >= 6, "out of length min.");
            require(bt.length <= 30, "out of length max.");
        }
        require(ownerPercent <= 100, "out of percent.");
        require(authorPercent <= 100, "out of percent.");
        require(memberPercent <= 100, "out of percent.");

        require(
            ownerPercent + authorPercent + memberPercent == 100,
            "error reward."
        );
        require(perTime >= 1, "out of min perTime.");
        require(perTime <= 100, "out of max perTime.");

        {
            // check nft.
            IERC721 nftToken = IERC721(nftAddress);
            require(msgSender() == nftToken.ownerOf(nftid), "error owner.");
            nftToken.safeTransferFrom(msgSender(), address(this), nftid);
        }

        {
            TribeInfoExtra storage extra = extraTribesInfo[startID];
            extra.created = true;
        }

        {
            TribeInfo storage info = tribesInfo[startID];
            info.name = name;
            info.logo = logo;
            info.introduction = information;
            info.feeToken = feeToken;
            info.feeAmount = feeAmount;
            info.validDate = validDate;
            info.perTime = perTime;
            info.ownerPercent = ownerPercent;
            info.authorPercent = authorPercent;
            info.memberPercent = memberPercent;
            info.creator = msgSender();
            emit CreateTribe(startID, block.timestamp, info);
        }

        {
            TribeNftInfo storage nftInfo = extraTribesNFTInfo[startID];
            nftInfo.ownerNFTName = "Tribe Chief NFT";
            nftInfo.ownerNFTImage = logo;
            nftInfo
                .ownerNFTIntroduction = "Own the Tribe Chief NFT you can enjoy the tribe chief rights.";
        }

        startID++;
        unique_name[name] = true;
    }

    function setTribeExtraInfo(uint256 tribe_id, string memory introduction)
        public
    {
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        require(extra.created == true, "cant find tribe.");
        require(extra.owner == msgSender(), "not owner.");

        TribeInfo storage info = tribesInfo[startID];
        info.introduction = introduction;

        emit UpdateTribeInfo(msgSender(), tribe_id, introduction);
    }

    function setTribeMemberNFT(
        uint256 tribe_id,
        string memory logo,
        string memory name,
        string memory introduction
    ) public checkTribeOwner(tribe_id) {
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        require(extra.initMemberNFT == false, "init nft.");

        TribeNftInfo storage nftInfo = extraTribesNFTInfo[tribe_id];
        nftInfo.memberNFTName = name;
        nftInfo.memberNFTImage = logo;
        nftInfo.memberNFTIntroduction = introduction;

        extra.initMemberNFT = true;

        emit InitMemberNFT(msgSender(), tribe_id, nftInfo);
    }

    function claimOwnerNFT(uint256 tribe_id) public {
        TribeInfo storage info = tribesInfo[tribe_id];
        require(info.creator == msgSender(), "not owner.");

        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        require(extra.claimOwnerNFT == false, "init nft.");

        TribeNftInfo storage nftInfo = extraTribesNFTInfo[tribe_id];

        // mint nft to.
        uint256 createdID = _tribe_nft.mint(
            msgSender(),
            "Tribe Trief NFT",
            nftInfo.ownerNFTIntroduction,
            info.logo,
            msgSender(),
            0
        );
        extra.claimOwnerNFT = true;
        extra.owner = address(0);
        extra.owner_nft_id = createdID;

        emit ClaimNFT(
            msgSender(),
            tribe_id,
            createdID,
            info.feeToken,
            0,
            1,
            0,
            address(0),
            0,
            block.timestamp
        );
    }

    /// stake
    function stakeOwnNFT(uint256 tribe_id, uint256 nft_id) public {
        //
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        require(extra.owner_nft_id == nft_id, "error nft id.");
        require(user_tribe_nftid[msgSender()][tribe_id] == 0, "ready stake member.");
        //
        IERC721 nftToken = IERC721(_tribe_nft);
        require(msgSender() == nftToken.ownerOf(nft_id), "error owner.");
        nftToken.safeTransferFrom(msgSender(), address(this), nft_id);

        extra.owner = msgSender();

        user_tribe_nftid[msgSender()][tribe_id] = nft_id;

        emit StakeNFT(msgSender(), tribe_id, nft_id, block.timestamp);
    }

    // unstake
    function unOwnStake(uint256 tribe_id) public {
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        require(extra.owner == msgSender(), "not owner.");

        extra.owner = address(0);

        IERC721 nftToken = IERC721(_tribe_nft);
        nftToken.safeTransferFrom(
            address(this),
            msgSender(),
            extra.owner_nft_id
        );
        user_tribe_nftid[msgSender()][tribe_id] = 0;

        emit UnStakeNFT(
            msgSender(),
            tribe_id,
            extra.owner_nft_id,
            block.timestamp
        );
    }

    // join
    function ClaimMemberNFT(uint256 tribe_id, address invaiteAddress)
        public
        payable
        nonReentrant
    {
        require(checkTribeCompleteStatus(tribe_id), "tribe status error.");

        /// check invalid address
        if (invaiteAddress != address(0)) {
            require(
                user_tribe_nftid[invaiteAddress][tribe_id] != 0,
                "invliad address."
            );
        }

        /// pay fee
        uint256 payFeeAmount = getPayFeeAmount(tribe_id);

        TribeInfo storage info = tribesInfo[tribe_id];

        // check pro or basic.
        if (info.feeToken == address(_matter_token)) {
            require(invaiteAddress == address(0), "only use pro.");
        }

        TribeNftInfo memory nft_info = extraTribesNFTInfo[tribe_id];
        uint256 outOfTime = getValidDate(tribe_id);
        // mint nft to.
        uint256 createdID = _tribe_nft.mint(
            msgSender(),
            nft_info.memberNFTName,
            nft_info.memberNFTIntroduction,
            nft_info.memberNFTImage,
            msgSender(),
            getValidDate(tribe_id)
        );

        TribeNFTCreate storage tribe_nft = nft_claim_contracts[createdID];
        tribe_nft.creator = msgSender();
        tribe_nft.startTime = block.timestamp;
        tribe_nft.validDate = info.validDate;
        tribe_nft.feeToken = info.feeToken;
        tribe_nft.feeAmount = payFeeAmount;
        tribe_nft.tribe_id = tribe_id;

        TribeInfoExtra storage tribeInfo = extraTribesInfo[tribe_id];

        transferFeeAmountToOwner(
            payFeeAmount,
            info.feeToken,
            tribeInfo.owner,
            invaiteAddress,
            tribeInfo.invitationRate
        );

        emit ClaimNFT(
            msgSender(),
            tribe_id,
            createdID,
            info.feeToken,
            payFeeAmount,
            2,
            outOfTime,
            invaiteAddress,
            tribeInfo.invitationRate,
            block.timestamp
        );
    }

    function stakeNFT(uint256 tribe_id, uint256 nft_id) public {
        require(checkTribeCompleteStatus(tribe_id), "tribe status error.");

        TribeNFTCreate storage tribe_nft = nft_claim_contracts[nft_id];

        /// check nft is valid.
        require(tribe_nft.creator != address(0), "error nft id.");
        require(user_tribe_nftid[msgSender()][tribe_id] == 0, "ready stake.");

        if (tribe_nft.validDate != 0) {
            uint256 endTime = tribe_nft.startTime + tribe_nft.validDate;
            require(endTime >= block.timestamp, "out of date.");
        }

        require(tribe_nft.tribe_id == tribe_id, "error tribe id");

        //
        IERC721 nftToken = IERC721(_tribe_nft);
        require(msgSender() == nftToken.ownerOf(nft_id), "error owner.");
        nftToken.safeTransferFrom(msgSender(), address(this), nft_id);

        tribe_nft.user = msgSender();
        user_tribe_nftid[msgSender()][tribe_id] = nft_id;

        emit StakeNFT(msgSender(), tribe_id, nft_id, block.timestamp);
    }

    function unStakeNFT(uint256 tribe_id) public {
        uint256 stake_nft_id = user_tribe_nftid[msgSender()][tribe_id];
        require(stake_nft_id != 0, "no stake.");

        TribeNFTCreate storage tribe_nft = nft_claim_contracts[stake_nft_id];
        require(tribe_nft.user == msgSender(), "stake owner");
        tribe_nft.user = address(0);

        //
        IERC721 nftToken = IERC721(_tribe_nft);
        nftToken.safeTransferFrom(address(this), msgSender(), stake_nft_id);

        // unstake
        user_tribe_nftid[msgSender()][tribe_id] = 0;
        emit UnStakeNFT(msgSender(), tribe_id, stake_nft_id, block.timestamp);
    }

    function checkTribeCompleteStatus(uint256 tribe_id)
        public
        view
        returns (bool)
    {
        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        return
            extra.created == true &&
            extra.claimOwnerNFT == true &&
            extra.initMemberNFT == true &&
            extra.deny == false;
    }

    function getPayFeeAmount(uint256 tribe_id) internal returns (uint256) {
        TribeInfo storage info = tribesInfo[tribe_id];

        if (info.feeToken == address(_matter_token)) {
            //
            uint256 oldAmount = _matter_token.balanceOf(address(this));
            _matter_token.transferFrom(
                msgSender(),
                address(this),
                _join_matter
            );
            uint256 newAmount = _matter_token.balanceOf(address(this));
            uint256 payFeeAmount = newAmount.sub(oldAmount);

            require(payFeeAmount >= _join_matter, "not enough amount.");
            return payFeeAmount;
        }

        // BNB
        if (info.feeToken == address(1)) {
            require(msg.value >= info.feeAmount, "not enough amount.");
            return msg.value;
        }
        ERC20 _fee_token = ERC20(info.feeToken);
        uint256 oldAmount = _fee_token.balanceOf(address(this));

        _fee_token.transferFrom(msgSender(), address(this), info.feeAmount);
        uint256 newAmount = _fee_token.balanceOf(address(this));
        uint256 payFeeAmount = newAmount.sub(oldAmount);

        require(payFeeAmount >= info.feeAmount, "not enough amount.");

        return payFeeAmount;
    }

    function getValidDate(uint256 tribe_id) internal view returns (uint256) {
        TribeInfo storage info = tribesInfo[tribe_id];
        if (info.validDate == 0) {
            return 0;
        }
        return info.validDate.add(block.timestamp);
    }

    function rollbackNFTFromTribe(uint256 nft_id)
        public
        payable
        nonReentrant
        returns (uint256)
    {
        TribeNFTCreate storage tribe_nft = nft_claim_contracts[nft_id];
        require(tribe_nft.user != address(0), "no stake.");

        TribeInfoExtra storage info_extra = extraTribesInfo[tribe_nft.tribe_id];
        require(info_extra.owner == msgSender(), "not owner.");
        
        // check is tribe.
        require(info_extra.owner_nft_id != nft_id, "cant delete tribe owner nft.");

        

     

        uint256 rollbackAmount = getRollbackAmount(nft_id);

        if (rollbackAmount > 0) {
            checkTransferFromFeeAmount(rollbackAmount, nft_id);

            /// BNB
            if (tribe_nft.feeToken == address(1)) {
                //
                (bool success, ) = tribe_nft.user.call{value: rollbackAmount}(
                    ""
                );
                require(success, "rollback failed.");
            } else {
                ERC20 _fee_token = ERC20(tribe_nft.feeToken);
                bool ok = _fee_token.transfer(tribe_nft.user, rollbackAmount);
                require(ok, "transfer token error.");
            }
        }
        
        // reset
        user_tribe_nftid[tribe_nft.user][tribe_nft.tribe_id] = 0;

        tribe_nft.user = address(0);
        emit DeleteTribeNFT(msgSender(), nft_id, block.timestamp);
        return nft_id;
    }

    function getRollbackAmount(uint256 nft_id) public view returns (uint256) {
        TribeNFTCreate storage tribe_nft = nft_claim_contracts[nft_id];
        if (tribe_nft.validDate == 0) {
            return tribe_nft.feeAmount;
        }
        uint256 end_time = tribe_nft.startTime.add(tribe_nft.validDate);
        if (end_time <= block.timestamp) {
            return 0;
        }
        uint256 outOfTime = end_time.sub(block.timestamp);
        uint256 roll_back_amount = tribe_nft.feeAmount.mul(outOfTime).div(
            tribe_nft.validDate
        );
        return roll_back_amount;
    }

    function checkTransferFromFeeAmount(uint256 feeAmount, uint256 nft_id)
        internal
        returns (uint256)
    {
        TribeNFTCreate storage tribe_nft = nft_claim_contracts[nft_id];
        // BNB
        if (tribe_nft.feeToken == address(1)) {
            require(msg.value >= feeAmount, "bad fee.");
        } else {
            ERC20 _fee_token = ERC20(tribe_nft.feeToken);
            uint256 oldAmount = _fee_token.balanceOf(address(this));

            _fee_token.transferFrom(msgSender(), address(this), feeAmount);
            uint256 newAmount = _fee_token.balanceOf(address(this));
            uint256 subBalance = newAmount.sub(oldAmount);
            require(subBalance >= feeAmount, "bad fee token.");
        }

        return 0;
    }

    /// transfer fee of claim member .
    function transferFeeAmountToOwner(
        uint256 feeAmount,
        address feeToken,
        address toAddress,
        address invitationAddress,
        uint256 rate
    ) internal {
        if (toAddress == address(0)) {
            // DOT anything
            return;
        }

        if (feeAmount == 0) {
            return;
        }
        uint256 invaitation_value = 0;
        uint256 owner_value = feeAmount;

        // dispatch fee amount.
        if (rate != 0 && invitationAddress != address(0)) {
            invaitation_value = feeAmount.mul(rate).div(100);
            owner_value = feeAmount.sub(invaitation_value);
        }

        // BNB
        if (feeToken == address(1)) {
            (bool success, ) = toAddress.call{value: owner_value}("");
            require(success, "tranfer fee failed.");

            if (invitationAddress != address(0) && invaitation_value != 0) {
                (bool success2, ) = invitationAddress.call{
                    value: invaitation_value
                }("");
                require(success2, "tranfer fee failed.");
            }

            return;
        }

        // transfer onwer
        ERC20 _fee_token = ERC20(feeToken);
        bool success = _fee_token.transfer(toAddress, owner_value);
        require(success, "transfer fee error.");

        // transfer invaitation_value
        if (invitationAddress != address(0) && invaitation_value != 0) {
            bool success2 = _fee_token.transfer(
                invitationAddress,
                invaitation_value
            );
            require(success2, "transfer fee error.");
        }
    }

    function updateTribeFeeSetting(
        uint256 tribe_id,
        address feeToken,
        uint256 feeAmount,
        uint256 validDate
    ) public checkTribeOwner(tribe_id) {
        TribeInfo storage info = tribesInfo[tribe_id];

        // check pro or basic.
        require(info.feeToken != address(_matter_token), "only use pro.");

        info.feeToken = feeToken;
        info.feeAmount = feeAmount;
        info.validDate = validDate;

        emit UpdateTribeSetting(msgSender(), tribe_id, info);
    }

    function settingInvitaion(uint256 tribe_id, uint256 rate)
        public
        checkTribeOwner(tribe_id)
    {
        require(rate <= 100, "error rate");

        TribeInfo storage info = tribesInfo[tribe_id];
        // check pro or basic.
        require(info.feeToken != address(_matter_token), "only use pro.");

        TribeInfoExtra storage extra = extraTribesInfo[tribe_id];
        extra.invitationRate = rate;

        emit UpdateTribeInvitation(msgSender(), tribe_id, rate);
    }
}
