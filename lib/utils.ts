import { getBytes, Signer, solidityPackedKeccak256 } from "ethers";
import { HardhatEthersHelpers } from "@nomicfoundation/hardhat-ethers/types";

export async function signPermit(signer: Signer, nonce: number, permitType: number, dataHash: string, expire: number): Promise<{ permitType: number, nonce: number, dataHash: string, expire: number, sig: string }> {
    const hash = solidityPackedKeccak256(["uint8", "uint128", "uint256", "uint"], [permitType, nonce, dataHash, expire]);
    const sig = await signer.signMessage(getBytes(hash));
    return { permitType, nonce, dataHash, expire, sig };
}

export async function deploy(ethers: HardhatEthersHelpers, signerAddress: string, uri: string) {
    const PermitVerifier = await ethers.getContractFactory("PermitVerifier");
    const permitVerifier = await PermitVerifier.deploy();
    const txSetSigner = await permitVerifier.setSigner(signerAddress);
    console.log("PermitVerifier setSigner tx:", txSetSigner.hash);

    const Lazbubu = await ethers.getContractFactory("Lazbubu");
    const lazbubu = await Lazbubu.deploy(uri, permitVerifier.target);

    const txSetServiceTo = await permitVerifier.setServiceTo(lazbubu.target);
    console.log("PermitVerifier setServiceTo tx:", txSetServiceTo.hash);
    return { permitVerifier, lazbubu };
}