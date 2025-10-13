//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SwapSwap} from "./SwapSwap.sol";

contract SwapSwapFactory is Ownable {
    error SwapSwapFactory__NotAdmin();
    error SwapSwapFactory__ZeroAddress();
    error SwapSwapFactory__AlreadyDeployed(address _token);

    event SwapSwapFactory__AdminUpdated(address indexed newAdmin);
    event SwapSwapFactory__Created(address indexed instance, address indexed token);

    address public admin;
    address public immutable i_zRouter;
    address public immutable i_USDC;
    address public immutable i_WETH;
    address public immutable i_DAI;

    mapping(address _token => address _instance) public instances;

    constructor(address _admin, address router, address usdc, address weth, address dai) Ownable(msg.sender) {
        if (_admin == address(0) || router == address(0)) {
            revert SwapSwapFactory__ZeroAddress();
        }
        admin = _admin;
        i_zRouter = router;
        i_USDC = usdc;
        i_WETH = weth;
        i_DAI = dai;
    }

    function updateAdmin(address _newAdmin) external onlyOwner {
        if (_newAdmin == address(0)) {
            revert SwapSwapFactory__ZeroAddress();
        }

        admin = _newAdmin;
        emit SwapSwapFactory__AdminUpdated(_newAdmin);
    }

    function deploySwapSwap(address _token) external returns (address instance) {
        if (msg.sender != admin) revert SwapSwapFactory__NotAdmin();

        if (_token == address(0)) revert SwapSwapFactory__ZeroAddress();

        address predictedAddress = predictAddress(_token);

        if (predictedAddress.code.length != 0) revert SwapSwapFactory__AlreadyDeployed(_token);

        bytes32 salt = _salt(_token);
        bytes memory bytecode = _initCode(_token);

        instance = Create2.deploy(0, salt, bytecode);

        instances[_token] = instance;

        emit SwapSwapFactory__Created(instance, _token);
    }

    function predictAddress(address _token) public view returns (address predicted) {
        bytes32 initCodeHash = keccak256(_initCode(_token));
        bytes32 salt = _salt(_token);
        predicted = Create2.computeAddress(salt, initCodeHash);
    }

    function _initCode(address token) internal view returns (bytes memory) {
        // creation bytecode + encoded constructor args
        return abi.encode(type(SwapSwap).creationCode, abi.encode(token, i_zRouter, i_USDC, i_WETH, i_DAI, admin));
    }

    function _salt(address token) internal pure returns (bytes32) {
        // single 32-byte salt derived from the ordered pair
        return keccak256(abi.encodePacked(token, "swapswap.eth"));
    }
}
