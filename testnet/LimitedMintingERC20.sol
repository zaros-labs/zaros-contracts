// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

// Open zeppelin upgradeable dependencies
import { ERC20PermitUpgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @notice LimitedMintingERC20 is an ERC20 token with limited minting capabilities used in testnet.
contract LimitedMintingERC20 is UUPSUpgradeable, ERC20PermitUpgradeable, OwnableUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Address of the Perpetuals Engine contract.
    address public constant PERPS_ENGINE = 0x6B57b4c5812B8716df0c3682A903CcEfc94b21ad;

    /// @notice Amount of tokens minted per address.
    uint256 public constant AMOUNT_TO_MINT_USDC = 100_000 * 10 ** 18;

    uint256 public constant MAX_AMOUNT_USER_SHOULD_HAVE_BEFORE_THE_MINT = 10_000 * 10 ** 18;

    /// @notice Start time for minting.
    uint256 public startTimeMinting;

    /// @notice Mapping of the amount minted per address.
    mapping(address user => uint256 amount) public amountMintedPerAddress;

    /// @notice Mapping of the last minted time per address.
    mapping(address user => uint256 lastMintedTime) public userLastMintedTime;

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when the amount to mint is zero.
    error LimitedMintingERC20_ZeroAmount();

    /// @notice Error emitted when the user is not permitted.
    error LimitedMintingERC20_UserIsNotPermitted(address user);

    /// @notice Error emitted when minting is not started.
    error LimitedMintingERC20_MintingIsNotStarted(uint256 timestampStartDate);

    /// @notice Error emitted when the user has already minted this week.
    error LimitedMintingERC20_UserAlreadyMintedThisWeek(address user, uint256 lastMintedTime);

    /// @notice Error emitted when the user has more than the maximum amount.
    error LimitedMintingERC20_UserHasMoreThanMaxAmount(address user, uint256 amount, uint256 maxAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function initialize(address owner, string memory name, string memory symbol) external initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init(owner);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        if (msg.sender != PERPS_ENGINE) {
            revert LimitedMintingERC20_UserIsNotPermitted(msg.sender);
        }

        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        if (msg.sender != PERPS_ENGINE) {
            revert LimitedMintingERC20_UserIsNotPermitted(msg.sender);
        }

        return super.transferFrom(from, to, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function setStartTimeMinting(uint256 _startTimeMinting) external onlyOwner {
        startTimeMinting = _startTimeMinting;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function mint(uint256 tokenIndex) external {
        if (block.timestamp < startTimeMinting) {
            revert LimitedMintingERC20_MintingIsNotStarted(startTimeMinting);
        }

        uint256 numberOfWeeks = (block.timestamp - startTimeMinting) / 7 days;

        if (userLastMintedTime[msg.sender] >= startTimeMinting + numberOfWeeks * 7 days) {
            revert LimitedMintingERC20_UserAlreadyMintedThisWeek(msg.sender, userLastMintedTime[msg.sender]);
        }

        address tradingAccountToken = IPerpsEngine(PERPS_ENGINE).getTradingAccountToken();
        uint128 tradingAccountId = uint128(IERC721Enumerable(tradingAccountToken).tokenOfOwnerByIndex(msg.sender, tokenIndex));

        (SD59x18 marginBalanceUsdX18,,,) = IPerpsEngine(PERPS_ENGINE).getAccountMarginBreakdown(tradingAccountId);

        uint256 userBalance = balanceOf(msg.sender) + uint256(marginBalanceUsdX18.intoInt256());

        if (userLastMintedTime[msg.sender] > 0 && userBalance > MAX_AMOUNT_USER_SHOULD_HAVE_BEFORE_THE_MINT) {
            revert LimitedMintingERC20_UserHasMoreThanMaxAmount(
                msg.sender, userBalance, MAX_AMOUNT_USER_SHOULD_HAVE_BEFORE_THE_MINT
            );
        }

        userLastMintedTime[msg.sender] = block.timestamp;
        amountMintedPerAddress[msg.sender] = AMOUNT_TO_MINT_USDC;

        _mint(msg.sender, AMOUNT_TO_MINT_USDC);
    }

    function burn(address from, uint256 amount) external {
        _requireAmountNotZero(amount);
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) revert LimitedMintingERC20_ZeroAmount();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
