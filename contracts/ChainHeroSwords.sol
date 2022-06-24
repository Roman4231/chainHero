// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IChainHeroWeapon.sol";


/**
 * @title SampleERC721
 * @dev Create a sample ERC721 standard token
 */
contract ChainHeroSwords is IChainHeroWeapon, ERC721URIStorage, Ownable {


    struct Item {
        SwordType swordType;
        uint level;
    }

    struct SwordType {
        uint64 damagePerLevel;
        uint64 initDamage;
        uint128 price;
        string imageUri;
        string embeddableSvg;
    }


    using Strings for uint256;
    using Strings for uint128;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(string => SwordType) public swordNameToSwordType;
    string[] public availableSwords;
    mapping(uint256 => Item) public tokenIdToItem;

    constructor(string memory tokenName, string memory tokenSymbol) ERC721(tokenName, tokenSymbol) {}

    function getTokenEmbeddableSvg(uint tokenId) public view returns (string memory){
        return tokenIdToItem[tokenId].swordType.embeddableSvg;
    }

    function getImageUri(uint tokenId) public view returns (string memory){
        return string.concat(_baseURI(), tokenIdToItem[tokenId].swordType.imageUri);
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory){
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "ChainHeroSword #', tokenId.toString(), '",',
            '"description": "Chain heroes swords",',
            '"image": "', getImageUri(tokenId), '"',
            '}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    function mint(string calldata swordName) public payable {
        require(!equal(swordNameToSwordType[swordName].imageUri, ""), "SwordName is wrong!");
        require(swordNameToSwordType[swordName].price == msg.value,
            string.concat("You sent incorrect amount of ether. The price is ", swordNameToSwordType[swordName].price.toString()));

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _safeMint(msg.sender, newItemId);
        tokenIdToItem[newItemId].swordType = swordNameToSwordType[swordName];
        tokenIdToItem[newItemId].level = 0;
        _setTokenURI(newItemId, getTokenURI(newItemId));
    }

    function train(uint256 tokenId) public {
        //would we good to add signature verification at this step
        require(_exists(tokenId));
        require(ownerOf(tokenId) == msg.sender, "You must own this NFT to train it!");

        uint256 currentLevel = tokenIdToItem[tokenId].level;
        tokenIdToItem[tokenId].level = currentLevel + 1;
        _setTokenURI(tokenId, getTokenURI(tokenId));
    }

    function addNewSwordType(
        string calldata name,
        uint64 damagePerLevel,
        uint64 initDamage,
        uint128 price,
        string calldata imageUrl,
        string calldata embeddableSvg
    ) public onlyOwner {
        require(equal(swordNameToSwordType[name].imageUri,""), "sword with such name already exists");

        swordNameToSwordType[name].damagePerLevel = damagePerLevel;
        swordNameToSwordType[name].initDamage = initDamage;
        swordNameToSwordType[name].price = price;
        swordNameToSwordType[name].imageUri = imageUrl;
        swordNameToSwordType[name].embeddableSvg = embeddableSvg;
        availableSwords.push(name);
    }

    function getDamage(uint tokenId) public view returns (uint){
        return tokenIdToItem[tokenId].swordType.initDamage +
        (tokenIdToItem[tokenId].level * tokenIdToItem[tokenId].swordType.damagePerLevel);
    }


    function compare(string memory _a, string memory _b) private pure returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        //@todo unroll the loop into increments of 32 and do full 32 byte comparisons
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }
    /// @dev Compares two strings and returns true iff they are equal.
    function equal(string memory _a, string memory _b) private pure  returns (bool) {
        return compare(_a, _b) == 0;
    }

}
