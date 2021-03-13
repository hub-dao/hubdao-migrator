pragma solidity =0.6.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hubdao-periphery/contracts/interfaces/IHubdaoRouter02.sol';
import 'hubdao-core/contracts/interfaces/IHubdaoPair.sol';

import './BonusToken.sol';

contract LiquidityMigrator {
  IHubdaoRouter02 public router;
  IHubdaoPair public pair;
  IHubdaoRouter02 public routerFork;
  IHubdaoPair public pairFork;
  BonusToken public bonusToken;
  address public admin;
  bool public migrationDone;
  
  mapping(address => uint) public unclaimedBalances;
  
  constructor(
    address _router,
    address _pair,
    address _routerFork,
    address _pairFork,
    address _bonusToken
  ) public {
    router =  IHubdaoRouter02(_router);
    pair =IHubdaoPair(_pair);
    routerFork =  IHubdaoRouter02(_routerFork);
    pairFork =IHubdaoPair(_pairFork);
    bonusToken = BonusToken(_bonusToken);
    admin = msg.sender;
  }

  function depoist(uint amount) external {
    require(migrationDone == false, 'migration aleady done');

    pair.transferFrom(msg.sender, address(this), amount);
    bonusToken.mint(msg.sender, amount);
    unclaimedBalances[msg.sender] += amount;
  }

  function migrate() external {
    require(msg.sender == admin, 'only admin');
    require(migrationDone == false, 'migration aleady done');

    IERC20 token0 = IERC20(pair.token0());
    IERC20 token1 = IERC20(pair.token1());
    uint totalBalance = pair.balanceOf(address(this));
    
    // last parameter is liquidity remove deadline
    router.removeLiquidity(address(token0), address(token1), totalBalance, 0, 0, address(this), block.timestamp);

    uint token0Balance = token0.balanceOf(address(this));
    uint token1Balance = token1.balanceOf(address(this));

    token0.approve(address(routerFork), token0Balance);
    token1.approve(address(routerFork), token1Balance);

    routerFork.addLiquidity(address(token0), address(token1), token0Balance, token1Balance, token0Balance, token1Balance, address(this), block.timestamp);

    migrationDone = true;
  }

  function claimLPtokens() external {
    require(unclaimedBalances[msg.sender] >= 0, 'no unclaimed balances');
    require(migrationDone == true, 'migration not done yet');

    uint amountToSend = unclaimedBalances[msg.sender];
    unclaimedBalances[msg.sender] = 0;
    pairFork.transfer(msg.sender, amountToSend);
  }
}