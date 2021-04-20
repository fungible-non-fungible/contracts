// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakeRouter.sol";
import "./FNFT.sol";
import "./NFT.sol";

contract Marketplace is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    address public factory;
    address public router;
    address public wbnb;
    address public fnf;
    uint256 public symbolFee;
    uint256 public mintingFee;
    uint256 public createNftFee;

    struct userStruct {
        address fnft;
        uint256 amount;
        uint256 minLevel;
        uint256 PSFinalPrice;
    }

    mapping(address => address[]) public pairs;
    mapping(address => bool) public fnfts;
    mapping(address => mapping(uint256 => userStruct)) public nftData;
    mapping(address => mapping(address => mapping(uint256 => userStruct)))
        public userData;

    event PairCreated(address indexed pair, address indexed user);
    event LiquidityAdded(
        address indexed pair,
        address indexed user,
        uint256 bnbValue,
        uint256 tokensValue
    );
    event FactoryChanged(
        address indexed oldFactory,
        address indexed newFactory
    );
    event RouterChanged(address indexed oldRouter, address indexed newRouter);
    event WBNBChanged(address indexed oldWBNB, address indexed newWBNB);
    event TokensMinted(
        address nft,
        uint256 nftId,
        address token,
        uint256 amount,
        string indexed symbol
    );
    event NFTCreated(address fnf, uint256 nftId, string indexed _tokenURI);
    event MintingFeeChanged(
        uint256 indexed oldMintingFee,
        uint256 indexed newMintingFee
    );
    event SymbolFeeChanged(
        uint256 indexed oldSymbolFee,
        uint256 indexed newSymbolFee
    );
    event CreateNftFeeChanged(
        uint256 indexed oldCreateNftFee,
        uint256 indexed newCreateNftFee
    );

    constructor(
        address _factory,
        address _router,
        address _wbnb,
        address _nft
    ) {
        factory = _factory;
        router = _router;
        wbnb = _wbnb;
        fnf = _nft;
        symbolFee = 1000000;
        mintingFee = 5000000;
        createNftFee = 2000000;
    }

    modifier correctFNFT(address fnft) {
        require(fnfts[fnft], "Not FNFT");
        _;
    }

    function createPairAndAddLiquidity(address fnft)
        public
        payable
        correctFNFT(fnft)
    {
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

        address pair = IPancakeFactory(factory).getPair(fnft, wbnb);

        pairs[msg.sender].push(pair);

        emit PairCreated(pair, msg.sender);
        emit LiquidityAdded(pair, msg.sender, msg.value, tokenBalance);
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

        address oldFactory = factory;

        factory = _factory;

        emit FactoryChanged(oldFactory, factory);
    }

    function changeRouter(address _router) external onlyOwner {
        require(_router != address(0), "Zero address");
        require(_router != address(this), "Self address");
        require(_router != msg.sender, "Sender address");
        require(_router != wbnb, "WBNB address");
        require(_router != factory, "Factory address");

        address oldRouter = router;

        router = _router;

        emit RouterChanged(oldRouter, router);
    }

    function changeWBNB(address _wbnb) external onlyOwner {
        require(_wbnb != address(0), "Zero address");
        require(_wbnb != address(this), "Self address");
        require(_wbnb != msg.sender, "Sender address");
        require(_wbnb != router, "Router address");
        require(_wbnb != factory, "Factory address");

        address oldWBNB = wbnb;

        wbnb = _wbnb;

        emit WBNBChanged(oldWBNB, wbnb);
    }

    function mint(
        address nft,
        uint256 nftId,
        uint256 amount,
        string memory symbol,
        uint256 minLevel,
        bool isExternal
    ) public payable {
        require(minLevel > (amount / 2) * 10**8 + 1, "Level so low");
        require(minLevel <= ((amount * 90) / 100) * 10**8, "Level so high");

        uint256 res;
        string memory tokenName = "FNFT";

        if (
            keccak256(abi.encodePacked((symbol))) !=
            keccak256(abi.encodePacked((tokenName)))
        ) {
            res = msg.value.sub(mintingFee + symbolFee);
        } else {
            res = msg.value.sub(mintingFee);
        }

        if (isExternal) {
            IERC721(nft).safeTransferFrom(msg.sender, address(this), nftId);
        }

        ERC20 newToken = new FNFT("Fungible Non Fungible", symbol, amount);
        fnfts[address(newToken)] = true;

        userData[msg.sender][nft][nftId].fnft = address(newToken);
        userData[msg.sender][nft][nftId].amount = amount;
        userData[msg.sender][nft][nftId].minLevel = minLevel;

        nftData[nft][nftId].fnft = address(newToken);
        nftData[nft][nftId].amount = amount;
        nftData[nft][nftId].minLevel = minLevel;

        emit TokensMinted(nft, nftId, address(newToken), amount, symbol);

        this.createPairAndAddLiquidity{value: res}(address(newToken));
    }

    function createNFT(
        string memory _tokenURI,
        uint256 amount,
        uint256 minLevel,
        string memory symbol
    ) external payable {
        require(msg.value > createNftFee + mintingFee, "Not enough msg.value");

        _tokenIds.increment();

        uint256 currentId = _tokenIds.current();

        NFT(fnf).addItem(address(this), _tokenURI);

        emit NFTCreated(fnf, currentId, _tokenURI);

        this.mint{value: msg.value}(
            fnf,
            currentId,
            amount,
            symbol,
            minLevel,
            false
        );
    }

    function changeMintingFee(uint256 _mintingFee) external onlyOwner {
        uint256 oldMintingFee = mintingFee;

        mintingFee = _mintingFee;

        emit MintingFeeChanged(oldMintingFee, mintingFee);
    }

    function changeSymbolFee(uint256 _symbolFee) external onlyOwner {
        uint256 oldSymbolFee = symbolFee;

        symbolFee = _symbolFee;

        emit SymbolFeeChanged(oldSymbolFee, symbolFee);
    }

    function changeCreateNftFee(uint256 _createNftFee) external onlyOwner {
        uint256 oldCreateNftFee = symbolFee;

        createNftFee = _createNftFee;

        emit CreateNftFeeChanged(oldCreateNftFee, createNftFee);
    }
}
