// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/**
 * Contract to prevent re-entrancy attack.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * Modifier to prevent re-entrancy attack.
     */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * Interface for ERC20 token to interact with it.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function decimals() external view returns (uint8);
}

/**
 * Contract to manage the Tontine.
 */
contract Tontine is ReentrancyGuard {
    // Index to track the subscribers
    uint256 public lastIndex = 0;

    // Maximum subscription by any subscriber
    uint256 public maxSubscription = 0;

    // Flag to track if distribution has started
    bool public distributionStarted = false;

    // Subscriber's age
    mapping(address => uint256) public ages;

    // Subscriber's alive status
    mapping(address => bool) public alive;

    // Subscriber's eligibility status
    mapping(address => bool) public eligible;

    // Mapping to get subscriber by index
    mapping(uint256 => address) public subscriberIndex;

    // Subscriber's investment
    mapping(address => uint256) public investment;

    // Address of the BUSD token contract
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    IERC20 private constant IBUSD = IERC20(BUSD);

    // Address of the KYC software wallet
    address constant kycSoftwareWallet = 0xd1411cE47497158d7D0FFcDEB7c670fa6c0c6e60;

    // Subscription window end timestamp
    uint256 window;

    // Tontine end timestamp
    uint256 public endTime = 1673649666;

    // Total investment by all subscribers
    uint256 totalInvestment = 0;

    /**
     * Modifier to restrict function access to KYC software.
     */
    modifier onlySoftware() {
        require(
            msg.sender == kycSoftwareWallet,
            "Only the KYC software is allowed to interact with this function"
        );
        _;
    }

    /**
     * Initialize the tontine smart contract.
     */
    constructor(uint256 subTime) {
        window = block.timestamp + subTime;
    }

    /**
     * Subscribe to the tontine.
     */
    function subscribe(
        uint256 investmentAmount
    ) external nonReentrant returns (bool) {
        require(
            eligible[msg.sender],
            "You are not eligible to participate in this tontine!"
        );
        require(window > block.timestamp, "Subscription window has ended!");
        if (lastIndex < 20) {
            // If subscriber is one of the first 20
            if (investment[msg.sender] == 0) {
                lastIndex += 1;
                subscriberIndex[lastIndex] = msg.sender;
            }
            // Updating maxSubscription if needed
            maxSubscription = investmentAmount > maxSubscription
                ? investmentAmount
                : maxSubscription;
        } else {
            // If subscriber is not one of the first 20
            require(
                investmentAmount <= maxSubscription / 10,
                "You can't invest more than 10% of the maximum investment"
            );
            if (investment[msg.sender] == 0) {
                lastIndex += 1;
                subscriberIndex[lastIndex] = msg.sender;
            }
        }

        // Transfer the BUSD from the msg.sender to the CA
        bool s = IBUSD.transferFrom(
            msg.sender,
            address(this),
            investmentAmount
        );
        require(s, "transfer of BUSD failed!");

        // Update subscriber's investment
        investment[msg.sender] += investmentAmount;

        // Update total investment
        totalInvestment += investmentAmount;

        return (true);
    }

    /**
     * Start the distribution of funds.
     */
    function startDistribution() external onlySoftware {
        require(block.timestamp > endTime, "Tontine has not matured yet!");
        distributionStarted = true;
    }

    /**
     * Claim the share of the fund.
     */
    function claim() external nonReentrant {
        require(
            distributionStarted,
            "Distribution has not started yet!"
        );
        require(
            alive[msg.sender],
            "You can't claim the funds as your status is not alive."
        );
        uint256 totalInvesmentAlive = getAliveInvestment();
        uint256 claimAmount =
            (investment[msg.sender] * totalInvestment) /
            totalInvesmentAlive;
        require(
            IBUSD.transfer(msg.sender, claimAmount),
            "Transfer of BUSD failed!"
        );
    }

    /**
     * Get total investment by alive subscribers.
     */
    function getAliveInvestment() public view returns (uint256) {
        uint256 aliveInvestment = 0;
        for (uint256 i = 1; i <= lastIndex; i++) {
            if (alive[subscriberIndex[i]]) {
                aliveInvestment += investment[subscriberIndex[i]];
            }
        }
        return (aliveInvestment);
    }

    /**
     * Change the alive status of a subscriber.
     */
    function changeAlive(
        address subscriber,
        bool aliveStatus
    ) external onlySoftware {
        alive[subscriber] = aliveStatus;
    }

    /**
     * Set the age of a subscriber.
     */
    function setAge(address subscriber, uint256 age) external onlySoftware {
        ages[subscriber] = age;
    }

    /**
     * Set the eligibility of a subscriber.
     */
    function setEligible(address sub, bool isEligible) external onlySoftware {
        eligible[sub] = isEligible;
    }
}
