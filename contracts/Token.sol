pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //

    address[] public tokenHolders;
    mapping(address => bool) private isHolder;
    mapping(address => mapping(address => uint256)) public allowanceMap;
    mapping(address => uint256) public withdrawableDividend;

    // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowanceMap[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        if (balanceOf[msg.sender] == 0 && isHolder[msg.sender]) {
            isHolder[msg.sender] = false;
            for (uint256 i = 0; i < tokenHolders.length; i++) {
                if (tokenHolders[i] == msg.sender) {
                    tokenHolders[i] = tokenHolders[tokenHolders.length - 1];
                    tokenHolders.pop();
                    break;
                }
            }
        }

        if (value > 0 && balanceOf[to] == value && !isHolder[to]) {
            tokenHolders.push(to);
            isHolder[to] = true;
        }

        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        allowanceMap[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowanceMap[from][msg.sender] >= value, "Allowance too low");

        allowanceMap[from][msg.sender] = allowanceMap[from][msg.sender].sub(
            value
        );

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        if (balanceOf[from] == 0 && isHolder[from]) {
            isHolder[from] = false;
            for (uint256 i = 0; i < tokenHolders.length; i++) {
                if (tokenHolders[i] == from) {
                    tokenHolders[i] = tokenHolders[tokenHolders.length - 1];
                    tokenHolders.pop();
                    break;
                }
            }
        }

        if (value > 0 && balanceOf[to] == value && !isHolder[to]) {
            tokenHolders.push(to);
            isHolder[to] = true;
        }

        return true;
    }

    // IMintableToken

    function mint() external payable override {
        require(msg.value > 0, "No ETH sent");

        uint256 tokens = msg.value;
        totalSupply = totalSupply.add(tokens);

        if (balanceOf[msg.sender] == 0 && !isHolder[msg.sender]) {
            tokenHolders.push(msg.sender);
            isHolder[msg.sender] = true;
        }

        balanceOf[msg.sender] = balanceOf[msg.sender].add(tokens);
    }

    function burn(address payable dest) external override {
        require(balanceOf[msg.sender] > 0, "Nothing to burn");

        uint256 amount = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);

        if (isHolder[msg.sender]) {
            isHolder[msg.sender] = false;
            for (uint256 i = 0; i < tokenHolders.length; i++) {
                if (tokenHolders[i] == msg.sender) {
                    tokenHolders[i] = tokenHolders[tokenHolders.length - 1];
                    tokenHolders.pop();
                    break;
                }
            }
        }

        dest.transfer(amount);
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return tokenHolders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        if (index == 0 || index > tokenHolders.length) {
            return address(0);
        }
        return tokenHolders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "No ETH sent");
        uint256 dividendAmount = msg.value;

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            address holder = tokenHolders[i];
            uint256 holderBalance = balanceOf[holder];

            if (holderBalance > 0 && totalSupply > 0) {
                withdrawableDividend[holder] = withdrawableDividend[holder].add(
                    dividendAmount.mul(holderBalance).div(totalSupply)
                );
            }
        }
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        return withdrawableDividend[payee];
    }

    function withdrawDividend(address payable dest) external override {
        uint256 amount = withdrawableDividend[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        withdrawableDividend[msg.sender] = 0;
        dest.transfer(amount);
    }
}
