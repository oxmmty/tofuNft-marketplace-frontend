// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

import './interface/IACSVault.sol';
import './interface/IACSController.sol';
import './interface/ISCVNFT.sol';

/**
 * The contract mints a random SCVxACryptoS NFT.
 * Users need to pay with an ERC20 `token` with certain `amount`
 * Random number generated from block.timestamp will be used to
 * choose a NFT spec
 */
contract SCVxACSMinter is Context, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
    bytes32 public constant OPERATOR_ROLE = keccak256('OPERATOR_ROLE');

    // token and price for buying the NFT
    uint256 public requiredTokenAmount;
    address public buyWithToken;
    uint256 public botPrice;
    address public nftToken;

    // for transferring the sales of NFTs
    address private _acsVault;
    address private _acsController;
    address private _scvReward = 0x079a889eB69013d451EcF45377258948116e2b3e;
    uint256 _baseSpecId;

    /**
     */
    constructor(
        address vault,
        address controller,
        uint256 amount,
        address token,
        uint256 price,
        address nft,
        uint256 baseSpecId
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        // 0x7679381507af0c8DE64586A458161aa58D3A4FC3
        _acsVault = vault;
        // 0xeb8f15086274586f95c551890A29077a5b6e5e55
        _acsController = controller;
        _baseSpecId = baseSpecId;

        // 5 ACS = 5 * 1e18
        requiredTokenAmount = amount;
        // buy with token, 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
        buyWithToken = token;
        // 10 BUSD = 10 * 1e18
        botPrice = price;
        // the NFT to be minted
        nftToken = nft;
    }

    /**
     * @dev Return the amount of ACS which sender holds in the vault
     */
    function amountInVault() private view returns (uint256) {
        IACSVault vault = IACSVault(_acsVault);
        uint256 balance = vault.balanceOf(_msgSender());
        uint256 ppfs = vault.getPricePerFullShare();

        // (balanceof / 10**decimals) * (getPricePerFullShare / 10**decimals)
        // as decimals = 18 in ACS token is fixed
        // to preserve the precision, share 1e18 as two 1e9
        return (balance / 1e9) * (ppfs / 1e9);
    }

    /**
     * @dev A very loose randomness for just bringing the users some
     * unbalanced supply of different types
     */
    function getRandomSpecId() private view returns (uint256) {
        bytes memory b = abi.encodePacked(block.timestamp, block.difficulty);
        uint256 seed = uint256(keccak256(b)) % 100;
        if (seed >= 95) {
            // 5%
            return 0;
        } else if (seed >= 80) {
            // 15%
            return 1;
        } else if (seed >= 50) {
            // 30%
            return 2;
        } else {
            // 50%
            return 3;
        }
    }

    /**
     * @dev Creates a new token for `msg.sender`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     */
    function mint() public virtual whenNotPaused {
        require(
            amountInVault() >= requiredTokenAmount,
            'must have enough tokens'
        );
        IERC20 erc20 = IERC20(buyWithToken);
        // transfer 80% to ACS
        uint256 amount0 = (botPrice * 8) / 10;
        address acsAddr = IACSController(_acsController).rewards();
        erc20.safeTransferFrom(_msgSender(), acsAddr, amount0);
        // transfer the rest to SCV
        uint256 amount1 = botPrice - amount0;
        erc20.safeTransferFrom(_msgSender(), _scvReward, amount1);
        // calc the specId from 0~3 and add to baseSpecId
        uint256 specId = _baseSpecId + getRandomSpecId();
        ISCVNFT(nftToken).mint(_msgSender(), specId);
    }

    /**
     * @dev Set a new required `amount` to accquire the NFT
     */
    function setAmount(uint256 amount) public virtual {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            'must have operator role to change amount'
        );
        requiredTokenAmount = amount;
    }

    /**
     * @dev Set a new required `amount` to accquire the NFT
     */
    function setBaseSpecId(uint256 baseSpecId) public virtual {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            'must have operator role to change amount'
        );
        _baseSpecId = baseSpecId;
    }

    /**
     * @dev Set a new required `amount` to accquire the NFT
     */
    function setBuyWithToken(address token) public virtual {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            'must have operator role to change amount'
        );
        buyWithToken = token;
    }

    /**
     * @dev Set a new required `amount` to accquire the NFT
     */
    function setPrice(uint256 price) public virtual {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            'must have operator role to change amount'
        );
        botPrice = price;
    }

    function pause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            'must have pauser role to pause'
        );
        _pause();
    }

    function unpause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            'must have pauser role to unpause'
        );
        _unpause();
    }
}
