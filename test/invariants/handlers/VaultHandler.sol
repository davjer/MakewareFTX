contract VaultHandler {

    ReputationVaultV7 vault;

    constructor(ReputationVaultV7 _vault) {
        vault = _vault;
    }

    function borrow(uint256 nftId, uint256 amount) public {
        amount = bound(amount, 0.01 ether, 5 ether);
        // simulate borrow calls
    }

    function repay(uint256 loanId) public payable {
        // fuzz repayment
    }

    function liquidate(uint256 loanId) public {
        // fuzz liquidation
    }
}