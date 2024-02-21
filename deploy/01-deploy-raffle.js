const { network, ethers } = require("hardhat");
const { developmentChains, networkConfig } = require("../helper-herdhet-config");
const { verify } = require("../utils/verify");


module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    let vrfCoordinatorV2Address, subscriptionId;
    const chainId = network.config.chainId;
    const vrfSubscriptionFundAmount = ethers.parseEther("2");


    if (developmentChains.includes(network.name)) {
        const vrfCoordinatorV2Mock = await ethers.getContractAt("VRFCoordinatorV2Mock", "0x5FbDB2315678afecb367f032d93F642f64180aa3");


        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.target;
        const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
        const transactionReceipt = await transactionResponse.wait(1);
        subscriptionId = transactionReceipt.logs[0].topics[1];
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, vrfSubscriptionFundAmount);
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
        subscriptionId = networkConfig[chainId]["subscriptionId"];
    }


    const entranceFee = networkConfig[chainId]["entranceFee"];
    const gasLane = networkConfig[chainId]["gasLane"];
    const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
    const interval = networkConfig[chainId]["interval"];

    console.log("ADDRESS = ", vrfCoordinatorV2Address);

    const args = [vrfCoordinatorV2Address, entranceFee, gasLane, subscriptionId, callbackGasLimit, interval];
    const raffle = await deploy("Raffle", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    });

    if (!developmentChains.includes(network.name) && process.env.ETHERSCANAPIKEY) {
        log("VERIFYING....");
        await verify(raffle.address, args);
    }

    log("==========================================");
};


module.exports.tags = ["all", "raffle"];