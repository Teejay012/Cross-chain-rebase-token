// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChain is Test {
    uint256 sepoliaEthFork;
    uint256 arbitrumSepoliaFork;

    RebaseToken sepoliaToken;
    RebaseToken arbitrumSepoliaToken;

    RebaseTokenPool sepoliaTokenPool;
    RebaseTokenPool arbitrumSepoliaTokenPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbitrumSepoliaNetworkDetails;

    Vault vault;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");

    uint256 constant SEND_VALUE = 1e10;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    function setUp() public {
        sepoliaEthFork = vm.createSelectFork("sepolia-eth");
        arbitrumSepoliaFork = vm.createFork("arbitrum-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.startPrank(OWNER);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.setMintAndBurnRole(address(vault));
        sepoliaToken.setMintAndBurnRole(address(sepoliaTokenPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaTokenPool)
        );
        vm.stopPrank();

        vm.selectFork(arbitrumSepoliaFork);
        vm.startPrank(OWNER);
        arbitrumSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbitrumSepoliaToken = new RebaseToken();
        arbitrumSepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(arbitrumSepoliaToken)),
            new address[](0),
            arbitrumSepoliaNetworkDetails.rmnProxyAddress,
            arbitrumSepoliaNetworkDetails.routerAddress
        );
        arbitrumSepoliaToken.setMintAndBurnRole(address(arbitrumSepoliaTokenPool));
        RegistryModuleOwnerCustom(arbitrumSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbitrumSepoliaToken)
        );
        TokenAdminRegistry(arbitrumSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(arbitrumSepoliaToken)
        );
        TokenAdminRegistry(arbitrumSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbitrumSepoliaToken), address(arbitrumSepoliaTokenPool)
        );
        vm.stopPrank();

        configureTokenPool(
            sepoliaEthFork,
            address(sepoliaTokenPool),
            arbitrumSepoliaNetworkDetails.chainSelector,
            address(arbitrumSepoliaTokenPool),
            address(arbitrumSepoliaToken)
        );
        configureTokenPool(
            arbitrumSepoliaFork,
            address(arbitrumSepoliaTokenPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaTokenPool),
            address(sepoliaToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        vm.prank(OWNER);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);

        //  struct ChainUpdate {
        //     uint64 remoteChainSelector; // ──╮ Remote chain selector
        //     bool allowed; // ────────────────╯ Whether the chain should be enabled
        //     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        // }

        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddresses[0],
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDeatails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);
        vm.prank(USER);

        // struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        // }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(USER),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDeatails.linkAddress,
            extraArgs: ""
        });

        // Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 100000}))

        uint256 fee =
            IRouterClient(localNetworkDeatails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(USER, fee);
        vm.prank(USER);
        IERC20(localNetworkDeatails.linkAddress).approve(localNetworkDeatails.routerAddress, fee);
        vm.prank(USER);
        IERC20(address(localToken)).approve(localNetworkDeatails.routerAddress, amountToBridge);
        uint256 localTokenBalanceBefore = localToken.balanceOf(USER);
        vm.prank(USER);
        IRouterClient(localNetworkDeatails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localTokenBalanceAfter = localToken.balanceOf(USER);
        assertEq(localTokenBalanceAfter, localTokenBalanceBefore - amountToBridge, "Local balance not updated");
        uint256 localUserInterestRate = IRebaseToken(address(localToken)).getUserInterestRate(USER);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);

        uint256 remoteBalanceBefore = remoteToken.balanceOf(USER);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(USER);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge, "Remote balance not updated");
        uint256 remoteUserInterestRate = IRebaseToken(address(remoteToken)).getUserInterestRate(USER);
        assertEq(remoteUserInterestRate, localUserInterestRate, "Remote interest rate not updated");
    }

    function testBridgeTokens() public {
        vm.selectFork(sepoliaEthFork);
        vm.deal(USER, SEND_VALUE);
        vm.startPrank(USER);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(USER), SEND_VALUE, "Deposit failed");
        vm.stopPrank();

        bridgeTokens(
            SEND_VALUE,
            sepoliaEthFork,
            arbitrumSepoliaFork,
            sepoliaNetworkDetails,
            arbitrumSepoliaNetworkDetails,
            sepoliaToken,
            arbitrumSepoliaToken
        );

        vm.selectFork(arbitrumSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);

        assertGt(arbitrumSepoliaToken.balanceOf(USER), SEND_VALUE, "Remote balance not updated");

        bridgeTokens(
            SEND_VALUE,
            arbitrumSepoliaFork,
            sepoliaEthFork,
            arbitrumSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbitrumSepoliaToken,
            sepoliaToken
        );
    }
}
