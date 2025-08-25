// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract DeviceNFTTemplate is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    address public operator;

    function initialize(string memory _name, string memory _symbol, address _owner, address _operator) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_owner);
        operator = _operator;
    }

    function setOperator(address _newOperator) public onlyOwner {
        operator = _newOperator;
    }

    function mint(address to, uint256 tokenId) public {
        require(msg.sender == operator || msg.sender == owner(), "Only owner or operator can mint");
        _safeMint(to, tokenId);
    }

    function batchMint(address[] calldata to, uint256[] calldata tokenIds) public {
        require(msg.sender == operator || msg.sender == owner(), "Only owner or operator can mint");
        require(to.length == tokenIds.length, "Array lengths must match");
        for (uint256 i = 0; i < to.length; i++) {
            _safeMint(to[i], tokenIds[i]);
        }
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == owner(), "Only owner can burn");
        _burn(tokenId);
    }
}