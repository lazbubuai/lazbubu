import { expect } from "chai";
import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { PERMIT_TYPE_ADVENTURE, PERMIT_TYPE_CREATE_MEMORY, PERMIT_TYPE_SET_LEVEL, PERMIT_TYPE_SET_PERSONALITY, PERMIT_TYPE_MINT } from "../lib/constants";
import { deploy, signPermit } from "../lib/utils";
import { solidityPackedKeccak256 } from "ethers";

describe("Lazbubu", () => {
    async function deployFixture() {
        const accounts = await ethers.getSigners();
        const [deployer, signer, user] = accounts;

        const { lazbubu } = await deploy(ethers, deployer.address, signer.address, "https://lazbubu.com/token/{id}");

        return { deployer, signer, user, lazbubu };
    }

    const tokenIdForMint = (address: string) => (1n << 255n) + BigInt(address);

    async function mintWithPermit(toSigner: any, signer: any, lazbubu: any, fileUrl = "https://lazbubu.com/token/1") {
        const tokenId = tokenIdForMint(toSigner.address);
        const nonce = Number(await lazbubu.nextPermitNonce(tokenId));
        const dataHash = solidityPackedKeccak256(["address", "string"], [toSigner.address, fileUrl]);
        const expire = Math.floor(Date.now() / 1000) + 3600;
        const chainId = (await ethers.provider.getNetwork()).chainId;
        const permit = await signPermit(signer, nonce, PERMIT_TYPE_MINT, dataHash, expire, await lazbubu.getAddress(), Number(chainId));
        await lazbubu.mint(toSigner.address, fileUrl, permit);
        const mintedId = await lazbubu.currentTokenId();
        return { mintedId, fileUrl, expire };
    }

    it("should be deployed and initialized correctly", async () => {
        const { deployer, signer, lazbubu } = await loadFixture(deployFixture);
        expect(await lazbubu.uri(0)).to.equal("https://lazbubu.com/token/{id}");
        expect(await lazbubu.currentTokenId()).to.equal(0);
        expect(await lazbubu.signer()).to.equal(signer.address);
        expect(await lazbubu.admin()).to.equal(deployer.address);
    });

    it("should mint a token", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const dataStr = "https://lazbubu.com/token/1";
        const dataHash = solidityPackedKeccak256(['address', 'string'], [user.address, dataStr]);
        const expire = Math.floor(Date.now() / 1000) + 3600;
        const chainId = (await ethers.provider.getNetwork()).chainId;
        const permit = await signPermit(signer, 0, PERMIT_TYPE_MINT, dataHash, expire, await lazbubu.getAddress(), Number(chainId));
        await expect(lazbubu.mint(user.address, dataStr, permit)).to.emit(lazbubu, "TokenMinted").withArgs(user.address, 1, dataStr);
        expect(await lazbubu.balanceOf(user.address, 1)).to.equal(1);
        const states = await lazbubu.states(1);
        expect(states.owner).to.equal(user.address);
        expect(states.birthday).to.be.gt(0);
        expect(states.level).to.equal(0);
        expect(states.maturity).to.equal(0);
        expect(states.reserved).to.equal(0);
        expect(states.lastTimeMessageQuotaClaimed).to.equal(0);
        expect(states.firstTimeMessageQuotaClaimed).to.equal(0);
        expect(states.personality).to.equal("");
        expect(await lazbubu.fileUrl(1)).to.equal(dataStr);
        const tokenIdForPermit = tokenIdForMint(user.address);
        expect(await lazbubu.nextPermitNonce(tokenIdForPermit)).to.equal(1);
    });

    it("should reject mint with invalid permit", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const attacker = (await ethers.getSigners())[3];
        const dataStr = "https://lazbubu.com/token/1";
        const dataHash = solidityPackedKeccak256(["address", "string"], [user.address, dataStr]);
        const expire = Math.floor(Date.now() / 1000) + 3600;
        const chainId = (await ethers.provider.getNetwork()).chainId;
        const permit = await signPermit(attacker, 0, PERMIT_TYPE_MINT, dataHash, expire, await lazbubu.getAddress(), Number(chainId));
        await expect(lazbubu.mint(user.address, dataStr, permit)).to.be.revertedWithCustomError(lazbubu, "InvalidPermitSignature");
    });

    it("should reject mint when permit expired", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const dataStr = "https://lazbubu.com/token/1";
        const dataHash = solidityPackedKeccak256(["address", "string"], [user.address, dataStr]);
        const expire = Math.floor(Date.now() / 1000) - 10;
        const chainId = (await ethers.provider.getNetwork()).chainId;
        const permit = await signPermit(signer, 0, PERMIT_TYPE_MINT, dataHash, expire, await lazbubu.getAddress(), Number(chainId));
        await expect(lazbubu.mint(user.address, dataStr, permit)).to.be.revertedWithCustomError(lazbubu, "PermitExpired");
    });

    it("should create adventures and memories with valid permits", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);

        const chainId = (await ethers.provider.getNetwork()).chainId;
        const adventureNonce = Number(await lazbubu.nextPermitNonce(mintedId));
        const adventureType = 2;
        const adventureContent = 12345;
        const adventureHash = solidityPackedKeccak256(["uint256", "uint8", "uint256"], [mintedId, adventureType, adventureContent]);
        const adventurePermit = await signPermit(signer, adventureNonce, PERMIT_TYPE_ADVENTURE, adventureHash, Math.floor(Date.now() / 1000) + 3600, await lazbubu.getAddress(), Number(chainId));
        await expect(lazbubu.adventure(mintedId, adventureType, adventureContent, adventurePermit))
            .to.emit(lazbubu, "AdventureCreated")
            .withArgs(mintedId, user.address, adventureType, adventureContent);

        const memoryNonce = Number(await lazbubu.nextPermitNonce(mintedId));
        const memoryContent = 67890;
        const memoryHash = solidityPackedKeccak256(["uint256", "uint256"], [mintedId, memoryContent]);
        const memoryPermit = await signPermit(signer, memoryNonce, PERMIT_TYPE_CREATE_MEMORY, memoryHash, Math.floor(Date.now() / 1000) + 3600, await lazbubu.getAddress(), Number(chainId));
        await expect(lazbubu.createMemory(mintedId, memoryContent, memoryPermit))
            .to.emit(lazbubu, "MemoryCreated")
            .withArgs(mintedId, anyValue, user.address, memoryContent);

        const memoryId = ((await lazbubu.queryFilter(lazbubu.filters.MemoryCreated()))[0] as any).args?.id;
        await expect(lazbubu.connect(user).deleteMemory(mintedId, memoryId)).to.emit(lazbubu, "MemoryDeleted").withArgs(mintedId, memoryId, user.address);
    });

    it("should set personality with permit", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);

        const chainId = (await ethers.provider.getNetwork()).chainId;
        const nonce = Number(await lazbubu.nextPermitNonce(mintedId));
        const personality = "Curious";
        const hash = solidityPackedKeccak256(["uint256", "string"], [mintedId, personality]);
        const permit = await signPermit(signer, nonce, PERMIT_TYPE_SET_PERSONALITY, hash, Math.floor(Date.now() / 1000) + 3600, await lazbubu.getAddress(), Number(chainId));

        await expect(lazbubu.setPersonality(mintedId, personality, permit))
            .to.emit(lazbubu, "PersonalitySet")
            .withArgs(mintedId, user.address, personality);
        const state = await lazbubu.states(mintedId);
        expect(state.personality).to.equal(personality);
    });

    it("should set level once and prevent further updates when mature", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);

        const chainId = (await ethers.provider.getNetwork()).chainId;
        const nonce = Number(await lazbubu.nextPermitNonce(mintedId));
        const level = 3;
        const hash = solidityPackedKeccak256(["uint256", "uint8", "bool"], [mintedId, level, true]);
        const permit = await signPermit(signer, nonce, PERMIT_TYPE_SET_LEVEL, hash, Math.floor(Date.now() / 1000) + 3600, await lazbubu.getAddress(), Number(chainId));

        await expect(lazbubu.setLevel(mintedId, level, true, permit))
            .to.emit(lazbubu, "LevelSet")
            .withArgs(mintedId, user.address, level, true);

        const state = await lazbubu.states(mintedId);
        expect(state.level).to.equal(level);
        expect(state.maturity).to.be.gt(0);

        const secondHash = solidityPackedKeccak256(["uint256", "uint8", "bool"], [mintedId, 4, false]);
        const secondPermit = await signPermit(signer, Number(await lazbubu.nextPermitNonce(mintedId)), PERMIT_TYPE_SET_LEVEL, secondHash, Math.floor(Date.now() / 1000) + 3600, await lazbubu.getAddress(), Number(chainId));
        await expect(lazbubu.setLevel(mintedId, 4, false, secondPermit)).to.be.revertedWithCustomError(lazbubu, "TokenAlreadyMature");
    });

    it("should handle message quota claims correctly", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);

        const firstTx = await lazbubu.connect(user).claimMessageQuota(mintedId);
        await expect(firstTx).to.emit(lazbubu, "MessageQuotaClaimed").withArgs(mintedId, user.address);
        const firstState = await lazbubu.states(mintedId);
        expect(firstState.firstTimeMessageQuotaClaimed).to.be.gt(0);
        expect(firstState.lastTimeMessageQuotaClaimed).to.equal(firstState.firstTimeMessageQuotaClaimed);

        await time.increase(10);
        const secondTx = await lazbubu.connect(user).claimMessageQuota(mintedId);
        await expect(secondTx).to.emit(lazbubu, "MessageQuotaClaimed").withArgs(mintedId, user.address);
        const secondState = await lazbubu.states(mintedId);
        expect(secondState.firstTimeMessageQuotaClaimed).to.equal(firstState.firstTimeMessageQuotaClaimed);
        expect(secondState.lastTimeMessageQuotaClaimed).to.be.gt(firstState.lastTimeMessageQuotaClaimed);
    });

    it("should block message quota claim from non-owner", async () => {
        const { signer, user, deployer, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);
        await expect(lazbubu.claimMessageQuota(mintedId)).to.be.revertedWithCustomError(lazbubu, "NotTokenOwner");
        await expect(lazbubu.connect(deployer).claimMessageQuota(mintedId)).to.be.revertedWithCustomError(lazbubu, "NotTokenOwner");
    });

    it("should prevent transferring non-mature tokens and invalid amounts", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);

        await expect(lazbubu.connect(user).safeTransferFrom(user.address, signer.address, mintedId, 1, "0x")).to.be.revertedWithCustomError(lazbubu, "NonMatureTokenCannotBeTransferred");
        await expect(lazbubu.connect(user).safeTransferFrom(user.address, signer.address, mintedId, 0, "0x")).to.be.revertedWithCustomError(lazbubu, "InvalidAmount");
    });

    it("should allow transferring mature tokens", async () => {
        const { signer, user, lazbubu } = await loadFixture(deployFixture);
        const { mintedId } = await mintWithPermit(user, signer, lazbubu);

        const chainId = (await ethers.provider.getNetwork()).chainId;
        const nonce = Number(await lazbubu.nextPermitNonce(mintedId));
        const hash = solidityPackedKeccak256(["uint256", "uint8", "bool"], [mintedId, 1, true]);
        const permit = await signPermit(signer, nonce, PERMIT_TYPE_SET_LEVEL, hash, Math.floor(Date.now() / 1000) + 3600, await lazbubu.getAddress(), Number(chainId));
        await lazbubu.setLevel(mintedId, 1, true, permit);

        await lazbubu.connect(user).safeTransferFrom(user.address, signer.address, mintedId, 1, "0x");
        const state = await lazbubu.states(mintedId);
        expect(state.owner).to.equal(signer.address);
    });
});
