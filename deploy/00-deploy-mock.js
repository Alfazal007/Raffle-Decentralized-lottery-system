const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-herdhet-config");

const baseFee = ethers.parseEther("0.25"); // it costs 0.25 links per request
// https://docs.chain.link/vrf/v2/subscription/supported-networks
const gasPriceLink = 1e9; // 1000000000 // calculated value based on gas price of the chain


module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const args = [baseFee, gasPriceLink];
    const chainId = network.config.chainId;
    if (developmentChains.includes(network.name)) {
        log("Local network detected! Deploying mocks...");
        // deploy mock
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        });
        log("Mocks deployed");
        log("==============================================================");
    }
};

module.exports.tags = ["all", "mocks"];