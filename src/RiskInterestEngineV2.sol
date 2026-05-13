// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";


//import "./UGINFTCoreV6.sol";

import "./interfaces/IRiskInterestEngineV2.sol";
import "./interfaces/IUGINFTCoreV6.sol";

contract RiskInterestEngineV2 is
    AccessControl,
    Pausable
{
    // -------------------------------------------------
    // CONSTANTS
    // -------------------------------------------------

    uint256 public constant MAX_BPS =
        10000;

    // -------------------------------------------------
    // NFT CORE
    // -------------------------------------------------

    IUGINFTCoreV6 public nft;

    // -------------------------------------------------
    // GLOBAL APR CONFIG
    // -------------------------------------------------

    uint256 public baseAPR =
        500; // 5%

    uint256 public maxAPR =
        2500; // 25%

    uint256 public minAPR =
        200; // 2%

    // -------------------------------------------------
    // SCORE BRACKETS
    // -------------------------------------------------

    uint256 public primeScore =
        800;

    uint256 public trustedScore =
        600;

    uint256 public basicScore =
        400;

    uint256 public lowScore =
        200;

    // -------------------------------------------------
    // TIER MODIFIERS
    // -------------------------------------------------

    mapping(uint8 => int256)
        public tierModifier;

    // -------------------------------------------------
    // SYSTEM RISK MULTIPLIER
    // -------------------------------------------------

    uint256 public protocolRiskBps =
        0;

    // -------------------------------------------------
    // EVENTS
    // -------------------------------------------------

    event APRComputed(
        uint256 indexed nftId,
        uint256 score,
        uint256 aprBps
    );

    event APRConfigUpdated(
        uint256 minAPR,
        uint256 baseAPR,
        uint256 maxAPR
    );

    event TierModifierUpdated(
        uint8 indexed tier,
        int256 modifierBps
    );

    event ProtocolRiskUpdated(
        uint256 protocolRiskBps
    );

    // -------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------

    constructor(
        address nftAddress,
        address admin
    )
    {
        require(
            nftAddress != address(0),
            "ZERO_NFT"
        );

        require(
            admin != address(0),
            "ZERO_ADMIN"
        );

        nft =
            IUGINFTCoreV6(
                nftAddress
            );

        _grantRole(
            DEFAULT_ADMIN_ROLE,
            admin
        );

        // LOW
        tierModifier[0] = 500;

        // BASIC
        tierModifier[1] = 200;

        // TRUSTED
        tierModifier[2] = -100;

        // PRIME
        tierModifier[3] = -300;
    }

    // -------------------------------------------------
    // ADMIN
    // -------------------------------------------------

    function setAPRBounds(
        uint256 min_,
        uint256 base_,
        uint256 max_
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            min_ < base_ &&
            base_ < max_,
            "INVALID"
        );

        minAPR = min_;

        baseAPR = base_;

        maxAPR = max_;

        emit APRConfigUpdated(
            min_,
            base_,
            max_
        );
    }

    function setTierModifier(
        uint8 tier,
        int256 modifierBps
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tierModifier[tier] =
            modifierBps;

        emit TierModifierUpdated(
            tier,
            modifierBps
        );
    }

    function setProtocolRisk(
        uint256 riskBps
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            riskBps <= 5000,
            "TOO_HIGH"
        );

        protocolRiskBps =
            riskBps;

        emit ProtocolRiskUpdated(
            riskBps
        );
    }

    function setScoreThresholds(
        uint256 low_,
        uint256 basic_,
        uint256 trusted_,
        uint256 prime_
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            low_ <
            basic_ &&
            basic_ <
            trusted_ &&
            trusted_ <
            prime_,
            "ORDER"
        );

        lowScore =
            low_;

        basicScore =
            basic_;

        trustedScore =
            trusted_;

        primeScore =
            prime_;
    }

    function pause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();
    }

    function unpause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();
    }

    // -------------------------------------------------
    // CORE APR MODEL
    // -------------------------------------------------

    function getAPR(
        uint256 nftId
    )
        public
        view
        whenNotPaused
        returns (
            uint256 aprBps
        )
    {
        (
            uint256 score,
            ,
            uint8 tier,
            bool broken,

        ) = nft.getReputation(
                nftId
            );

        // ---------------------------------------------
        // HARD FAILURE STATE
        // ---------------------------------------------

        if (broken) {
            return maxAPR;
        }

        // ---------------------------------------------
        // BASE SCORE RISK
        // ---------------------------------------------

        uint256 riskFactor =
            _scoreRisk(
                score
            );

        // ---------------------------------------------
        // TIER MODIFIER
        // ---------------------------------------------

        int256 interestmodifier =
            tierModifier[tier];

        int256 adjusted =
            int256(riskFactor) +
            interestmodifier +
            int256(protocolRiskBps);

        // ---------------------------------------------
        // LOWER BOUND
        // ---------------------------------------------

        if (
            adjusted <
            int256(minAPR)
        ) {
            return minAPR;
        }

        // ---------------------------------------------
        // UPPER BOUND
        // ---------------------------------------------

        if (
            adjusted >
            int256(maxAPR)
        ) {
            return maxAPR;
        }

        aprBps =
            uint256(adjusted);

        emit APRComputed(
            nftId,
            score,
            aprBps
        );
    }

    // -------------------------------------------------
    // SCORE MODEL
    // -------------------------------------------------

    function _scoreRisk(
        uint256 score
    )
        internal
        view
        returns (uint256)
    {
        // PRIME
        if (
            score >= primeScore
        ) {
            return baseAPR;
        }

        // TRUSTED
        if (
            score >= trustedScore
        ) {
            return
                baseAPR + 300;
        }

        // BASIC
        if (
            score >= basicScore
        ) {
            return
                baseAPR + 800;
        }

        // LOW
        if (
            score >= lowScore
        ) {
            return
                baseAPR + 1500;
        }

        // CRITICAL
        return
            baseAPR + 2200;
    }

    // -------------------------------------------------
    // FRONTEND PREVIEW
    // -------------------------------------------------

    function previewAPR(
        uint256 nftId
    )
        external
        view
        returns (
            uint256 aprBps,
            uint256 score,
            uint8 tier,
            bool broken
        )
    {
        (
            score,
            ,
            tier,
            broken,

        ) = nft.getReputation(
                nftId
            );

        aprBps =
            getAPR(
                nftId
            );
    }

    // -------------------------------------------------
    // PURE PREVIEW
    // -------------------------------------------------

    function simulateAPR(
        uint256 score,
        uint8 tier,
        bool broken
    )
        external
        view
        returns (
            uint256 aprBps
        )
    {
        if (broken) {
            return maxAPR;
        }

        uint256 risk =
            _scoreRisk(
                score
            );

        int256 interestmodifier =
            tierModifier[tier];

        int256 adjusted =
            int256(risk) +
            interestmodifier +
            int256(protocolRiskBps);

        if (
            adjusted <
            int256(minAPR)
        ) {
            return minAPR;
        }

        if (
            adjusted >
            int256(maxAPR)
        ) {
            return maxAPR;
        }

        return uint256(adjusted);
    }
}