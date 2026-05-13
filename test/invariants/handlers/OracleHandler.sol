contract OracleHandler {

    UGIOracleV3 oracle;

    constructor(UGIOracleV3 _oracle) {
        oracle = _oracle;
    }

    function executeRequest(bytes32 requestId) public {
        // fuzz oracle execution
    }
}