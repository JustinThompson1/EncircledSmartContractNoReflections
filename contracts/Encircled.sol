// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract Encircled is Context, IERC20, IERC20Metadata, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    uint256 private _totalSupply = 0;
    uint256 private constant _initialSupply = 200_000_000;

    string private constant _name = "Encircled";
    string private constant _symbol = "ENCD";
    uint8 private constant _decimals = 18;

    uint256 public constant _transactionFee = 5;
    address public constant _feeWallet =
        0xe325854cfCC89546d9c9bfCFa32967864287bD0C;

    /**
     * @dev initalizing the contract
     * @notice excluding owner(deployer) and address from the fees and assigning the total supply to the deployer
     */
    constructor() {
        _mint(_msgSender(), _initialSupply * 10 ** uint256(_decimals));
        _isExcludedFromFee[_msgSender()] = true;
    }

    /**
     * @dev transfer of tokens from own wallet (ERC20 token standard)
     * @param recipient receiving address
     * @param amount amount of tokens to send
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev approve another address to spend tokens (ERC20 token standard)
     * @param spender address that is granted the ability to spend tokens
     * @param amount amount of tokens spender is allowed to spend
     */
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev transfer of approved tokens (ERC20 token standard)
     * @param sender sending address
     * @param recipient receiving address
     * @param amount amount of tokens to send
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev increases token amount address is allowed to spend (ERC20 token standard)
     * @param spender address that is granted the ability to spend tokens
     * @param addedValue allowed amount added of tokens spender is allowed to use
     */
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    /**
     * @dev decreases token amount address is allowed to spend (ERC20 token standard)
     * @param spender address that is granted the ability to spend tokens
     * @param subtractedValue allowed amount subtracted of tokens spender is allowed to use
     */
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev including address in fee (has to pay the fee when sending tokens (redistribution, development))
     * @notice all addresses are automatically included only to include an adress after excluding it
     * @param account address that is included
     */
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    /**
     * @dev excluded address from fee (won't pay a fee when sending tokens (redistribution, development))
     * @param account address that is excluded
     */
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    //returning informations to caller:
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    //execute transfer function
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        uint256 transactionFee = calculateFee(amount);
        uint256 transferAmount = amount;
        if (!(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient])) {
            transferAmount = transferAmount - transactionFee;
            _balances[_feeWallet] = _balances[_feeWallet] + transactionFee;
            _totalSupply = _totalSupply - transactionFee;
        }
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += transferAmount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    //function to calculate the fee
    function calculateFee(uint256 _amount) private pure returns (uint256) {
        return (_amount * _transactionFee) / 100;
    }

    //function to mint tokens (only be called in the constructor)
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    //execute approve function
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}
