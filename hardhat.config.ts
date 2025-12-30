import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig, task, types } from "hardhat/config";
import dotenv from "dotenv";
import 'solidity-docgen';
import { deploy } from "./lib/utils.ts";
import { resolveArgs } from "ethers/lib.commonjs/contract/contract.js";

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.24",

        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
                details: {
                    yul: true,
                },
            },
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            },
        },
    },

    networks: {
        bsc: {
            chainId: 56,
            url:
                process.env.RPC_URL ||
                "https://bsc-dataseed.binance.org/",
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        bsctest: {
            chainId: 97,
            url:
                process.env.RPC_URL ||
                "https://bsc-testnet.drpc.org",
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
    },

    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY || "placeholder",
        customChains: [
            {
                network: "bsc",
                chainId: 56,
                urls: {
                    apiURL: "https://bscscan.com/api",
                    browserURL: "https://bscscan.com/",
                },
            },
            {
                network: "bsctestnet",
                chainId: 97,
                urls: {
                    apiURL: "https://testnet.bscscan.com/api",
                    browserURL: "https://testnet.bscscan.com/",
                },
            },
        ],
    },
};

export default config;

task("deploy", "Deploy the contract")
    .addParam("signer", "The address of the signer")
    .addParam("uri", "The URI of the token")
    .setAction(async (args: { signer: string, uri: string }, { ethers }) => {
        const { lazbubu } = await deploy(ethers, args.signer, args.uri);
        console.log("Lazbubu deployed to:", lazbubu.target);
    });