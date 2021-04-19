// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FNFT is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 amount
    ) ERC20(name, symbol) {
        _mint(msg.sender, amount);
    }

    function decimals() public view override returns (uint8) {
        return 8;
    }
}
