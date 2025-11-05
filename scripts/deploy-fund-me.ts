import hre, { network } from "hardhat";
import { getContract } from "viem";


const { viem } = await network.connect({
    network: "sepolia", 
  chainType: "l1", 
});

console.log("Sending transaction using the OP chain type");

const [wallet1,wallet2] = await viem.getWalletClients();

const fundMe = await viem.deployContract("FundMe",[100n],{
    client:{
        wallet:wallet2,
    },
});
const address =  fundMe.address;

console.log("contract is address:",address);

const fundMeNew = getContract({
    address:fundMe.address,
    abi: fundMe.abi,
    client:{
        wallet:wallet1,
    }
})


await fundMeNew.write.fund({
   value: 4n*10n ** 15n,
});


await fundMeNew.write.refund()





  