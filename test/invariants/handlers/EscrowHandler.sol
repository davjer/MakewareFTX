contract EscrowHandler {

    IUGIEscrowV4 escrow;

    constructor(UGIEscrowV4 _escrow) {
        escrow = _escrow;
    }

    function release(uint256 id) public {
        // fuzz milestone release
    }

    function fail(uint256 id) public {
        // fuzz failure paths
    }
}