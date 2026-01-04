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

export async function deploy(ethers: HardhatEthersHelpers, signerAddress: string, uri: string) {
    const Lazbubu = await ethers.getContractFactory("Lazbubu");
    const lazbubu = await Lazbubu.deploy(uri);

    // Set signer if different from deployer
    const deployer = await ethers.getSigners();
    if (deployer[0].address.toLowerCase() !== signerAddress.toLowerCase()) {
        const txSetSigner = await lazbubu.setSigner(signerAddress);
        console.log("Lazbubu setSigner tx:", txSetSigner.hash);
        await txSetSigner.wait();
    }

    return { lazbubu };
}