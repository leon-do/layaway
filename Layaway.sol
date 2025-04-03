// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Layaway {
    address USD = 0xfB72aAdB17a855D27A68B565ee0a84CB30A387e4;
    struct Listing {
        uint    id;         // unique id for listing
        address poster;     // address of poster
        address buyer;      // address of buyer (default 0x0)
        uint    value;      // value in ETH
        uint    amount;     // amount in USD
        uint    price;      // price ETH:USD
        uint    expiry;     // expiry block
        bool    settled;    // is listing settled (default false)
    }
    mapping (uint => Listing) public listings;

    /*
    * @dev anyone can post a listing
    * @param _price of ETH in USD
    * @param _expiry block number to settle
    */
    function post(uint _price, uint _amount, uint _expiry) public payable {
        uint id = uint(keccak256(abi.encodePacked(msg.sender, block.number)));
        listings[id].id = id;
        listings[id].poster = msg.sender;
        listings[id].value = msg.value;
        listings[id].price = _price;
        listings[id].amount = _amount;
        listings[id].expiry = _expiry;
    }

    /*
    * @dev poster can cancel their listing for ETH refund
    * @param _id of listing
    */
    function cancel(uint _id) public payable {
        require(msg.sender == listings[_id].poster, "Only Poster");
        require(!listings[_id].settled, "Settled");
        require(listings[_id].buyer == address(0), "Bought");
        listings[_id].settled = true;
        (bool success, ) = listings[_id].poster.call{value: listings[_id].value}("");
        require(success, "Transfer failed");
    }

    /*
    * @dev anyone can buy a listing by depositing 10% of amount
    * @param _id of listing
    */
    function buy(uint _id) public {
        require(!listings[_id].settled, "Settled");
        uint depositAmount = listings[_id].amount * 1_000 / 10_000;
        IERC20(USD).transferFrom(msg.sender, address(this), depositAmount);
        listings[_id].buyer = msg.sender;
    }

    /*
    * @dev buyer can settle their listing
    * @dev buyer 
    * @param _id of listing
    */
    function settle(uint _id) public payable {
        require(msg.sender == listings[_id].buyer, "Only Buyer");
        require(!listings[_id].settled, "Settled");
        require(listings[_id].expiry < block.number, "Expired");
        uint currentPrice = 1; // TODO get price on chain
        require(listings[_id].price > currentPrice, "Too Low");
        listings[_id].settled = true;
        uint remainder = listings[_id].amount * 9_000 / 10_000;
        IERC20(USD).transferFrom(msg.sender, listings[_id].poster, remainder);
        IERC20(USD).transferFrom(address(this), listings[_id].poster, listings[_id].amount);
        (bool success, ) = listings[_id].buyer.call{value: listings[_id].value}("");
        require(success, "Transfer failed");
    }

    /*
    * @dev poster can get ETH refund & USD deposit
    */
    function walk(uint _id) public payable {
        require(!listings[_id].settled, "Settled");
        require(listings[_id].expiry > block.number, "Not Expired");
        listings[_id].settled = true;
        IERC20(USD).transferFrom(address(this), listings[_id].poster, listings[_id].amount);
        (bool success, ) = listings[_id].poster.call{value: listings[_id].value}("");
        require(success, "Transfer failed");
    }
}
