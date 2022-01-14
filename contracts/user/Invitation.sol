// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../governance/InitializableOwner.sol";
import "../base/BasicMetaTransaction.sol";
import "../interfaces/IDsgNft.sol";
import "../interfaces/IUserProfile.sol";
import "../interfaces/IBurnableERC20.sol";

contract Invitation is InitializableOwner, BasicMetaTransaction, ReentrancyGuard {

    using SafeMath for uint256;

    struct CodeLock {
        address user;
        uint256 lockedAt;
    }

    struct CodeInfo {
        address generator;
        uint8 state; // 1.unused 2.used
    }

    uint8 constant CODE_STATE_UNUSED = 1;
    uint8 constant CODE_STATE_USED = 2;

    IERC721 public nft;
    IUserProfile public userProfile;

    mapping(uint256 => uint) public nftGenCodeCount; // Count of invitation codes generated by nft
    mapping(bytes32 => CodeInfo) public codeInfo; 
    mapping(bytes32 => CodeLock) public codeLock;

    uint256 public codeLockDuration;
    uint256 public maxGenCodeCount;

    event GenCode(address indexed sender, uint256 indexed nft_id, uint256 timestamp, bytes32 code);
    event LockEvent(address indexed serder, uint256 timestamp, bytes32 halfHash);

    event Exchange(address indexed sender, string indexed code, uint256 indexed createdID, uint256 existedID, uint256 color);

    // mint to.
    IDsgNft public _toToken;

    uint8 constant MAX_DEPTH = 16;
    uint32 constant MAX_DIF = (1 << 5) - 1;
    uint8 constant MOVE = 5;
    uint256 constant NFT_LIMIT = 20000;

    // parse ntf , 
    uint8[MAX_DEPTH] public tokenMax;
    // limit diff. if 0  this select unlimit ,
    uint8[MAX_DEPTH][MAX_DIF] public limitDiff;
    // how many select created.
    uint8[MAX_DEPTH][MAX_DIF] public createdDiff;

    // 0xff R
    // 0xff G
    // 0xff B
    // 0xff alpha  
    uint256 constant MAX_COLOR = 0xffffffff;

    // 
    uint8 public now_length = 0;

    // DsgNft _toToken nft,
    mapping(uint256 => address) public  _nft_address;

    uint256 public created_count = 0;

    /// upgrade
    uint256 public min_nft_value;
    bool public switch_buy_nft;

    /// upgrade nft ADB
    event MintMKDABNFT(address indexed sender, uint256 indexed value, uint256 indexed nfs);
    IDsgNft public METAYC_ADB;
    IBurnableERC20 public _MEYAYC_ADB_FragmentToken;
    uint256 public m_price;
    
    // 
    uint256 public max_create_nfts;

    constructor() public {

    }

    function initialize(
        IERC721 nft_, 
        address _to_token, 
        address userProfile_, 
        address metaYCBoard,
        address metaYCBoardFragment
    ) public {
        super._initialize();

        nft = nft_;
        _toToken = IDsgNft(_to_token);
        userProfile = IUserProfile(userProfile_);
        codeLockDuration = 10 minutes;
        maxGenCodeCount = 3;
        switch_buy_nft = false;
        min_nft_value = 3e17;
        METAYC_ADB = IDsgNft(metaYCBoard);
        _MEYAYC_ADB_FragmentToken = IBurnableERC20(metaYCBoardFragment);
        m_price = 10000*(10**18);
        max_create_nfts = NFT_LIMIT;
    }

    // codeHash: keccak256(code)
    function genCodes(uint256 nftId, bytes32[] memory codeHashs) public {
        (,, uint256 uTokenId, ,) = userProfile.getUserView(msgSender());
        require(nft.ownerOf(nftId) == msgSender() || (uTokenId >= 0 && nftId == uTokenId), "not the nft owner");

        uint count = nftGenCodeCount[nftId];
        require(count + codeHashs.length <= maxGenCodeCount, "exceeds the maximum number that can be generated");

        for(uint i = 0; i < codeHashs.length; ++i) {
            CodeInfo storage info = codeInfo[codeHashs[i]];
            require(info.state == 0, "code alread used");

            info.state = CODE_STATE_UNUSED;
            info.generator = msgSender();

            emit GenCode(msgSender(), nftId, block.timestamp, codeHashs[i]);
        }

        nftGenCodeCount[nftId] = count + codeHashs.length;
      
    }

    function lockCode(bytes32 halfHash) public {
        CodeLock storage cl = codeLock[halfHash];
        if (cl.lockedAt != 0){
             require(cl.lockedAt.add(codeLockDuration) < block.timestamp, "already locked");
        }
    
        cl.user = msgSender();
        cl.lockedAt = block.timestamp;

        emit LockEvent(msgSender(), block.timestamp, halfHash);
    }

    function exchange(string memory nickname, string calldata code, uint256 created, uint256 bg_color)  public limitCreated returns(uint256 createTokenID) {
        require(_nft_address[created] == address(0), "id is crated.");
        require(checkTokenID(created) == true, "invalid created id.");
        require(MAX_COLOR >=  bg_color, "invalid is color.");
        // alpha only use 0xff.
        require(bg_color & 0xff ==  0xff, "alpha only 0xff.");

        bytes32 codeHash = keccak256(bytes(code));
        CodeInfo storage info = codeInfo[codeHash];
        require(info.state == CODE_STATE_UNUSED, "bad state");

        info.state = CODE_STATE_USED;

        bytes32 codeHashHalf = keccak256(abi.encodePacked(code[:8]));
        require(codeLock[codeHashHalf].user == msgSender(), "not the locker");


        string memory res = uint256ToString(created);
        //mint nft.
        uint256 createdID = _toToken.mint(address(this), "Metaverse ape yacht club",  0, 0, res, address(this));

        // record 
        _nft_address[created] = msgSender();

        _toToken.approve(address(userProfile), createdID);
        userProfile.createProfileToUser(msgSender(), nickname, address(_toToken), createdID, info.generator);

        created_count++;
        // emit event.
        emit Exchange(msg.sender, code, createdID, created, bg_color);
        
        return createdID;
    }

    function setMaxDepth(uint8 index, uint8 limit) onlyOwner public {
        require(index < MAX_DEPTH, "outof index(16).");
        require(limit > 0, "limit require > 0.");
        require(limit <= MAX_DIF, "outof index(32).");

        tokenMax[index] = limit - 1;
    }

    function setOneLimit(uint8 index, uint8 limit, uint8 maxSize) onlyOwner public {
        require(limit < tokenMax[index], "invalid index - limit.");

        limitDiff[index][limit] = maxSize;
    }

    function setDepth(uint8 depth)  onlyOwner public {
        now_length = depth;
    }

    function getLimitSize(uint8 index) public view returns( uint8[] memory) {
        
        uint8[] memory dif =  new uint8[](tokenMax[index]+1);
        
        for (uint8 i = 0; i <= tokenMax[index];i++){
            dif[i] = limitDiff[index][i];
        }
        
        return dif;
    }

    function getCreatedSize(uint8 index) public view returns( uint8[] memory) {
        uint8[] memory dif =  new uint8[](tokenMax[index]+1);
        
        for (uint8 i = 0; i <= tokenMax[index];i++){
            dif[i] = createdDiff[index][i];
        }
        
        return dif;
    }

    function checkTokenID(uint256 createID) public view returns(bool) {
        // must first != 0.
        require(tokenMax[0] != 0,"please init setMaxDepth.");

        uint8[] memory dif  = DecodeToken(createID);
        
        require(dif.length == now_length, "invalid length createid");
        
        for (uint8 i = 0; i < dif.length; i++){
            uint8 select = dif[i];

            if (select > tokenMax[i]) {
                return false;
            }

            if ( limitDiff[i][select] != 0 && createdDiff[i][select] + 1 > limitDiff[i][select] ) {
                return false;
            }
        }
        
        return true;
    }

    function encodeToken(uint8[] memory dif) public view returns(uint256 tokenID)  {
        require(dif.length == now_length, "length must == now_length");

        for(uint8 i = 0; i < now_length;i++){
            require(dif[i] >= 0, "invalid dif");
            require(dif[i] <= tokenMax[i], "outof different.");
            tokenID = (tokenID << (MOVE)) + dif[i];
        }
        return tokenID;
    }

    function DecodeToken(uint256 tokenID) public view returns(uint8[] memory ) {
        
        uint8[] memory dif =  new uint8[](now_length);

        for (uint8 i = 0; i < now_length; i++){
            dif[now_length - i - 1] = uint8( tokenID & (MAX_DIF)) ;
            tokenID = tokenID >> MOVE;
        }
        
        return dif;
    }

    function uint256ToString(uint i) public pure returns (string memory) {
        
        if (i == 0) return "0";
        
        uint j = i;
        uint length;
        
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        
        uint mask = 15;
        bytes memory bstr = new bytes(length);
        uint k = length - 1;
        
        while (i != 0) {
            uint curr = (i & mask);
            bstr[k--] = bytes1(curr > 9 ? uint8(55 + curr ) : uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }
        
        return string(bstr);
    }

    function getView() public view returns(address nft_, address userProfile_, uint256 codeLockDuration_, uint256 maxGenCodeCount_, address toToken_) {
        nft_ = address(nft);
        userProfile_ = address(userProfile);
        codeLockDuration_ = codeLockDuration;
        maxGenCodeCount_ = maxGenCodeCount;
        toToken_ = address(_toToken);
    }

    function getCreatedLimit() public view returns(uint256 limit , uint256 created){
        limit = max_create_nfts;
        created = created_count;
    }

    function getCodeView(bytes32 codeHash) public view returns(address lockUser, uint256 lockedAt, address generator, uint8 state) {
        CodeLock storage cl = codeLock[codeHash];
        CodeInfo storage ci = codeInfo[codeHash];

        lockUser = cl.user;
        lockedAt = cl.lockedAt;
        generator = ci.generator;
        state = ci.state;
    }

    // implementation  received.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public  returns (bytes4) {
        
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }
        
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    modifier switch_buy_status() {
        require(switch_buy_nft == true, "end.");
        _;
    }

    modifier limitCreated() {
        require(created_count < max_create_nfts, "out of limit.");
        _;
    }

    function Exchange_NFT(uint256 created, uint256 bg_color)  public payable limitCreated switch_buy_status nonReentrant {
        require(_nft_address[created] == address(0), "id is crated.");
        require(checkTokenID(created) == true, "invalid created id.");
        require(MAX_COLOR >=  bg_color, "invalid is color.");
        // alpha only use 0xff.
        require(bg_color & 0xff ==  0xff, "alpha only 0xff.");
        require(msg.value == min_nft_value, "invliad value.");

        _nft_address[created] = msgSender();
        string memory res = uint256ToString(created);
        uint256 createdID = _toToken.mint(msgSender(), "Metaverse ape yacht club",  0, 0, res, address(this));

        created_count++;
        // emit event.
        emit Exchange(msgSender(), "", createdID, created, bg_color);
    }

    function set_buy_nft_value(uint256 value) public onlyOwner{
        min_nft_value = value;
    }

    function switch_status(bool status) public onlyOwner {
        switch_buy_nft = status;
    }

    function WithdrawValue() public payable onlyOwner nonReentrant {
        // require(address(this).call.value(100)(), "Call failed"); // solhint-disable-line avoid-call-value
        uint256 total_value = address(this).balance;
        (bool success,) = owner().call{value:total_value}("");
        require(success, "withdraw failed.");
    }

    /// 
    function set_METAYC_ADB_token(address adb, address Fragment_adb) public onlyOwner {
        METAYC_ADB = IDsgNft(adb);
        _MEYAYC_ADB_FragmentToken = IBurnableERC20(Fragment_adb);
    }

    function set_price(uint256 price) public onlyOwner{
        m_price = price;
    }

    function set_max_created_number(uint256 number) public onlyOwner{
        max_create_nfts = number;
    }

    function Exhcange_METAYC_ADB(uint256 nft_id, uint256 created, uint256 bg_color)  public  {
        require(_nft_address[created] == address(0), "id is crated.");
        require(checkTokenID(created) == true, "invalid created id.");
        require(MAX_COLOR >=  bg_color, "invalid is color.");
        // alpha only use 0xff.
        require(bg_color & 0xff ==  0xff, "alpha only 0xff.");
        //
        require(msgSender() == METAYC_ADB.ownerOf(nft_id), "Only NFT owner can register");
        METAYC_ADB.safeTransferFrom(msgSender(), address(this), nft_id);

        // burn nft.
        METAYC_ADB.burn(nft_id);

        // created
        string memory res = uint256ToString(created);
        //mint nft.
        uint256 createdID = _toToken.mint(msgSender(), "Metaverse ape yacht club",  0, 0, res, msgSender());

        // emit event.
        emit Exchange(msgSender(), "", createdID, created, bg_color);
    }

    /*
     */
    function buyMKDADBNFT(uint256 amount)  public limitCreated returns(bool) {
        require(amount > 0, "amount < price");
        // how many ticketsNFT.
        uint256 nfts = amount.div(m_price);

        // cost amount.
        uint256 value = nfts.mul(m_price);
        require(nfts > 0, "nfts not enougt amount.");
        require(value > 0, "value not enougt amount.");
        require(max_create_nfts >= created_count + nfts, "out of number.");

        bool ret = _MEYAYC_ADB_FragmentToken.transferFrom(address(msgSender()), address(this), value);
        require(ret, "transferFrom error");

        for (uint256 i = 0; i < nfts; i++) {
            METAYC_ADB.mint(msgSender(), "METAYCDB",  0, 0, "METAYCBD", address(this));
        }
        created_count += nfts;

        _MEYAYC_ADB_FragmentToken.burn(value);

        emit MintMKDABNFT(msgSender(), value, nfts);
        return true;
    }

    function buy_MKDAB() public payable limitCreated switch_buy_status nonReentrant {
        uint256 amount = msg.value;
        // how many ticketsNFT.
        uint256 nfts = amount.div(min_nft_value);

        // cost amount.
        uint256 value = nfts.mul(min_nft_value);
        
        require(nfts > 0, "nfts not enougt amount.");
        require(value > 0, "value not enougt amount.");
        require(max_create_nfts >= created_count + nfts, "out of number.");

        for (uint256 i = 0; i < nfts; i++) {
             METAYC_ADB.mint(msgSender(), "MKDAB",  0, 0, "MKDAB", address(this));
            // emit event.
            emit MintMKDABNFT(msgSender(), min_nft_value, 1);
        } 
        created_count += nfts;
    }
    
}