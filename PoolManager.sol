// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Attaching Libraries
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IBalancerPool.sol";
import "./structs/PoolStructs.sol";
import "./structs/StakeStructs.sol";
import "./structs/ParamStructs.sol"; 
import "./libraries/PoolUtils.sol";

/// @title PoolManager Contract
/// @notice Manages staking, unstaking, and pool management functions
/// @dev Uses OpenZeppelin's upgradeable contracts for security and upgradability
contract PoolManager is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using PoolUtils for uint256;
    using PoolUtils for bytes;

    // Declarations
    bytes32[] public poolIds;
    mapping(bytes32 => PoolStructs.Pool) public pools;
    mapping(address => mapping(bytes32 => StakeStructs.Stake[])) public stakes;
    mapping(address => bytes32[]) userPools;

    IBalancerPool public balancer;

    uint256 MAX_INT;
    IERC20Upgradeable public nodedToken;
    uint256 public nodedApr;

    uint256 public totalUsers;
    PoolStructs.NodedPool public nodedPool;
    mapping(address => StakeStructs.NodedStake[]) public nodedStakes;
    uint256 public totalNodedStaked;
    uint256 public totalNodedUsers;

    // Events
    event PoolCreated(
        bytes32 indexed poolId,
        uint256[] lockupDurations,
        uint256 apr,
        bool isActive,
        uint256 feePercentage
    );
    event NodedPoolCreated(
        uint256[] lockupDurations,
        uint256[] apys,
        bool isActive,
        uint256 fee
    );
    event PoolToggled(bytes32 indexed poolId, bool isActive);
    event PoolDeleted(bytes32 indexed poolId);
    event StakeCreated(
        address indexed user,
        bytes32 indexed poolId,
        uint256 amount,
        uint256 lockupDuration,
        uint256 apr
    );
    event StakeNodedCreated(
        address indexed user,
        uint256 amount,
        uint256 lockupDuration,
        uint256 apr
    );
    event Unstaked(
        address indexed user,
        bytes32 indexed poolId,
        uint256 stakeIndex
    );
    event UnstakedNoded(address indexed user, uint256 stakeIndex);
    event EmergencyWithdrawal(address indexed tokenAddress, uint256 amount);

    // Modifiers
    modifier validPoolId(bytes32 poolId) {
        require(poolId != bytes32(0), "Invalid poolId");
        _;
    }

    modifier poolIsActive(bytes32 poolId) {
        require(pools[poolId].isActive, "Pool is not active");
        _;
    }

    // Admin Functions

    /// @notice Initializes the PoolManager contract
    /// @param _balancerAddress The address of the Balancer pool
    /// @param _nodedToken The address of the Noded token
    function initialize(address _balancerAddress, address _nodedToken)
        public
        initializer
    {
        require(
            _balancerAddress != address(0),
            "Balancer address cannot be zero"
        );
        require(
            _nodedToken != address(0),
            "Noded token address cannot be zero"
        );

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        balancer = IBalancerPool(_balancerAddress);

        nodedToken = IERC20Upgradeable(_nodedToken);
        MAX_INT = type(uint256).max;
        totalUsers = 0;
        totalNodedStaked = 0;
        totalNodedUsers = 0;
    }

    /// @notice Sets the address of the Balancer pool
    /// @param _balancerAddress The new address of the Balancer pool
    function setBalancerAddress(address _balancerAddress) public onlyOwner {
        require(
            _balancerAddress != address(0),
            "Balancer address cannot be zero"
        );
        balancer = IBalancerPool(_balancerAddress);
    }

    /// @notice Authorizes the contract upgrade
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /// @notice Performs an emergency withdrawal of the contract's balance
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
        emit EmergencyWithdrawal(address(0), balance);
    }

    /// @notice Performs an emergency withdrawal of a specific ERC20 token
    /// @param _tokenAddress The address of the token
    /// @param _amount The amount to be withdrawn
    function emergencyWithdrawErc20(address _tokenAddress, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "Amount must be greater than 0");
        IERC20Upgradeable(_tokenAddress).safeTransfer(msg.sender, _amount);
        emit EmergencyWithdrawal(_tokenAddress, _amount);
    }

    /// @notice Creates a new pool
    /// @param poolId The ID of the pool
    /// @param lockupDurations The lockup durations for the pool
    /// @param apr The APR for the pool
    /// @param isActive Whether the pool is active
    /// @param feePercentage The fee percentage for the pool
    function createPool(
        bytes32 poolId,
        uint256[] memory lockupDurations,
        uint256 apr,
        bool isActive,
        uint256 feePercentage
    ) public onlyOwner validPoolId(poolId) {
        require(feePercentage <= 10000, "Fee percentage cannot exceed 100%");
        (address[] memory assets, , ) = getPoolDataFromBalancer(poolId);
        (address poolToken, ) = balancer.getPool(poolId);

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] != address(0)) {
                IERC20Upgradeable(assets[i]).approve(
                    address(balancer),
                    MAX_INT
                );
            }
        }

        pools[poolId] = PoolStructs.Pool(
            poolId,
            assets,
            lockupDurations,
            apr,
            poolToken,
            isActive,
            feePercentage
        );
        poolIds.push(poolId);

        emit PoolCreated(poolId, lockupDurations, apr, isActive, feePercentage);
    }

    /// @notice Creates a new Noded pool
    /// @param lockupDurations The lockup durations for the Noded pool
    /// @param apys The APYs for the Noded pool
    /// @param isActive Whether the Noded pool is active
    /// @param fee The fee for the Noded pool
    function createNodedPool(
        uint256[] memory lockupDurations,
        uint256[] memory apys,
        bool isActive,
        uint256 fee
    ) public onlyOwner {
        require(
            lockupDurations.length == apys.length,
            "Lockup durations and APYs length mismatch"
        );
        nodedPool = PoolStructs.NodedPool({
            lockupDurations: lockupDurations,
            apys: apys,
            isActive: isActive,
            fee: fee
        });

        emit NodedPoolCreated(lockupDurations, apys, isActive, fee);
    }

    /// @notice Toggles the active status of a pool
    /// @param poolId The ID of the pool
    /// @param isActive The new active status of the pool
    function togglePoolActive(bytes32 poolId, bool isActive)
        public
        onlyOwner
        validPoolId(poolId)
    {
        pools[poolId].isActive = isActive;
        emit PoolToggled(poolId, isActive);
    }

    /// @notice Deletes a pool
    /// @param poolId The ID of the pool
    function deletePool(bytes32 poolId) public onlyOwner validPoolId(poolId) {
        require(pools[poolId].isActive, "Pool is already inactive");

        delete pools[poolId];

        uint256 lastIndex = poolIds.length - 1;
        for (uint256 i = 0; i < poolIds.length; i++) {
            if (poolIds[i] == poolId) {
                if (i != lastIndex) {
                    poolIds[i] = poolIds[lastIndex];
                }
                poolIds.pop();
                break;
            }
        }

        emit PoolDeleted(poolId);
    }

    /// @notice Refreshes the spending allowance for a specific asset
    /// @param assetAddress The address of the asset
    /// @param spending The new spending allowance
    function refreshSpending(address assetAddress, uint256 spending)
        public
        onlyOwner
    {
        IERC20Upgradeable(assetAddress).approve(address(balancer), spending);
    }

    // Getter Functions

    /// @notice Retrieves pool data from the Balancer pool
    /// @param poolId The ID of the pool
    /// @return tokens The tokens in the pool
    /// @return balances The balances of the tokens in the pool
    /// @return lastChangeBlock The last change block of the pool
    function getPoolDataFromBalancer(bytes32 poolId)
        public
        view
        returns (
            address[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        )
    {
        (tokens, balances, lastChangeBlock) = balancer.getPoolTokens(poolId);
        return (tokens, balances, lastChangeBlock);
    }

    /// @notice Retrieves the Noded stakes of a user
    /// @param user The address of the user
    /// @return userNodedStakes The Noded stakes of the user
    /// @return calculatedInterests The calculated interests for the Noded stakes
    function getUserNodedStakes(address user)
        public
        view
        returns (
            StakeStructs.NodedStake[] memory userNodedStakes,
            uint256[] memory calculatedInterests
        )
    {
        userNodedStakes = nodedStakes[user];
        calculatedInterests = new uint256[](userNodedStakes.length);
        for (uint256 i = 0; i < userNodedStakes.length; i++) {
            calculatedInterests[i] = PoolUtils.calculateProjectedReturns(
                userNodedStakes[i].amount,
                userNodedStakes[i].apr,
                userNodedStakes[i].lockupDuration
            );
        }
        return (userNodedStakes, calculatedInterests);
    }

    /// @notice Retrieves the total amount of Noded tokens staked
    /// @return The total amount of Noded tokens staked
    function getTotalNodedStaked() public view returns (uint256) {
        return totalNodedStaked;
    }

    /// @notice Retrieves the total number of users staking Noded tokens
    /// @return The total number of users staking Noded tokens
    function getTotalNodedUsers() public view returns (uint256) {
        return totalNodedUsers;
    }

    /// @notice Retrieves the details of the Noded pool
    /// @return The lockup durations, APYs, active status, and fee of the Noded pool
    function getNodedPool()
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            bool,
            uint256
        )
    {
        return (
            nodedPool.lockupDurations,
            nodedPool.apys,
            nodedPool.isActive,
            nodedPool.fee
        );
    }

    /// @notice Retrieves the pools of a user
    /// @param _user The address of the user
    /// @return The pools of the user
    function getUserPools(address _user)
        public
        view
        returns (bytes32[] memory)
    {
        return userPools[_user];
    }

    /// @notice Retrieves the details of all stakes for a user in a specific pool
    /// @param user The address of the user
    /// @param poolId The ID of the pool
    /// @return userStakes The stakes of the user
    /// @return calculatedInterests The calculated interests for the stakes
    function getAllStakesDetails(address user, bytes32 poolId)
        public
        view
        returns (
            StakeStructs.Stake[] memory userStakes,
            uint256[] memory calculatedInterests
        )
    {
        userStakes = stakes[user][poolId];
        calculatedInterests = new uint256[](userStakes.length);
        for (uint256 i = 0; i < userStakes.length; i++) {
            calculatedInterests[i] = calculateInterestForStake(user, poolId, i);
        }
        return (userStakes, calculatedInterests);
    }

    /// @notice Retrieves the details of all pools
    /// @return allPools The details of all pools
    function getAllPools()
        public
        view
        returns (PoolStructs.Pool[] memory allPools)
    {
        allPools = new PoolStructs.Pool[](poolIds.length);
        for (uint256 i = 0; i < poolIds.length; i++) {
            allPools[i] = pools[poolIds[i]];
        }
        return allPools;
    }

    // Setter Functions

    /// @notice Sets the APR for the Noded pool
    /// @param _nodedApr The new APR for the Noded pool
    function setNodedApr(uint256 _nodedApr) public onlyOwner {
        nodedApr = _nodedApr;
    }

    /// @notice Sets the fee percentage for a specific pool
    /// @param poolId The ID of the pool
    /// @param feePercentage The new fee percentage
    function setPoolFee(bytes32 poolId, uint256 feePercentage)
        public
        onlyOwner
        validPoolId(poolId)
    {
        require(feePercentage <= 10000, "Fee percentage cannot exceed 100%");
        pools[poolId].feePercentage = feePercentage;
    }

    /// @notice Sets the APR for a specific pool
    /// @param poolId The ID of the pool
    /// @param apr The new APR
    function setPoolApr(bytes32 poolId, uint256 apr)
        public
        onlyOwner
        validPoolId(poolId)
    {
        pools[poolId].apr = apr;
    }

    /// @notice Stakes assets in a pool
    /// @param params A struct containing the parameters for staking
    function stake(
        ParamStructs.StakeParams memory params
    ) external payable nonReentrant poolIsActive(params.poolId) {
        // Validate the lockup index
        require(params.lockupIndex < pools[params.poolId].lockupDurations.length, "Invalid lockup duration index");

        // Transfer assets and ensure the correct amount of native asset is sent
        (address assetAddress, uint256 assetAmount) = _transferAssets(params);
        _checkNativeAmount(assetAddress, assetAmount);

        // Execute the join pool request and get the new BPT amount
        uint256 bptAmount = _executeJoinPool(params, pools[params.poolId]);

        // Create a new stake
        _createNewStake(msg.sender, assetAmount, assetAddress, params, pools[params.poolId], bptAmount);

        // Update user pools
        _updateUserPools(msg.sender, params.poolId);

        emit StakeCreated(msg.sender, params.poolId, assetAmount, pools[params.poolId].lockupDurations[params.lockupIndex], pools[params.poolId].apr);
    }

    /// @notice Stakes Noded tokens
    /// @param amount The amount of Noded tokens to be staked
    /// @param lockupIndex The index of the lockup duration
    function stakeNoded(uint256 amount, uint256 lockupIndex)
        external
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than 0");
        require(
            lockupIndex < nodedPool.lockupDurations.length,
            "Invalid lockup duration index"
        );

        nodedToken.safeTransferFrom(msg.sender, address(this), amount);

        nodedStakes[msg.sender].push(
            StakeStructs.NodedStake({
                amount: amount,
                startTime: block.timestamp,
                lockupDuration: nodedPool.lockupDurations[lockupIndex],
                apr: nodedPool.apys[lockupIndex]
            })
        );

        totalNodedStaked += amount;

        if (nodedStakes[msg.sender].length == 1) {
            totalNodedUsers++;
        }

        emit StakeNodedCreated(
            msg.sender,
            amount,
            nodedPool.lockupDurations[lockupIndex],
            nodedPool.apys[lockupIndex]
        );
    }

    /// @notice Unstakes Noded tokens
    /// @param stakeIndex The index of the stake to be unstaked
    function unstakeNoded(uint256 stakeIndex)
        external
        nonReentrant
    {
        require(stakeIndex < nodedStakes[msg.sender].length, "Invalid stake index");
        StakeStructs.NodedStake storage stakex = nodedStakes[msg.sender][stakeIndex];
        require(stakex.amount > 0, "Already unstaked");
        require(block.timestamp >= stakex.startTime + stakex.lockupDuration, "Lockup period is not over");

        uint256 interest = PoolUtils.calculateProjectedReturns(
            stakex.amount,
            stakex.apr,
            stakex.lockupDuration
        );

        uint256 fee = (interest * nodedPool.fee) / 10000;
        uint256 amountAfterFee = (stakex.amount + interest) - fee;

        nodedToken.safeTransfer(msg.sender, amountAfterFee);

        totalNodedStaked -= stakex.amount;

        uint256 lastIndex = nodedStakes[msg.sender].length - 1;
        if (stakeIndex != lastIndex) {
            nodedStakes[msg.sender][stakeIndex] = nodedStakes[msg.sender][lastIndex];
        }
        nodedStakes[msg.sender].pop();

        if (nodedStakes[msg.sender].length == 0) {
            totalNodedUsers--;
        }

        emit UnstakedNoded(msg.sender, stakeIndex);
    }

    /// @notice Unstakes assets from a pool
    /// @param params A struct containing the parameters for unstaking
    function unstake(
        ParamStructs.UnstakeParams memory params
    ) external nonReentrant poolIsActive(params.poolId) {
        require(params.stakeIndex < stakes[msg.sender][params.poolId].length, "Invalid stake index");

        StakeStructs.Stake storage stakex = stakes[msg.sender][params.poolId][params.stakeIndex];
        require(stakex.amount > 0, "No amount found for this stake");
        require(block.timestamp >= stakex.startTime + stakex.lockupDuration, "Lockup period is not over");

        (, uint256 amountUnstaked) = params.userData.decodeUserData();
        require(stakex.bptAmount == amountUnstaked, "Invalid amount unstaked");

        uint256[] memory initialBalances = new uint256[](params.assets.length);
        for (uint256 i = 0; i < params.assets.length; i++) {
            initialBalances[i] = IERC20Upgradeable(params.assets[i]).balanceOf(address(this));
        }

        IBalancerPool.ExitPoolRequest memory request = IBalancerPool.ExitPoolRequest({
            assets: params.assets,
            minAmountsOut: params.amounts,
            userData: params.userData,
            toInternalBalance: false
        });

        balancer.exitPool(params.poolId, address(this), payable(address(this)), request);

        for (uint256 i = 0; i < params.assets.length; i++) {
            uint256 newBalance = IERC20Upgradeable(params.assets[i]).balanceOf(address(this));
            uint256 difference = newBalance - initialBalances[i];
            uint256 fee = (difference * pools[params.poolId].feePercentage) / 10000;
            uint256 amountAfterFee = difference - fee;
            IERC20Upgradeable(params.assets[i]).safeTransfer(msg.sender, amountAfterFee);
        }

        if (containsNoded(params.poolId)) {
            uint256 nodedInterest = PoolUtils.calculateProjectedReturns(
                stakex.amount,
                nodedApr,
                stakex.lockupDuration
            );
            nodedToken.safeTransfer(msg.sender, nodedInterest);
        }

        delete stakes[msg.sender][params.poolId][params.stakeIndex];

        uint256 totalUserStakesInPool = 0;
        StakeStructs.Stake[] storage stakeAfterDelete = stakes[msg.sender][params.poolId];
        for (uint256 i = 0; i < stakeAfterDelete.length; i++) {
            if (stakeAfterDelete[i].amount > 0) {
                totalUserStakesInPool++;
            }
        }

        if (totalUserStakesInPool == 0) {
            _deleteUserPool(msg.sender, params.poolId);
        }

        if (userPools[msg.sender].length == 0) {
            totalUsers--;
        }

        emit Unstaked(msg.sender, params.poolId, params.stakeIndex);
    }

    // Internal Functions

    function _deleteUserPool(address user, bytes32 poolId) internal {
        require(poolId != bytes32(0), "Invalid poolId");
        uint256 lastIndex = userPools[user].length - 1;
        for (uint256 i = 0; i < userPools[user].length; i++) {
            if (userPools[user][i] == poolId) {
                if (i != lastIndex) {
                    userPools[user][i] = userPools[user][lastIndex];
                }
                userPools[user].pop();
                break;
            }
        }
    }

    /// @notice Transfer assets from the user to the contract
    /// @return assetAddress The address of the asset transferred
    /// @return assetAmount The amount of the asset transferred
    function _transferAssets(
        ParamStructs.StakeParams memory stakeRequest
    ) private returns (address assetAddress, uint256 assetAmount) {
        for (uint256 i = 0; i < stakeRequest.assets.length; i++) {
            if (stakeRequest.amounts[i] > 0) {
                assetAddress = stakeRequest.assets[i];
                assetAmount = stakeRequest.amounts[i];
                if (assetAddress != address(0)) {
                    IERC20Upgradeable(assetAddress).safeTransferFrom(
                        msg.sender,
                        address(this),
                        assetAmount
                    );
                }
                break;
            }
        }
        require(assetAmount > 0, "No valid amount found");
    }

    /// @notice Checks the native amount sent matches the required amount
    function _checkNativeAmount(address assetAddress, uint256 assetAmount) private view {
        if (assetAddress == address(0)) {
            require(msg.value == assetAmount, "Native amount sent does not match the required amount");
        }
    }

    /// @notice Executes the join pool request
    /// @return bptAmount The amount of BPT received
    function _executeJoinPool(
        ParamStructs.StakeParams memory stakeRequest,
        PoolStructs.Pool storage pool
    ) private returns (uint256 bptAmount) {
        uint256 initialBalance = IERC20Upgradeable(pool.poolToken).balanceOf(address(this));

        IBalancerPool.JoinPoolRequest memory request = IBalancerPool.JoinPoolRequest({
            assets: stakeRequest.assets,
            maxAmountsIn: stakeRequest.amounts,
            userData: stakeRequest.userData,
            fromInternalBalance: false
        });

        balancer.joinPool{value: msg.value}(stakeRequest.poolId, address(this), address(this), request);

        uint256 newBalance = IERC20Upgradeable(pool.poolToken).balanceOf(address(this));
        bptAmount = newBalance - initialBalance;
    }

    /// @notice Creates a new stake for the user
    function _createNewStake(
        address user,
        uint256 assetAmount,
        address assetAddress,
        ParamStructs.StakeParams memory stakeRequest,
        PoolStructs.Pool storage pool,
        uint256 bptAmount
    ) private {
        stakes[user][stakeRequest.poolId].push(
            StakeStructs.Stake({
                amount: assetAmount,
                bptAmount: bptAmount,
                assetAddress: assetAddress,
                startTime: block.timestamp,
                lockupDuration: pool.lockupDurations[stakeRequest.lockupIndex],
                apr: pool.apr,
                assets: stakeRequest.assets,
                amounts: stakeRequest.amounts
            })
        );
    }

    /// @notice Updates the user's pools
    function _updateUserPools(address user, bytes32 poolId) private {
        bool foundUserPool = false;
        for (uint256 i = 0; i < userPools[user].length; i++) {
            if (userPools[user][i] == poolId) {
                foundUserPool = true;
                break;
            }
        }
        if (!foundUserPool) {
            if (userPools[user].length == 0) {
                totalUsers++;
            }
            userPools[user].push(poolId);
        }
    }

    // Utility Functions

    /// @notice Calculates the APY for a user in a specific pool
    /// @param user The address of the user
    /// @param poolId The ID of the pool
    /// @return totalInterest The total interest earned by the user
    function calculateAPYForUser(address user, bytes32 poolId)
        public
        view
        returns (uint256 totalInterest)
    {
        StakeStructs.Stake[] memory userStakes = stakes[user][poolId];
        totalInterest = 0;
        for (uint256 i = 0; i < userStakes.length; i++) {
            uint256 timeStaked = block.timestamp - userStakes[i].startTime;
            if (timeStaked > userStakes[i].lockupDuration) {
                timeStaked = userStakes[i].lockupDuration;
            }
            uint256 interest = (userStakes[i].amount *
                userStakes[i].apr *
                timeStaked) / (365 days * 10000);
            totalInterest += interest;
        }
        return totalInterest;
    }

    /// @notice Calculates the interest for a specific stake
    /// @param user The address of the user
    /// @param poolId The ID of the pool
    /// @param stakeIndex The index of the stake
    /// @return interest The interest earned by the stake
    function calculateInterestForStake(
        address user,
        bytes32 poolId,
        uint256 stakeIndex
    ) public view returns (uint256 interest) {
        StakeStructs.Stake memory stakex = stakes[user][poolId][stakeIndex];
        uint256 timeStaked = block.timestamp - stakex.startTime;
        if (timeStaked > stakex.lockupDuration) {
            timeStaked = stakex.lockupDuration;
        }
        interest =
            (stakex.amount * stakex.apr * timeStaked) /
            (365 days * 10000);
        return interest;
    }

    /// @notice Checks if a pool contains Noded tokens
    /// @param poolId The ID of the pool
    /// @return True if the pool contains Noded tokens, false otherwise
    function containsNoded(bytes32 poolId) internal view returns (bool) {
        PoolStructs.Pool storage pool = pools[poolId];
        for (uint256 i = 0; i < pool.assets.length; i++) {
            if (pool.assets[i] == address(nodedToken)) {
                return true;
            }
        }
        return false;
    }

    /// @notice Fallback function to receive Ether
    receive() external payable {}
}
