// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// 1.创建一个收款函数
// 2.记录投资人并且查看
// 3.在锁定期内，达到目标值，生产商可以提款
// 4.在锁定期内，没有达到目标值，投资人在锁定期以后退款
contract FundMe{
 
    AggregatorV3Interface internal dataFeed;
    // 定义映射  
    mapping(address => uint256) public fundersToAmount;

    // 设置最小值
    uint256 constant MIMI_NUM = 1 * 10 ** 18;//USD计价   1个ETH = 多少USD？

    uint256 constant TARGET = 100 * 10 ** 18;

    address owner;

    uint256 deployTimestamp; // 部署时间戳

    uint256 lockTime; // 锁定时间

    // ERC20地址
    address public erc20Address ;

    // 提款成功标识
    bool public isWithdraw = false;

    constructor(uint256 _lockTime){
        owner = msg.sender;
       // spolia testnet
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        deployTimestamp = block.timestamp;
        lockTime = _lockTime;
      }

    // payble 修饰收款函数
    function fund() external payable {
        // 供应商不能存款
        require(msg.sender != owner, "owner can't fund!"); 
        //存入的值必须大于设置的最小值
        // require 必须是true的状态 false状态就会触发revert
        require(convertEthToUsdPrice(msg.value) >= MIMI_NUM, "You need to spend more ETH!");
        // 是否在锁定期内
        require(block.timestamp < deployTimestamp + lockTime, "windows is close!");
        fundersToAmount[msg.sender] += msg.value;
    }

     function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
    // prettier-ignore
    (
      /* uint80 roundId */
      ,
      int256 answer,
      /*uint256 startedAt*/
      ,
      /*uint256 updatedAt*/
      ,
      /*uint80 answeredInRound*/
    ) = dataFeed.latestRoundData();
    return answer;
  }

  // ETH转换USD函数
  function convertEthToUsdPrice(uint256 amount) internal  view returns (uint256) {
    // (ETH amount)*(ETH price) =(ETH value)
    uint256 price = uint256(getChainlinkDataFeedLatestAnswer());
    // amount 的单位是wei  price 的精度 precision ETH == USD precision 10**8
    // X = ETH 10**18
    return price * amount / (10 ** 8);
  }
  
  // 提款函数 达到预期需要本人提取
  function getFund() external  onlyOwner lockTimeCheck{
    // 判断融资金额是否达到预期值
    require(convertEthToUsdPrice(address(this).balance) >= TARGET, "Funding goal not reached");
    // transfer 纯转账 transfer ETH and revert if tx failed
    // payable(msg.sender).transfer(address(this).balance); // msg.sender
    // send 纯转账 transfer ETH and return false if failed
    // bool success = payable(msg.sender).send(address(this).balance);
    // require(success,"tx failed");
    // call 都可以全能转账可以夹扎着其他处理
    // call : transfer ETH with data return value of function and bool
    bool success;
    (success ,) = payable(msg.sender).call{value:address(this).balance}("");
    require(success,"transfer tx failed");
    isWithdraw = true; 
  }

  // 修改取款人
  function changeOwner(address newOwner) external onlyOwner{
    // 判断是否是本人提款
    owner = newOwner;
  }

  // 退款
  function refund() external{
    require(convertEthToUsdPrice(address(this).balance) < TARGET, "Funding goal reached");
    require(fundersToAmount[msg.sender] != 0, "You have not contributed");
    bool success;
    (success ,) = payable(msg.sender).call{value:fundersToAmount[msg.sender]}("");
    require(success,"transfer tx failed");
    // 退款完成之后要清0
    fundersToAmount[msg.sender] = 0;
  } 

  // 公共的判断
  modifier onlyOwner() {
     require(msg.sender == owner, "Only the owner can change the owner");
     _;
  }
  // 公共判断锁定期
  modifier lockTimeCheck() {
    require(block.timestamp >= deployTimestamp + lockTime, "windows is not close!");
    _;
  }

  // 修改投资者金额
  function changeFunderAmount(address funder, uint256 amount) external{
    // 投资者才可以修改
    require(msg.sender == erc20Address, "Only funder can change the amount");
    fundersToAmount[funder] = amount;
  }

  // 设置地址
  function setERC20Address(address _address) external onlyOwner{
    erc20Address = _address;
  }

}