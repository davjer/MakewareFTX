contract NFTHandler {

    IUGINFTCoreV6 nft;

    constructor(UGINFTCoreV6 _nft) {
        nft = _nft;
    }

    function reward(uint256 id, uint256 amount) public {
        amount = bound(amount, 1, 100);
    }

    function penalize(uint256 id, uint256 amount) public {
        amount = bound(amount, 1, 100);
    }
}