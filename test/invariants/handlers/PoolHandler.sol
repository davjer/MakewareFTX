contract PoolHandler {

    LiquidityPoolV3 pool;

    constructor(LiquidityPoolV3 _pool) {
        pool = _pool;
    }

    function deposit(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 10 ether);
    }

    function withdraw(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 5 ether);
    }
}