// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Encircled is ERC20, Ownable {
    constructor() ERC20("Encircled", "ENCD") {
        _mint(msg.sender, 200000000 * 10 ** decimals());
    }
}
