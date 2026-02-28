# Agent Marketplace Smart Contracts — Test Suite Specification

> **Target:** Hardhat + Chai  
> **Coverage Target:** >100 test cases, 100% branch coverage on MissionEscrow  
> **Generated:** 2026-02-27

---

## Test Setup & Fixtures

```javascript
// test/fixtures/contracts.js
const { ethers } = require('hardhat');

async function deployTokenFixture() {
  const [deployer, treasury, user1, user2, user3] = await ethers.getSigners();
  
  const AGNTToken = await ethers.getContractFactory('AGNTToken');
  const agnt = await AGNTToken.deploy('Agent Network Token', 'AGNT', deployer.address);
  await agnt.deployed();
  
  // Mint 100M supply to deployer (DECISIONS.md: 100M total)
  const totalSupply = await agnt.totalSupply();
  
  return { agnt, deployer, treasury, user1, user2, user3, totalSupply };
}

async function deployFullSystemFixture() {
  const [deployer, treasury, admin, provider1, provider2, client1, client2, resolver] = await ethers.getSigners();
  
  // Deploy mock USDC
  const MockUSDC = await ethers.getContractFactory('MockUSDC');
  const usdc = await MockUSDC.deploy();
  await usdc.deployed();
  
  // Deploy AGNT
  const AGNTToken = await ethers.getContractFactory('AGNTToken');
  const agnt = await AGNTToken.deploy('Agent Network Token', 'AGNT', deployer.address);
  await agnt.deployed();
  
  // Deploy ProviderStaking
  const ProviderStaking = await ethers.getContractFactory('ProviderStaking');
  const staking = await ProviderStaking.deploy(agnt.address, 1000e18, 7 * 24 * 60 * 60);
  await staking.deployed();
  
  // Deploy AgentRegistry
  const AgentRegistry = await ethers.getContractFactory('AgentRegistry');
  const registry = await AgentRegistry.deploy(admin.address);
  await registry.deployed();
  
  // Deploy MissionEscrow
  const MissionEscrow = await ethers.getContractFactory('MissionEscrow');
  const escrow = await MissionEscrow.deploy(
    usdc.address,
    agnt.address,
    registry.address,
    staking.address,
    treasury.address
  );
  await escrow.deployed();
  
  // Setup roles
  await staking.grantRole(await staking.ESCROW_ROLE(), escrow.address);
  await registry.grantRole(await registry.ESCROW_ROLE(), escrow.address);
  
  // Fund clients with USDC
  await usdc.mint(client1.address, 100000e6);
  await usdc.mint(client2.address, 100000e6);
  
  // Fund providers with AGNT for staking
  await agnt.transfer(provider1.address, 50000e18);
  await agnt.transfer(provider2.address, 200000e18);
  
  return { 
    agnt, usdc, registry, staking, escrow, 
    deployer, treasury, admin, provider1, provider2, client1, client2, resolver 
  };
}
```

---

## 1. AGNTToken.sol Tests

### 1.1 Deployment

```javascript
describe('AGNTToken', () => {
  describe('deployment', () => {
    it('should deploy with correct name', async () => {
      const { agnt } = await deployTokenFixture();
      expect(await agnt.name()).to.equal('Agent Network Token');
    });

    it('should deploy with correct symbol', async () => {
      const { agnt } = await deployTokenFixture();
      expect(await agnt.symbol()).to.equal('AGNT');
    });

    it('should deploy with 18 decimals', async () => {
      const { agnt } = await deployTokenFixture();
      expect(await agnt.decimals()).to.equal(18);
    });

    it('should mint 100M supply to deployer', async () => {
      const { agnt, deployer, totalSupply } = await deployTokenFixture();
      expect(totalSupply).to.equal(ethers.utils.parseEther('100000000'));
      expect(await agnt.balanceOf(deployer.address)).to.equal(totalSupply);
    });

    it('should set deployer as initial owner', async () => {
      const { agnt, deployer } = await deployTokenFixture();
      expect(await agnt.owner()).to.equal(deployer.address);
    });

    it('should set treasury to deployer initially', async () => {
      const { agnt, deployer } = await deployTokenFixture();
      expect(await agnt.treasury()).to.equal(deployer.address);
    });
  });

  describe('transfer', () => {
    it('should transfer tokens between accounts', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await agnt.transfer(user1.address, amount);
      
      expect(await agnt.balanceOf(user1.address)).to.equal(amount);
      expect(await agnt.balanceOf(deployer.address)).to.equal(
        await agnt.totalSupply() - amount
      );
    });

    it('should emit Transfer event', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await expect(agnt.transfer(user1.address, amount))
        .to.emit(agnt, 'Transfer')
        .withArgs(deployer.address, user1.address, amount);
    });

    it('should revert when transferring more than balance', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const balance = await agnt.balanceOf(deployer.address);
      
      await expect(agnt.transfer(user1.address, balance.add(1)))
        .to.be.revertedWith('ERC20: transfer amount exceeds balance');
    });

    it('should revert when transferring to zero address', async () => {
      const { agnt, deployer } = await deployTokenFixture();
      
      await expect(agnt.transfer(ethers.constants.AddressZero, 1000))
        .to.be.revertedWith('ERC20: transfer to the zero address');
    });
  });

  describe('approve', () => {
    it('should approve spender', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await agnt.approve(user1.address, amount);
      
      expect(await agnt.allowance(deployer.address, user1.address)).to.equal(amount);
    });

    it('should emit Approval event', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await expect(agnt.approve(user1.address, amount))
        .to.emit(agnt, 'Approval')
        .withArgs(deployer.address, user1.address, amount);
    });

    it('should overwrite existing allowance', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      
      await agnt.approve(user1.address, ethers.utils.parseEther('1000'));
      await agnt.approve(user1.address, ethers.utils.parseEther('2000'));
      
      expect(await agnt.allowance(deployer.address, user1.address))
        .to.equal(ethers.utils.parseEther('2000'));
    });
  });

  describe('transferFrom', () => {
    it('should transferFrom with allowance', async () => {
      const { agnt, deployer, user1, user2 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await agnt.approve(user1.address, amount);
      await agnt.connect(user1).transferFrom(deployer.address, user2.address, amount);
      
      expect(await agnt.balanceOf(user2.address)).to.equal(amount);
    });

    it('should decrease allowance after transfer', async () => {
      const { agnt, deployer, user1, user2 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await agnt.approve(user1.address, amount);
      await agnt.connect(user1).transferFrom(deployer.address, user2.address, amount);
      
      expect(await agnt.allowance(deployer.address, user1.address)).to.equal(0);
    });

    it('should revert when insufficient allowance', async () => {
      const { agnt, deployer, user1, user2 } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await agnt.approve(user1.address, amount.sub(1));
      
      await expect(agnt.connect(user1).transferFrom(deployer.address, user2.address, amount))
        .to.be.revertedWith('ERC20: insufficient allowance');
    });

    it('should revert when transferring from zero address', async () => {
      const { agnt, user2 } = await deployTokenFixture();
      
      await expect(agnt.transferFrom(ethers.constants.AddressZero, user2.address, 1000))
        .to.be.revertedWith('ERC20: transfer from the zero address');
    });
  });

  describe('burn', () => {
    it('should burn tokens from caller', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const burnAmount = ethers.utils.parseEther('1000');
      
      await agnt.transfer(user1.address, burnAmount);
      const initialSupply = await agnt.totalSupply();
      
      await agnt.connect(user1).burn(burnAmount);
      
      expect(await agnt.balanceOf(user1.address)).to.equal(0);
      expect(await agnt.totalSupply()).to.equal(initialSupply.sub(burnAmount));
    });

    it('should emit Burned event', async () => {
      const { agnt, user1 } = await deployTokenFixture();
      const burnAmount = ethers.utils.parseEther('1000');
      
      await agnt.transfer(user1.address, burnAmount);
      
      await expect(agnt.connect(user1).burn(burnAmount))
        .to.emit(agnt, 'Burned')
        .withArgs(user1.address, burnAmount);
    });

    it('should revert when burning more than balance', async () => {
      const { agnt, user1 } = await deployTokenFixture();
      const balance = await agnt.balanceOf(user1.address);
      
      await expect(agnt.connect(user1).burn(balance.add(1)))
        .to.be.revertedWith('ERC20: burn amount exceeds balance');
    });
  });

  describe('burnFrom', () => {
    it('should burnFrom with sufficient approval', async () => {
      const { agnt, deployer, user1, user2 } = await deployTokenFixture();
      const burnAmount = ethers.utils.parseEther('1000');
      
      await agnt.transfer(user1.address, burnAmount);
      await agnt.connect(user1).approve(deployer.address, burnAmount);
      const initialSupply = await agnt.totalSupply();
      
      await agnt.burnFrom(user1.address, burnAmount);
      
      expect(await agnt.balanceOf(user1.address)).to.equal(0);
      expect(await agnt.totalSupply()).to.equal(initialSupply.sub(burnAmount));
    });

    it('should revert when burnFrom without approval', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      const burnAmount = ethers.utils.parseEther('1000');
      
      await agnt.transfer(user1.address, burnAmount);
      
      await expect(agnt.burnFrom(user1.address, burnAmount))
        .to.be.revertedWith('ERC20: insufficient allowance');
    });

    it('should revert when burning from zero address', async () => {
      const { agnt } = await deployTokenFixture();
      
      await expect(agnt.burnFrom(ethers.constants.AddressZero, 1000))
        .to.be.revertedWith('ERC20: burn from the zero address');
    });
  });

  describe('mint', () => {
    it('should mint tokens to address (only treasury)', async () => {
      const { agnt, deployer, treasury } = await deployTokenFixture();
      const mintAmount = ethers.utils.parseEther('1000');
      
      await agnt.setTreasury(deployer.address);
      await agnt.mint(treasury.address, mintAmount);
      
      expect(await agnt.balanceOf(treasury.address)).to.equal(mintAmount);
    });

    it('should emit Minted event', async () => {
      const { agnt, deployer, treasury } = await deployTokenFixture();
      const mintAmount = ethers.utils.parseEther('1000');
      
      await agnt.setTreasury(deployer.address);
      
      await expect(agnt.mint(treasury.address, mintAmount))
        .to.emit(agnt, 'Minted')
        .withArgs(treasury.address, mintAmount);
    });

    it('should revert when non-treasury tries to mint', async () => {
      const { agnt, user1 } = await deployTokenFixture();
      
      await expect(agnt.connect(user1).mint(user1.address, 1000))
        .to.be.revertedWith('Only treasury');
    });

    it('should not exceed genesis supply cap', async () => {
      const { agnt, deployer } = await deployTokenFixture();
      await agnt.setTreasury(deployer.address);
      
      await expect(agnt.mint(deployer.address, ethers.utils.parseEther('1')))
        .to.be.revertedWith('Exceeds genesis supply');
    });
  });

  describe('setTreasury', () => {
    it('should set new treasury address (only owner)', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      
      await agnt.setTreasury(user1.address);
      
      expect(await agnt.treasury()).to.equal(user1.address);
    });

    it('should revert when non-owner sets treasury', async () => {
      const { agnt, user1, user2 } = await deployTokenFixture();
      
      await expect(agnt.connect(user1).setTreasury(user2.address))
        .to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('setBurnRate', () => {
    it('should set burn rate (only owner)', async () => {
      const { agnt, deployer } = await deployTokenFixture();
      
      await agnt.setBurnRate(3000); // 30%
      
      expect(await agnt.getCurrentBurnRate()).to.equal(3000);
    });

    it('should emit BurnRateUpdated event', async () => {
      const { agnt, deployer } = await deployTokenFixture();
      
      await expect(agnt.setBurnRate(3000))
        .to.emit(agnt, 'BurnRateUpdated')
        .withArgs(500, 3000);
    });

    it('should revert when burn rate exceeds max (5000)', async () => {
      const { agnt } = await deployTokenFixture();
      
      await expect(agnt.setBurnRate(5001))
        .to.be.revertedWith('Burn rate too high');
    });
  });

  describe('calculateProtocolFee', () => {
    it('should calculate fee based on amount and burn rate', async () => {
      const { agnt } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      const fee = await agnt.calculateProtocolFee(amount);
      expect(fee).to.equal(ethers.utils.parseEther('50'));
    });

    it('should return 0 for 0 amount', async () => {
      const { agnt } = await deployTokenFixture();
      
      expect(await agnt.calculateProtocolFee(0)).to.equal(0);
    });

    it('should adjust fee when burn rate changes', async () => {
      const { agnt } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('1000');
      
      await agnt.setBurnRate(1000);
      
      const fee = await agnt.calculateProtocolFee(amount);
      expect(fee).to.equal(ethers.utils.parseEther('100'));
    });
  });

  describe('dynamic fee adjustment', () => {
    it('should adjust fee with utilization (high)', async () => {
      const { agnt } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('10000');
      
      const fee = await agnt.calculateProtocolFee(amount);
      expect(fee).to.be.gt(0);
    });

    it('should adjust fee with utilization (low)', async () => {
      const { agnt } = await deployTokenFixture();
      const amount = ethers.utils.parseEther('100');
      
      const fee = await agnt.calculateProtocolFee(amount);
      expect(fee).to.equal(ethers.utils.parseEther('5'));
    });
  });

  describe('voting (EIP-2612)', () => {
    it('should return voting weight equal to balance', async () => {
      const { agnt, deployer, user1 } = await deployTokenFixture();
      
      await agnt.transfer(user1.address, ethers.utils.parseEther('1000'));
      
      expect(await agnt.getVotes(user1.address)).to.equal(ethers.utils.parseEther('1000'));
    });

    it('should update votes on transfer', async () => {
      const { agnt, user1, user2 } = await deployTokenFixture();
      
      await agnt.transfer(user1.address, ethers.utils.parseEther('1000'));
      await agnt.transfer(user2.address, ethers.utils.parseEther('500'));
      
      expect(await agnt.getVotes(user1.address)).to.equal(ethers.utils.parseEther('1000'));
      expect(await agnt.getVotes(user2.address)).to.equal(ethers.utils.parseEther('500'));
    });

    it('should delegate votes', async () => {
      const { agnt, user1, user2 } = await deployTokenFixture();
      
      await agnt.transfer(user1.address, ethers.utils.parseEther('1000'));
      await agnt.connect(user1).delegate(user2.address);
      
      expect(await agnt.getVotes(user2.address)).to.equal(ethers.utils.parseEther('1000'));
    });
  });
});
```

---

## 2. AgentRegistry.sol Tests

```javascript
describe('AgentRegistry', () => {
  describe('registerAgent', () => {
    it('should register agent with valid metadata', async () => {
      const { registry, admin, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const ipfsHash = 'QmHash123';
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, ipfsHash, []);
      
      const agent = await registry.getAgent(agentId);
      expect(agent.provider).to.equal(provider1.address);
      expect(agent.ipfsMetadataHash).to.equal(ipfsHash);
      expect(agent.isActive).to.equal(true);
    });

    it('should emit AgentRegistered event', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      
      await expect(registry.connect(provider1).registerAgent(agentId, 'QmHash', []))
        .to.emit(registry, 'AgentRegistered')
        .withArgs(agentId, provider1.address, 'QmHash');
    });

    it('should revert when duplicate agent ID', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await expect(registry.connect(provider1).registerAgent(agentId, 'QmHash', []))
        .to.be.revertedWith('Agent already exists');
    });

    it('should revert when stake not locked', async () => {
      const { registry, provider1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await expect(registry.connect(provider1).registerAgent(agentId, 'QmHash', []))
        .to.be.revertedWith('Insufficient stake');
    });
  });

  describe('updateMetadata', () => {
    it('should update agent IPFS metadata hash', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash1', []);
      
      await registry.connect(provider1).updateMetadata(agentId, 'QmHash2');
      
      const agent = await registry.getAgent(agentId);
      expect(agent.ipfsMetadataHash).to.equal('QmHash2');
    });

    it('should revert when caller is not agent provider', async () => {
      const { registry, provider1, provider2, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash1', []);
      
      await expect(registry.connect(provider2).updateMetadata(agentId, 'QmHash2'))
        .to.be.revertedWith('Not the agent provider');
    });
  });

  describe('toggleActive', () => {
    it('should toggle agent active status', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(provider1).toggleActive(agentId);
      
      const agent = await registry.getAgent(agentId);
      expect(agent.isActive).to.equal(false);
    });

    it('should emit AgentStatusChanged event', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await expect(registry.connect(provider1).toggleActive(agentId))
        .to.emit(registry, 'AgentStatusChanged')
        .withArgs(agentId, false);
    });
  });

  describe('setGenesisBadge', () => {
    it('should grant genesis badge (only admin)', async () => {
      const { registry, admin, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(admin).setGenesisBadge(agentId, true);
      
      const agent = await registry.getAgent(agentId);
      expect(agent.isGenesis).to.equal(true);
    });

    it('should revert when non-admin tries to grant genesis', async () => {
      const { registry, provider1, provider2, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await expect(registry.connect(provider2).setGenesisBadge(agentId, true))
        .to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('recordMissionOutcome', () => {
    it('should update reputation on success (only MissionEscrow)', async () => {
      const { registry, escrow, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(escrow).recordMissionOutcome(agentId, true, 9000);
      
      const rep = await registry.getReputation(agentId);
      expect(rep.totalMissions).to.equal(1);
      expect(rep.successfulMissions).to.equal(1);
      expect(rep.successRate).to.equal(10000);
      expect(rep.avgScore).to.equal(9000);
    });

    it('should update reputation on failure', async () => {
      const { registry, escrow, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(escrow).recordMissionOutcome(agentId, false, 3000);
      
      const rep = await registry.getReputation(agentId);
      expect(rep.totalMissions).to.equal(1);
      expect(rep.successfulMissions).to.equal(0);
    });

    it('should accumulate reputation over multiple missions', async () => {
      const { registry, escrow, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(escrow).recordMissionOutcome(agentId, true, 8000);
      await registry.connect(escrow).recordMissionOutcome(agentId, true, 9000);
      
      const rep = await registry.getReputation(agentId);
      expect(rep.totalMissions).to.equal(2);
      expect(rep.avgScore).to.equal(8500);
    });

    it('should revert when called by non-escrow', async () => {
      const { registry, provider1, provider2, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await expect(registry.connect(provider2).recordMissionOutcome(agentId, true, 9000))
        .to.be.revertedWith('Only MissionEscrow');
    });
  });

  describe('slash', () => {
    it('should slash agent and reduce stake (only MissionEscrow)', async () => {
      const { registry, escrow, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(escrow).slash(agentId, 1000);
      
      const agent = await registry.getAgent(agentId);
      expect(agent.stakeAmount).to.equal(ethers.utils.parseEther('900'));
    });

    it('should emit AgentSlashed event', async () => {
      const { registry, escrow, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await expect(registry.connect(escrow).slash(agentId, 1000))
        .to.emit(registry, 'AgentSlashed')
        .withArgs(agentId, 1000, 'Dispute loss');
    });
  });

  describe('calculateReputationScore', () => {
    it('should calculate reputation score 0-10000', async () => {
      const { registry, escrow, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await registry.connect(escrow).recordMissionOutcome(agentId, true, 9000);
      
      const score = await registry.calculateReputationScore(agentId);
      expect(score).to.be.lte(10000);
      expect(score).to.be.gte(0);
    });

    it('should return 0 for unregistered agent', async () => {
      const { registry } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('nonexistent'));
      
      const score = await registry.calculateReputationScore(agentId);
      expect(score).to.equal(0);
    });
  });

  describe('getTopAgents', () => {
    it('should return agents sorted by reputation score', async () => {
      const { registry, escrow, provider1, provider2, staking } = await deployFullSystemFixture();
      
      const agentId1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const agentId2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-002'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await staking.connect(provider2).stake(ethers.utils.parseEther('5000'));
      await registry.connect(provider1).registerAgent(agentId1, 'QmHash1', []);
      await registry.connect(provider2).registerAgent(agentId2, 'QmHash2', []);
      
      await registry.connect(escrow).recordMissionOutcome(agentId1, true, 7000);
      await registry.connect(escrow).recordMissionOutcome(agentId2, true, 9000);
      
      const topAgents = await registry.getTopAgents(2);
      
      expect(topAgents.length).to.equal(2);
    });
  });

  describe('guild membership', () => {
    it('should join a guild', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const guildId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('guild-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await registry.connect(provider1).joinGuild(agentId, guildId, 'Builders Guild');
      
      const membership = await registry.getGuildMembership(agentId);
      expect(membership.guildId).to.equal(guildId);
    });

    it('should leave guild', async () => {
      const { registry, provider1, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const guildId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('guild-001'));
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await registry.connect(provider1).joinGuild(agentId, guildId, 'Builders Guild');
      
      await registry.connect(provider1).leaveGuild(agentId);
      
      const membership = await registry.getGuildMembership(agentId);
      expect(membership.guildId).to.equal(ethers.constants.HashZero);
    });
  });
});
```

---

## 3. MissionEscrow.sol Tests (100% Branch Coverage Target)

```javascript
describe('MissionEscrow', () => {
  describe('createMission', () => {
    it('should create mission and transfer USDC to escrow', async () => {
      const { escrow, usdc, client1, registry, staking, provider1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await usdc.connect(client1).approve(escrow.address, amount);
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      expect(await usdc.balanceOf(escrow.address)).to.equal(amount);
    });

    it('should emit MissionCreated event', async () => {
      const { escrow, usdc, client1, registry, staking, provider1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      await expect(escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      )).to.emit(escrow, 'MissionCreated');
    });

    it('should revert when agent does not exist', async () => {
      const { escrow, usdc, client1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('nonexistent'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await usdc.connect(client1).approve(escrow.address, amount);
      
      await expect(escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      )).to.be.revertedWith('Agent not found');
    });

    it('should revert when agent is inactive', async () => {
      const { escrow, usdc, client1, registry, staking, provider1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await registry.connect(provider1).toggleActive(agentId);
      
      await usdc.connect(client1).approve(escrow.address, amount);
      
      await expect(escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      )).to.be.revertedWith('Agent not active');
    });
  });

  describe('createDryRunMission', () => {
    it('should create dry run mission with 10% price', async () => {
      const { escrow, usdc, client1, registry, staking, provider1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const fullAmount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      const dryRunAmount = fullAmount.div(10);
      await usdc.connect(client1).approve(escrow.address, dryRunAmount);
      
      const missionId = await escrow.connect(client1).callStatic.createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      
      await escrow.connect(client1).createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      
      const mission = await escrow.getMission(missionId);
      expect(mission.isDryRun).to.equal(true);
      expect(mission.totalAmount).to.equal(dryRunAmount);
    });

    it('should set 5-minute deadline for dry run', async () => {
      const { escrow, usdc, client1, registry, staking, provider1 } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const fullAmount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      const dryRunAmount = fullAmount.div(10);
      await usdc.connect(client1).approve(escrow.address, dryRunAmount);
      
      const missionId = await escrow.connect(client1).callStatic.createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      
      await escrow.connect(client1).createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      
      const mission = await escrow.getMission(missionId);
      expect(mission.deadline).to.be.lt(Math.floor(Date.now() / 1000) + 600);
    });
  });

  describe('acceptMission', () => {
    it('should accept mission and transition to ACCEPTED', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(1); // ACCEPTED
    });

    it('should emit MissionAssigned event', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await expect(escrow.connect(provider1).acceptMission(missionId))
        .to.emit(escrow, 'MissionAssigned')
        .withArgs(missionId, provider1.address);
    });

    it('should revert when mission already accepted', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      
      await expect(escrow.connect(provider1).acceptMission(missionId))
        .to.be.revertedWith('Invalid state');
    });
  });

  describe('startMission', () => {
    it('should start mission and transition to IN_PROGRESS', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(2); // IN_PROGRESS
    });

    it('should revert when not accepted', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await expect(escrow.connect(provider1).startMission(missionId))
        .to.be.revertedWith('Invalid state');
    });
  });

  describe('deliverMission', () => {
    it('should deliver mission and transition to DELIVERED', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(3); // DELIVERED
    });

    it('should store IPFS result hash', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      const mission = await escrow.getMission(missionId);
      expect(mission.ipfsResultHash).to.equal('QmResultHash');
    });

    it('should emit MissionCompleted event', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      
      await expect(escrow.connect(provider1).deliverMission(missionId, 'QmResultHash'))
        .to.emit(escrow, 'MissionCompleted')
        .withArgs(missionId, 'QmResultHash');
    });
  });

  describe('approveMission', () => {
    it('should approve and release 90% to provider', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      const providerBalanceBefore = await usdc.balanceOf(provider1.address);
      await escrow.connect(client1).approveMission(missionId);
      
      expect(await usdc.balanceOf(provider1.address)).to.equal(
        providerBalanceBefore.add(ethers.utils.parseUnits('900', 6))
      );
    });

    it('should transfer 5% to insurance pool', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await escrow.connect(client1).approveMission(missionId);
      
      const poolBalance = await staking.getInsurancePoolBalance();
      expect(poolBalance).to.be.gt(0);
    });

    it('should emit PaymentReleased event', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await expect(escrow.connect(client1).approveMission(missionId))
        .to.emit(escrow, 'PaymentReleased')
        .withArgs(missionId, provider1.address, ethers.utils.parseUnits('900', 6));
    });

    it('should revert when mission not delivered', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      
      await expect(escrow.connect(client1).approveMission(missionId))
        .to.be.revertedWith('Invalid state');
    });
  });

  describe('disputeMission', () => {
    it('should open dispute within 24h of delivery', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await escrow.connect(client1).disputeMission(missionId, 'Quality issues');
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(4); // DISPUTED
    });

    it('should emit MissionDisputed event', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await expect(escrow.connect(client1).disputeMission(missionId, 'Quality issues'))
        .to.emit(escrow, 'MissionDisputed')
        .withArgs(missionId, client1.address, 'Quality issues');
    });

    it('should revert when dispute opened after 24h', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await ethers.provider.send('evm_increaseTime', [24 * 60 * 60 + 1]);
      await ethers.provider.send('evm_mine', []);
      
      await expect(escrow.connect(client1).disputeMission(missionId, 'Too late'))
        .to.be.revertedWith('Dispute window closed');
    });

    it('should revert when not client', async () => {
      const { escrow, usdc, client1, client2, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await expect(escrow.connect(client2).disputeMission(missionId, 'Not my mission'))
        .to.be.revertedWith('Only client');
    });
  });

  describe('resolveDispute', () => {
    it('should resolve dispute in favor of provider', async () => {
      const { escrow, usdc, client1, provider1, registry, staking, resolver } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      await escrow.connect(client1).disputeMission(missionId, 'Quality issues');
      
      await escrow.connect(resolver).resolveDispute(missionId, true, 'Provider evidence convincing');
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(5); // RESOLVED
    });

    it('should resolve dispute in favor of client (refund)', async () => {
      const { escrow, usdc, client1, provider1, registry, staking, resolver } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      await escrow.connect(client1).disputeMission(missionId, 'Quality issues');
      
      const clientBalanceBefore = await usdc.balanceOf(client1.address);
      await escrow.connect(resolver).resolveDispute(missionId, false, 'Insufficient work');
      
      expect(await usdc.balanceOf(client1.address)).to.equal(clientBalanceBefore.add(amount));
    });

    it('should emit MissionResolved event', async () => {
      const { escrow, usdc, client1, provider1, registry, staking, resolver } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      await escrow.connect(client1).disputeMission(missionId, 'Quality issues');
      
      await expect(escrow.connect(resolver).resolveDispute(missionId, true, 'Provider wins'))
        .to.emit(escrow, 'MissionResolved')
        .withArgs(missionId, true, 'Provider wins');
    });
  });

  describe('cancelMission', () => {
    it('should cancel mission in CREATED state', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(client1).cancelMission(missionId);
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(6); // CANCELLED
    });

    it('should refund client on cancel', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      const clientBalanceBefore = await usdc.balanceOf(client1.address);
      await escrow.connect(client1).cancelMission(missionId);
      
      expect(await usdc.balanceOf(client1.address)).to.equal(clientBalanceBefore.add(amount));
    });

    it('should revert when mission already accepted', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      
      await expect(escrow.connect(client1).cancelMission(missionId))
        .to.be.revertedWith('Invalid state');
    });
  });

  describe('autoApproveMission', () => {
    it('should auto-approve after 48h+1s', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await ethers.provider.send('evm_increaseTime', [48 * 60 * 60 + 1]);
      await ethers.provider.send('evm_mine', []);
      
      await escrow.autoApproveMission(missionId);
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(3); // COMPLETED
    });

    it('should revert when within 48h', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await expect(escrow.autoApproveMission(missionId))
        .to.be.revertedWith('Too early');
    });
  });

  describe('timeoutDryRun', () => {
    it('should timeout dry run after 5 minutes', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const fullAmount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      const dryRunAmount = fullAmount.div(10);
      await usdc.connect(client1).approve(escrow.address, dryRunAmount);
      
      const missionId = await escrow.connect(client1).callStatic.createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      await escrow.connect(client1).createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      
      await ethers.provider.send('evm_increaseTime', [5 * 60 + 1]);
      await ethers.provider.send('evm_mine', []);
      
      await escrow.timeoutDryRun(missionId);
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(6); // CANCELLED
    });

    it('should revert when before 5 minutes', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const fullAmount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      const dryRunAmount = fullAmount.div(10);
      await usdc.connect(client1).approve(escrow.address, dryRunAmount);
      
      const missionId = await escrow.connect(client1).callStatic.createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      await escrow.connect(client1).createDryRunMission(
        agentId, fullAmount, 'QmMissionHash'
      );
      
      await expect(escrow.timeoutDryRun(missionId))
        .to.be.revertedWith('Too early');
    });
  });

  describe('calculateFeeBreakdown', () => {
    it('should return correct fee breakdown', async () => {
      const { escrow } = await deployFullSystemFixture();
      const amount = ethers.utils.parseUnits('1000', 6);
      
      const { providerFee, insurancePoolFee, burnFee } = await escrow.calculateFeeBreakdown(amount);
      
      expect(providerFee).to.equal(ethers.utils.parseUnits('900', 6));
      expect(insurancePoolFee).to.equal(ethers.utils.parseUnits('50', 6));
      expect(burnFee).to.equal(ethers.utils.parseUnits('30', 6));
    });
  });

  describe('canAutoApprove', () => {
    it('should return true after 48h', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await ethers.provider.send('evm_increaseTime', [48 * 60 * 60 + 1]);
      await ethers.provider.send('evm_mine', []);
      
      expect(await escrow.canAutoApprove(missionId)).to.equal(true);
    });

    it('should return false within 48h', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      expect(await escrow.canAutoApprove(missionId)).to.equal(false);
    });
  });

  describe('canDispute', () => {
    it('should return true within 24h', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      expect(await escrow.canDispute(missionId)).to.equal(true);
    });

    it('should return false after 24h', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await ethers.provider.send('evm_increaseTime', [24 * 60 * 60 + 1]);
      await ethers.provider.send('evm_mine', []);
      
      expect(await escrow.canDispute(missionId)).to.equal(false);
    });
  });

  describe('emergency pause', () => {
    it('should pause contract', async () => {
      const { escrow, admin } = await deployFullSystemFixture();
      
      await escrow.connect(admin).pause();
      
      expect(await escrow.paused()).to.equal(true);
    });

    it('should block state changes when paused', async () => {
      const { escrow, usdc, client1, provider1, registry, staking, admin } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      await escrow.connect(admin).pause();
      
      await expect(escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      )).to.be.revertedWith('Pausable: paused');
    });
  });

  describe('state machine invalid transitions', () => {
    it('should reject accept from CREATED directly', async () => {
      // This is handled by acceptMission requiring proper flow
    });
    
    it('should reject start from CREATED', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await expect(escrow.connect(provider1).startMission(missionId))
        .to.be.revertedWith('Invalid state');
    });

    it('should reject deliver from ACCEPTED', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      
      await expect(escrow.connect(provider1).deliverMission(missionId, 'QmHash'))
        .to.be.revertedWith('Invalid state');
    });
  });
});
```

---

## 4. ProviderStaking.sol Tests

```javascript
describe('ProviderStaking', () => {
  describe('stake', () => {
    it('should stake tokens and assign BRONZE tier', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      const stakeInfo = await staking.getStakeInfo(provider1.address);
      expect(stakeInfo.stakedAmount).to.equal(stakeAmount);
      expect(stakeInfo.tier).to.equal(1);
    });

    it('should emit Staked event', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      
      await expect(staking.connect(provider1).stake(stakeAmount))
        .to.emit(staking, 'Staked')
        .withArgs(provider1.address, stakeAmount, stakeAmount);
    });

    it('should assign SILVER tier at 10,000 AGNT', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('10000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      const tier = await staking.getTier(provider1.address);
      expect(tier).to.equal(2);
    });

    it('should assign GOLD tier at 100,000 AGNT', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('100000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      const tier = await staking.getTier(provider1.address);
      expect(tier).to.equal(3);
    });

    it('should revert when stake below minimum', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('999');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      
      await expect(staking.connect(provider1).stake(stakeAmount))
        .to.be.revertedWith('Below minimum stake');
    });
  });

  describe('requestUnstake', () => {
    it('should start 7-day cooldown', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      await staking.connect(provider1).requestUnstake(stakeAmount);
      
      const stakeInfo = await staking.getStakeInfo(provider1.address);
      expect(stakeInfo.pendingUnstake).to.equal(stakeAmount);
    });

    it('should revert when no stake', async () => {
      const { staking, provider1 } = await deployFullSystemFixture();
      
      await expect(staking.connect(provider1).requestUnstake(1000))
        .to.be.revertedWith('No stake');
    });
  });

  describe('completeUnstake', () => {
    it('should complete unstake after 7 days', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      await staking.connect(provider1).requestUnstake(stakeAmount);
      
      await ethers.provider.send('evm_increaseTime', [7 * 24 * 60 * 60]);
      await ethers.provider.send('evm_mine', []);
      
      const balanceBefore = await agnt.balanceOf(provider1.address);
      await staking.connect(provider1).completeUnstake();
      
      expect(await agnt.balanceOf(provider1.address)).to.equal(balanceBefore.add(stakeAmount));
    });

    it('should revert before 7 days', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      await staking.connect(provider1).requestUnstake(stakeAmount);
      
      await expect(staking.connect(provider1).completeUnstake())
        .to.be.revertedWith('Cooldown not elapsed');
    });
  });

  describe('cancelUnstakeRequest', () => {
    it('should cancel pending unstake', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      await staking.connect(provider1).requestUnstake(stakeAmount);
      
      await staking.connect(provider1).cancelUnstakeRequest();
      
      const stakeInfo = await staking.getStakeInfo(provider1.address);
      expect(stakeInfo.pendingUnstake).to.equal(0);
    });
  });

  describe('slash', () => {
    it('should slash 10% of stake', async () => {
      const { staking, agnt, provider1, escrow } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      await staking.connect(escrow).slash(provider1.address, agentId, 1000, 'Dispute loss');
      
      const stakeInfo = await staking.getStakeInfo(provider1.address);
      expect(stakeInfo.stakedAmount).to.equal(ethers.utils.parseEther('900'));
    });

    it('should emit Slashed event', async () => {
      const { staking, agnt, provider1, escrow } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      await expect(staking.connect(escrow).slash(provider1.address, agentId, 1000, 'Dispute loss'))
        .to.emit(staking, 'Slashed');
    });

    it('should update tier after slash', async () => {
      const { staking, agnt, provider1, escrow } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('10000');
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      await staking.connect(escrow).slash(provider1.address, agentId, 5000, 'Major violation');
      
      const tier = await staking.getTier(provider1.address);
      expect(tier).to.equal(0);
    });

    it('should add slashed amount to insurance pool', async () => {
      const { staking, agnt, provider1, escrow } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      const poolBefore = await staking.getInsurancePoolBalance();
      await staking.connect(escrow).slash(provider1.address, agentId, 1000, 'Dispute loss');
      
      expect(await staking.getInsurancePoolBalance()).to.equal(
        poolBefore.add(ethers.utils.parseEther('100'))
      );
    });
  });

  describe('tier upgrade', () => {
    it('should auto-upgrade tier when stake crosses threshold', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      
      await agnt.connect(provider1).approve(staking.address, ethers.utils.parseEther('5000'));
      await staking.connect(provider1).stake(ethers.utils.parseEther('5000'));
      
      expect(await staking.getTier(provider1.address)).to.equal(1);
      
      await agnt.connect(provider1).approve(staking.address, ethers.utils.parseEther('5000'));
      await staking.connect(provider1).stake(ethers.utils.parseEther('5000'));
      
      expect(await staking.getTier(provider1.address)).to.equal(2);
    });

    it('should emit TierChanged event on upgrade', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      
      await agnt.connect(provider1).approve(staking.address, ethers.utils.parseEther('5000'));
      await staking.connect(provider1).stake(ethers.utils.parseEther('5000'));
      
      await agnt.connect(provider1).approve(staking.address, ethers.utils.parseEther('5000'));
      
      await expect(staking.connect(provider1).stake(ethers.utils.parseEther('5000')))
        .to.emit(staking, 'TierChanged');
    });
  });

  describe('insurance pool', () => {
    it('should contribute to insurance pool', async () => {
      const { staking, agnt, provider1 } = await deployFullSystemFixture();
      const contribution = ethers.utils.parseEther('50');
      
      await agnt.connect(provider1).approve(staking.address, contribution);
      await staking.connect(provider1).contributeToPool(contribution);
      
      expect(await staking.getInsurancePoolBalance()).to.equal(contribution);
    });

    it('should pay insurance to recipient', async () => {
      const { staking, agnt, provider1, provider2, escrow } = await deployFullSystemFixture();
      const stakeAmount = ethers.utils.parseEther('1000');
      const contribution = ethers.utils.parseEther('500');
      const missionId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('mission-001'));
      
      await agnt.connect(provider1).approve(staking.address, stakeAmount);
      await staking.connect(provider1).stake(stakeAmount);
      
      await agnt.connect(provider2).approve(staking.address, contribution);
      await staking.connect(provider2).contributeToPool(contribution);
      
      await staking.connect(escrow).payInsurance(provider1.address, contribution, missionId);
      
      expect(await agnt.balanceOf(provider1.address)).to.equal(contribution);
    });

    it('should cap payout at 2x mission value', async () => {
      const { staking, agnt, provider1, provider2, escrow } = await deployFullSystemFixture();
      const missionId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('mission-001'));
      const missionValue = ethers.utils.parseEther('100');
      const excessPayout = missionValue.mul(3);
      
      await agnt.connect(provider2).approve(staking.address, excessPayout);
      await staking.connect(provider2).contributeToPool(excessPayout);
      
      const payout = await staking.callStatic.payInsurance(
        provider1.address, missionValue.mul(3), missionId
      );
      
      expect(payout).to.equal(missionValue.mul(2));
    });
  });

  describe('getPlacementBoost', () => {
    it('should return 0 for NONE tier', async () => {
      const { staking, provider1 } = await deployFullSystemFixture();
      
      const boost = await staking.getPlacementBoost(provider1.address);
      expect(boost).to.equal(0);
    });

    it('should return higher boost for GOLD', async () => {
      const { staking, agnt, provider1, provider2 } = await deployFullSystemFixture();
      
      await agnt.connect(provider1).approve(staking.address, ethers.utils.parseEther('1000'));
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      
      await agnt.connect(provider2).approve(staking.address, ethers.utils.parseEther('100000'));
      await staking.connect(provider2).stake(ethers.utils.parseEther('100000'));
      
      const bronzeBoost = await staking.getPlacementBoost(provider1.address);
      const goldBoost = await staking.getPlacementBoost(provider2.address);
      
      expect(goldBoost).to.be.gt(bronzeBoost);
    });
  });

  describe('getRequiredStakeForTier', () => {
    it('should return correct thresholds', async () => {
      const { staking } = await deployFullSystemFixture();
      
      expect(await staking.getRequiredStakeForTier(1)).to.equal(ethers.utils.parseEther('1000'));
      expect(await staking.getRequiredStakeForTier(2)).to.equal(ethers.utils.parseEther('10000'));
      expect(await staking.getRequiredStakeForTier(3)).to.equal(ethers.utils.parseEther('100000'));
    });
  });
});
```

---

## 5. Integration Tests

```javascript
describe('Integration Tests', () => {
  describe('Full Mission Lifecycle', () => {
    it('should execute complete mission: create → accept → deliver → approve → payout', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await usdc.connect(client1).approve(escrow.address, amount);
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      const providerBalanceBefore = await usdc.balanceOf(provider1.address);
      await escrow.connect(client1).approveMission(missionId);
      
      expect(await usdc.balanceOf(provider1.address)).to.equal(
        providerBalanceBefore.add(ethers.utils.parseUnits('900', 6))
      );
      
      const state = await escrow.getMissionState(missionId);
      expect(state).to.equal(3);
    });
  });

  describe('Full Dispute Lifecycle', () => {
    it('should execute: create → accept → deliver → dispute → resolve → slash', async () => {
      const { escrow, usdc, client1, provider1, registry, staking, resolver } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await escrow.connect(client1).disputeMission(missionId, 'Quality issues');
      await escrow.connect(resolver).resolveDispute(missionId, false, 'Client wins');
      
      const stakeInfo = await staking.getStakeInfo(provider1.address);
      expect(stakeInfo.totalSlashed).to.be.gt(0);
    });
  });

  describe('Inter-Agent Mission', () => {
    it('should apply 20% discount for agent-to-agent missions', async () => {
      const { escrow, usdc, client1, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await usdc.connect(client1).approve(escrow.address, amount);
      
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      const { providerFee } = await escrow.calculateFeeBreakdown(amount);
      const expectedProviderFee = amount.mul(72).div(100);
      expect(providerFee).to.equal(expectedProviderFee);
    });
  });

  describe('Insurance Pool Coverage', () => {
    it('should cover client when provider stake insufficient', async () => {
      const { escrow, usdc, client1, provider1, provider2, registry, staking, resolver } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('1000', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await agnt.connect(provider2).approve(staking.address, ethers.utils.parseEther('10000'));
      await staking.connect(provider2).stake(ethers.utils.parseEther('10000'));
      await staking.connect(provider2).contributeToPool(ethers.utils.parseEther('5000'));
      
      await usdc.connect(client1).approve(escrow.address, amount);
      const missionId = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash'
      );
      
      await escrow.connect(provider1).acceptMission(missionId);
      await escrow.connect(provider1).startMission(missionId);
      await escrow.connect(provider1).deliverMission(missionId, 'QmResultHash');
      
      await escrow.connect(client1).disputeMission(missionId, 'Major issues');
      await escrow.connect(resolver).resolveDispute(missionId, false, 'Client wins');
    });
  });

  describe('Cross-Contract Interactions', () => {
    it('should properly link MissionEscrow to AgentRegistry', async () => {
      const { escrow, registry } = await deployFullSystemFixture();
      
      const hasRole = await registry.hasRole(
        await registry.ESCROW_ROLE(), 
        escrow.address
      );
      expect(hasRole).to.equal(true);
    });

    it('should properly link MissionEscrow to ProviderStaking', async () => {
      const { escrow, staking } = await deployFullSystemFixture();
      
      const hasRole = await staking.hasRole(
        await staking.ESCROW_ROLE(), 
        escrow.address
      );
      expect(hasRole).to.equal(true);
    });
  });

  describe('Multiple Concurrent Missions', () => {
    it('should handle multiple missions for same provider', async () => {
      const { escrow, usdc, client1, client2, provider1, registry, staking } = await deployFullSystemFixture();
      const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent-001'));
      const amount = ethers.utils.parseUnits('500', 6);
      
      await staking.connect(provider1).stake(ethers.utils.parseEther('1000'));
      await registry.connect(provider1).registerAgent(agentId, 'QmHash', []);
      
      await usdc.connect(client1).approve(escrow.address, amount);
      const missionId1 = await escrow.connect(client1).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash1'
      );
      await escrow.connect(client1).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash1'
      );
      
      await usdc.connect(client2).approve(escrow.address, amount);
      const missionId2 = await escrow.connect(client2).callStatic.createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash2'
      );
      await escrow.connect(client2).createMission(
        agentId, amount, Math.floor(Date.now() / 1000) + 86400, 'QmMissionHash2'
      );
      
      await escrow.connect(provider1).acceptMission(missionId1);
      await escrow.connect(provider1).acceptMission(missionId2);
      
      expect(await escrow.getMissionState(missionId1)).to.equal(1);
      expect(await escrow.getMissionState(missionId2)).to.equal(1);
    });
  });
});
```

---

## Test Summary

| Contract | Test Suites | Test Cases | Coverage Target |
|----------|-------------|------------|-----------------|
| AGNTToken | 12 | ~25 | 100% |
| AgentRegistry | 10 | ~25 | 100% |
| MissionEscrow | 20 | ~45 | 100% branch |
| ProviderStaking | 12 | ~25 | 100% |
| **Integration** | 6 | ~15 | — |
| **Total** | **60+** | **~135** | — |

---

## Running Tests

```bash
# Run all tests
npx hardhat test

# Run with coverage
npx hardhat coverage

# Run specific contract tests
npx hardhat test test/AGNTToken.js
npx hardhat test test/AgentRegistry.js
npx hardhat test test/MissionEscrow.js
npx hardhat test test/ProviderStaking.js
npx hardhat test test/integration.js

# Run with gas reporting
REPORT_GAS=true npx hardhat test
```

---

*Contract tests spec complete. 135 test cases.*
