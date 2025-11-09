//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ISwapSwap} from "./interfaces/ISwapSwap.sol";

contract SwapSwapFactory is Ownable {
    error SwapSwapFactory__NotAdmin();
    error SwapSwapFactory__ZeroAddress();
    error SwapSwapFactory__AlreadyDeployed(address _token);

    event SwapSwapFactory__AdminUpdated(address indexed newAdmin);
    event SwapSwapFactory__Created(address indexed instance, address indexed token);
    event SwapSwapFactory__SaltUpdate(string indexed newSalt);
    event SwapSwapFactory__ImplementationUpdated(address indexed newImplementation);

    address public s_admin;
    address public s_implementation;

    address public immutable i_zRouter;
    address public immutable i_USDC;
    address public immutable i_WETH;
    address public immutable i_DAI;
    string s_salt;

    mapping(address _token => address _instance) public instances;

    constructor(
        address _implementation,
        address _admin,
        address router,
        address usdc,
        address weth,
        address dai,
        string memory salt
    ) Ownable(msg.sender) {
        if (_admin == address(0) || router == address(0) || _implementation == address(0)) {
            revert SwapSwapFactory__ZeroAddress();
        }
        s_implementation = _implementation;
        s_admin = _admin;
        s_salt = salt;

        i_zRouter = router;
        i_USDC = usdc;
        i_WETH = weth;
        i_DAI = dai;
    }

    function updateAdmin(address _newAdmin) external onlyOwner {
        if (_newAdmin == address(0)) {
            revert SwapSwapFactory__ZeroAddress();
        }

        s_admin = _newAdmin;
        emit SwapSwapFactory__AdminUpdated(_newAdmin);
    }

    function updateSalt(string memory _newSalt) external onlyOwner {
        s_salt = _newSalt;
        emit SwapSwapFactory__SaltUpdate(_newSalt);
    }

    function updateImplementation(address _newImplementation) external onlyOwner {
        s_implementation = _newImplementation;
        emit SwapSwapFactory__ImplementationUpdated(_newImplementation);
    }

    function deploySwapSwap(address _token) external returns (address instance) {
        if (msg.sender != s_admin) revert SwapSwapFactory__NotAdmin();

        if (_token == address(0)) revert SwapSwapFactory__ZeroAddress();

        address predictedAddress = predictAddress(_token);

        if (predictedAddress.code.length != 0) {
            revert SwapSwapFactory__AlreadyDeployed(_token);
        }

        bytes32 salt = _salt(_token);

        instance = Clones.cloneDeterministic(s_implementation, salt);
        instances[_token] = instance;

        ISwapSwap.InitParams memory initParams = ISwapSwap.InitParams(i_USDC, i_DAI, i_WETH, s_admin, _token, i_zRouter);

        ISwapSwap(instance).initialize(abi.encode(initParams));

        emit SwapSwapFactory__Created(instance, _token);
    }

    function predictAddress(address _token) public view returns (address predicted) {
        bytes32 salt = _salt(_token);
        predicted = Clones.predictDeterministicAddress(s_implementation, salt, address(this));
    }

    function _salt(address token) internal view returns (bytes32) {
        // single 32-byte salt derived from the ordered pair
        return keccak256(abi.encodePacked(token, s_salt));
    }
}
