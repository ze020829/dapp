// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "hardhat/console.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

//构建一个NFT交易市场的简单逻辑操作
contract NFTMarket is IERC721Receiver {
    IERC20 public erc20;
    IERC721 public erc721;
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;
    //实现订单的价格 售卖者 订单_tokenId,可以定义一个时间戳
    struct Order {
        // seller
        address seller;
        // NFT price
        uint256 price;
        //NFT tokenID,to modify the NFT
        uint256 _tokenId;
        //OnsaleTime
        uint256 timeStamp;
        //when the NFT is saled , the state become true.
        bool saleState;
    }
    //根据token_id的参数可以查看到相关的NFT订单信息，利用映射操作来进行理解
    mapping(uint256 => Order) public orderOfId;
    //订单数组传入相关的总订单操作
    Order[] public orders;
    //订单的ID转换到相关的订单索引？
    mapping(uint256 => uint256) public idToIndexOrder;
    //交易
    event Deal(
        address seller,
        address buyer,
        uint256 _tokenId,
        uint256 price,
        bool saleState
    );
    //NFT上架
    event NFTLoadToTheMarket(
        address seller,
        uint256 _tokenId,
        uint256 price,
        bool saleState
    );
    //更换NFT价格
    event RedefineTheNFTPrice(
        address ownerSeller,
        uint256 _tokenId,
        uint256 priviousPrice,
        uint256 nowPrice
    );
    //取消NFT订单
    event WithdrawTheNFTOrder(
        address ownerSeller,
        uint256 _tokenId,
        bool saleState
    );

    //构建相关操作进行参数变量的初始化
    constructor(address _erc20, address _erc721) {
        require(_erc20 != address(0), "address is 0 not fixed the law");
        require(_erc721 != address(0), "address is 0 not fixed the law");
        //传入相关合约的范式地址，进行初始化操作
        //wapper to show the interfaces function
        erc20 = IERC20(_erc20);
        erc721 = IERC721(_erc721);
    }

    //购买结束
    function purchaseTheNft(uint256 _tokenId) external {
        //根据当前的TOKENID购买相关的NFT操作
        address theNftSeller = orderOfId[_tokenId].seller;
        address theNftPuchaser = msg.sender;
        uint256 theNftPrice = orderOfId[_tokenId].price;
        //检验是否能够购买操作
        require(
            erc20.transferFrom(theNftPuchaser, theNftSeller, theNftPrice),
            "purchased not sucesse"
        );
        //安全调用相关的NFT代币置换协议
        erc721.safeTransferFrom(address(this), theNftPuchaser, _tokenId);
        removeOrders(_tokenId);
        emit Deal(theNftSeller, theNftPuchaser, _tokenId, theNftPrice, false);
    }

    //实现更改NFT价格操作
    function changeTheNftPrice(uint256 _tokenId, uint256 newPrice) external {
        require(
            newPrice != 0,
            "_tokenId is 0 or price is 0 ,not fixed the law"
        );
        address seller = orders[idToIndexOrder[_tokenId]].seller;
        uint256 theNftPrice = orderOfId[_tokenId].price;
        require(
            seller == msg.sender,
            "you are not the owner,please check the tokenId"
        );
        orderOfId[_tokenId].price = newPrice;
        //注意此处的链上数据的更改操作
        Order storage order = orders[idToIndexOrder[_tokenId]];
        order.price = newPrice;
        emit RedefineTheNFTPrice(msg.sender, _tokenId, theNftPrice, newPrice);
    }

    //实现撤单操作
    function withDrawTheNft(uint256 _tokenId) external {
        address theOwner = orderOfId[_tokenId].seller;
        require(msg.sender == theOwner, "you can not withDrawTheNft");
        Order storage order = orders[idToIndexOrder[_tokenId]];
        order.saleState = false;
        //将当前的NFT传递给自己
        removeOrders(_tokenId);
        erc721.safeTransferFrom(address(this), theOwner, _tokenId);
        emit WithdrawTheNFTOrder(theOwner, _tokenId, false);
    }

    function onERC721Received(
        address opreator,
        address from,
        uint256 _tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        uint256 price = toUint256(data, 0);
        require(price > 0, "price must be greater than 0");
        orders.push(Order(from, price, _tokenId, block.timestamp, true));
        orderOfId[_tokenId] = Order(
            from,
            price,
            _tokenId,
            block.timestamp,
            true
        );
        idToIndexOrder[_tokenId] = orders.length - 1;
        emit NFTLoadToTheMarket(from, _tokenId, price, true);
        return MAGIC_ON_ERC721_RECEIVED;
    }

    function toUint256(bytes memory _bytes, uint256 _start)
        public
        pure
        returns (uint256)
    {
        require(_bytes.length >= (_start + 32), "Market:Uint256 outOfBounds");
        require(_start + 32 >= _start, "Market:Uint256 overflow");
        uint256 tempUint;
        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }
        return tempUint;
    }

    //实现相关下架功能操作
    function removeOrders(uint256 _tokenId) internal {
        uint256 index = idToIndexOrder[_tokenId];
        uint256 lastIndex = orders.length - 1;
        if (index != lastIndex) {
            Order storage order = orders[lastIndex];
            orders[index] = order;
            idToIndexOrder[order._tokenId] = index;
        }
        orders.pop();
        delete orderOfId[_tokenId];
        delete idToIndexOrder[_tokenId];
    }

    function getTheOrderLength() external view returns (uint256) {
        return orders.length;
    }

    function getAllNfts() external view returns (Order[] memory) {
        return orders;
    }
}
