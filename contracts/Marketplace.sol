// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakeRouter.sol";
// import "./interfaces/IERC20.sol";
import "./FNFT.sol";

contract Marketplace is Ownable {
    using SafeMath for uint256;

    address public factory;
    address public router;
    address public wbnb;
    uint256 public symbolFee;
    uint256 public mintingFee;

    mapping(address => address[]) public pairs;
    mapping(address => bool) public fnfts;



    constructor(
        address _factory,
        address _router,
        address _wbnb
    ) {
        factory = _factory;
        router = _router;
        wbnb = _wbnb;
        symbolFee = 1000000;
        mintingFee = 5000000;
    }

    modifier correctFNFT(address fnft) {
        require(fnfts[fnft], "Not FNFT");
        _;
    }

    function createPairAndAddLiquidity(address fnft)
        external
        payable
        correctFNFT(fnft)
    {
        IPancakeFactory(factory).createPair(fnft, wbnb);

        pairs[msg.sender].push(IPancakeFactory(factory).getPair(fnft, wbnb));

        uint256 tokenBalance = IERC20(fnft).balanceOf(address(this));

        IERC20(fnft).approve(router, tokenBalance);
        IPancakeRouter(router).addLiquidityETH{value: msg.value}(
            fnft,
            tokenBalance,
            tokenBalance,
            msg.value,
            address(this),
            block.timestamp + 10 minutes
        );
    }

    function buyFNFT(
        address fnft,
        bool exactBNB,
        uint256 amountOutMin,
        uint256 amountOut
    ) external payable correctFNFT(fnft) {
        address[] memory path = new address[](2);

        path[0] = wbnb;
        path[1] = fnft;

        if (exactBNB && amountOut == 0) {
            IPancakeRouter(router).swapExactETHForTokens{value: msg.value}(
                amountOutMin, // min amount of output tokens
                path,
                msg.sender,
                block.timestamp + 10 minutes
            );
        } else if (!exactBNB && amountOutMin == 0) {
            IPancakeRouter(router).swapETHForExactTokens{value: msg.value}(
                amountOut, // amount of output tokens
                path,
                msg.sender,
                block.timestamp + 10 minutes
            );
        }
    }

    function sellFNFT(
        address fnft,
        bool exactFNFT,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 amountOut,
        uint256 amountInMax
    ) external correctFNFT(fnft) {
        address[] memory path = new address[](2);

        path[0] = fnft;
        path[1] = wbnb;

        if (exactFNFT && amountOut == 0 && amountInMax == 0) {
            IPancakeRouter(router).swapExactTokensForETH(
                amountIn, // amount of tokens to sell
                amountOutMin, // min amount of output BNB
                path,
                msg.sender,
                block.timestamp + 10 minutes
            );
        } else if (!exactFNFT && amountIn == 0 && amountOutMin == 0) {
            IPancakeRouter(router).swapTokensForExactETH(
                amountOut, // amount of output BNB
                amountInMax, // max amount of tokens that can be sold
                path,
                msg.sender,
                block.timestamp + 10 minutes
            );
        }
    }

    function changeFactory(address _factory) external onlyOwner {
        require(_factory != address(0), "Zero address");
        require(_factory != address(this), "Self address");
        require(_factory != msg.sender, "Sender address");
        require(_factory != wbnb, "WBNB address");
        require(_factory != router, "Router address");

        factory = _factory;
    }

    function changeRouter(address _router) external onlyOwner {
        require(_router != address(0), "Zero address");
        require(_router != address(this), "Self address");
        require(_router != msg.sender, "Sender address");
        require(_router != wbnb, "WBNB address");
        require(_router != factory, "Factory address");

        router = _router;
    }

    function changeWBNB(address _wbnb) external onlyOwner {
        require(_wbnb != address(0), "Zero address");
        require(_wbnb != address(this), "Self address");
        require(_wbnb != msg.sender, "Sender address");
        require(_wbnb != router, "Router address");
        require(_wbnb != factory, "Factory address");

        wbnb = _wbnb;
    }

    function mint(address nft, uint256 nftId, uint256 amount, uint256 minLevel, string memory symbol) payable external {
        require(minLevel > amount / 2 * 10**18 + 1, 'Level so low');
        require(minLevel <= amount * 90 / 100, 'Level so high');
        uint256 res;
        string memory tokenName = 'FNFT';

        if (keccak256(abi.encodePacked((symbol))) != keccak256(abi.encodePacked((tokenName)))) {
            res = msg.value.sub(mintingFee + symbolFee);
        }
        else {
            res = msg.value.sub(mintingFee);
        }
        IERC721(nft).safeTransferFrom(msg.sender, address(this), nftId);

        ERC20 newToken = new FNFT('FNFT', symbol, amount);
        fnfts[address(newToken)] = true;
        this.createPairAndAddLiquidity{value: res}(address(newToken));
    }
}
