// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMetaMorpho, IMorpho, Id, MarketParams} from "./interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory} from "./interfaces/IMetaMorphoFactory.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title MetaMorphoFactory
/// @notice This contract allows to create immutable, single-pair MetaMorpho vaults.
contract MetaMorphoWrapperFactory {
    /* IMMUTABLES */

    IMetaMorphoFactory public immutable MORPHO_FACTORY;

    IMorpho public immutable MORPHO;

    /* STORAGE */

    mapping(IMetaMorpho=>Id) public marketIds;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param morphoFactory The address of the Morpho Factory contract.
    constructor(IMetaMorphoFactory morphoFactory, IMorpho morpho) {
        if (address(morphoFactory) == address(0)) revert ErrorsLib.ZeroAddress();

        MORPHO_FACTORY = morphoFactory;
        MORPHO = morpho;
    }

    /* EXTERNAL */

    /// @dev for events simply index CreateMetaMorpho where initialOwner == address(this)
    function createMetaMorpho(Id id) external returns (IMetaMorpho metaMorpho) {
        MarketParams memory marketParams = MORPHO.idToMarketParams(id);
        address asset = marketParams.loanToken;
        string memory tokenName = IERC20Metadata(asset).name();

        metaMorpho = MORPHO_FACTORY.createMetaMorpho(address(this), 1 days, asset, string(abi.encodePacked("MM:", tokenName)), string(abi.encodePacked("MetaMorpho: ", tokenName)), Id.unwrap(id));

        marketIds[metaMorpho] = id;

        metaMorpho.submitCap(marketParams, type(uint184).max);
    }

    function initialize(IMetaMorpho metaMorpho) external {
        Id id = marketIds[metaMorpho]; 
        MarketParams memory marketParams = MORPHO.idToMarketParams(id);
        
        metaMorpho.acceptCap(marketParams);

        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = id;
        metaMorpho.setSupplyQueue(supplyQueue);
    }
}
