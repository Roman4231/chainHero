// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IChainHeroItem.sol";
import "./IChainHeroWeapon.sol";


contract ChainHero is ERC721URIStorage, Ownable {

    enum ItemTypes{
        WEAPON,
        ARMOR,
        HELMET
    }

    struct Hero {
        string name;
        uint level;
        mapping(ItemTypes => Item) items;
    }

    struct Item {
        address itemAddress;
        uint itemTokenId;
    }

    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint private constant INIT_DAMAGE = 1;
    uint private constant DAMAGE_PER_LEVEL = 2;

    mapping(bytes32 => bool) public approvedItemsProviders;
    mapping(uint256 => Hero) public tokenIdToHero;

    constructor(string memory tokenName, string memory tokenSymbol) ERC721(tokenName, tokenSymbol) {}

    function generateCharacterImage(uint256 tokenId) public view returns (string memory){
        bytes memory svg = abi.encodePacked(
            '<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">',
            '<ellipse stroke="#000" ry="48" rx="46" cy="120" cx="500" fill="#fff"/>',
            '<ellipse stroke="#000" ry="92" rx="63.5" cy="255" cx="500" fill="#fff"/>',
            '<ellipse stroke="#000" ry="72.42364" rx="21.10632" cy="420" cx="445" fill="#fff" transform="rotate(20.0349 445.612 422.444)"/>',
            '<ellipse stroke="#000" ry="72.42364" rx="21.10632" cy="420" cx="555" fill="#fff" transform="rotate(-16.4218 555.612 420.444)"/>',
            '<ellipse stroke="#000" ry="72.42364" rx="21.10632" cy="250" cx="388" fill="#fff" transform="rotate(-133.144 385.612 244.444)"/>',
            '<ellipse stroke="#000" ry="72.42364" rx="21.10632" cy="250" cx="607" fill="#fff" transform="rotate(-39.0953 607.612 250.444)"/>',
            '<text  font-size="24" y="47.5" x="450" stroke-width="0" stroke="#000">',
            tokenIdToHero[tokenId].name,
            ' Lv: ',
            tokenIdToHero[tokenId].level.toString(),
            '</text>',
            _getWeaponImage(tokenId),
            '</svg>'
        );
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(svg)
            )
        );
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory){
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "ChainHero #', tokenId.toString(), '",',
            '"description": "Chain heroes",',
            '"image": "', generateCharacterImage(tokenId), '",',
            '"attributes": [',
            '{"trait_type": "Damage","value": ', _getDamage(tokenId).toString(), ', "max_value": 100},',
//            '{"trait_type": "Agility","value": ', _getAgility(tokenId), ', "max_value": 100},',
            '{"trait_type": "Level", "value": ', _getLevel(tokenId).toString(), ', "display_type": "number"}',
            ']}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    function mint(string calldata _heroName) public {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        tokenIdToHero[newItemId].name = _heroName;
        tokenIdToHero[newItemId].level = 0;
        _setTokenURI(newItemId, getTokenURI(newItemId));
    }

    function train(uint256 tokenId) public {
        //would we good to add signature verification at this step
        require(_exists(tokenId));
        require(ownerOf(tokenId) == msg.sender, "You must own this NFT to train it!");

        uint256 currentLevel = tokenIdToHero[tokenId].level;
        tokenIdToHero[tokenId].level = currentLevel + 1;
        _setTokenURI(tokenId, getTokenURI(tokenId));
    }

    function putOnItem(uint heroId, ItemTypes itemType, address itemCollection, uint itemTokenId) public {
        //would we good to add signature verification at this step
        require(_exists(heroId));
        require(ownerOf(heroId) == msg.sender, "You must own this NFT to put an item on it!");
        require(IERC721(itemCollection).ownerOf(itemTokenId) == msg.sender, "You should own an item to use it");
        require(_isItemProviderApproved(itemCollection, itemType), "Item collection should be approved.");

        tokenIdToHero[heroId].items[itemType] = Item(itemCollection, itemTokenId);
        _setTokenURI(heroId, getTokenURI(heroId));
    }

    function approveItemsProvider(address itemCollection, ItemTypes itemType, bool approved) public onlyOwner {
        approvedItemsProviders[_getItemProviderKey(itemCollection, itemType)] = approved;
    }

    function _isItemProviderApproved(address itemCollection, ItemTypes itemType) private view returns (bool){
        return approvedItemsProviders[_getItemProviderKey(itemCollection, itemType)];
    }

    function _getItemProviderKey(address itemCollection, ItemTypes itemType) public pure returns (bytes32){
        return keccak256(abi.encodePacked(itemCollection, itemType));
    }

    function withdraw()public payable onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }

    function _getWeaponImage(uint tokenId) private view returns (string memory){
        Item memory item = tokenIdToHero[tokenId].items[ItemTypes.WEAPON];
        if (item.itemAddress == address(0)) {
            return '';
        } else {
            return IChainHeroItem(item.itemAddress).getTokenEmbeddableSvg(item.itemTokenId);
        }
    }

    function _getLevel(uint tokenId) private view returns (uint){
        return tokenIdToHero[tokenId].level;
    }

    function _getDamage(uint tokenId) private view returns (uint){
        Item memory item = tokenIdToHero[tokenId].items[ItemTypes.WEAPON];
        uint weaponDamage = _getWeaponDamage(item);
        uint heroDamage = INIT_DAMAGE + (tokenIdToHero[tokenId].level * DAMAGE_PER_LEVEL);
        //each level increases user damage;
        return weaponDamage + heroDamage;
    }

    function _getWeaponDamage(Item memory item) private view returns (uint){
        if (item.itemAddress == address(0)) {
            return 0;
        } else {
            return IChainHeroWeapon(item.itemAddress).getDamage(item.itemTokenId);
        }
    }
}
