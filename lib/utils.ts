import { Signer } from "ethers";
import { HardhatEthersHelpers } from "@nomicfoundation/hardhat-ethers/types";

export async function signPermit(signer: Signer, nonce: number, permitType: number, dataHash: string, expire: number, verifyingContract: string, chainId: number): Promise<{ permitType: number, nonce: number, dataHash: string, expire: number, sig: string }> {
    const domain = {
        name: "Lazbubu",
        version: "1",
        chainId,
        verifyingContract,
    };

    const types = {
        Permit: [
            { name: "permitType", type: "uint8" },
            { name: "nonce", type: "uint128" },
            { name: "dataHash", type: "uint256" },
            { name: "expire", type: "uint256" },
        ],
    };

    const value = {
        permitType: permitType,
        nonce: nonce,
        dataHash: dataHash,
        expire: expire,
    };

    const sig = await signer.signTypedData(domain, types, value);
    return { permitType, nonce, dataHash, expire, sig };
}

export async function deploy(ethers: HardhatEthersHelpers, adminAddress: string, signerAddress: string, uri: string) {
    const Lazbubu = await ethers.getContractFactory("Lazbubu");
    const lazbubu = await Lazbubu.deploy(uri, adminAddress, signerAddress);

    return { lazbubu };
}