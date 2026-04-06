// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract MplPlayerCardNonOptimized is ERC721URIStorage, Ownable, FunctionsClient {
    using Strings for uint256;
    using FunctionsRequest for FunctionsRequest.Request;

    uint256 private _tokenIds;
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
    uint64 public subscriptionId;
    string public sourceCode;

    struct PlayerData {
        string name;
        string lane;
        uint256 totalGames;
        uint256 avgKda;
        string fullSvg; // Model A: Menyimpan seluruh string gambar di storage 
    }

    mapping(uint256 => PlayerData) public s_playerData;
    mapping(bytes32 => uint256) public s_requestToTokenId;

    constructor(uint64 _subscriptionId) 
        ERC721("MPL Non-Optimized", "MNON") 
        Ownable(msg.sender) 
        FunctionsClient(router) 
    {
        subscriptionId = _subscriptionId;
    }

    // --- Fungsi Internal Perakitan SVG (Dijalankan On-Chain saat Update) ---
    function _buildEntireSVG(string memory _name, string memory _lane, uint256 _games, uint256 _kda) internal pure returns (string memory) {
        // Logika format KDA di dalam perakitan
        uint256 iPart = _kda / 100;
        uint256 dPart = _kda % 100;
        string memory kdaStr = string.concat(iPart.toString(), ".", dPart < 10 ? string.concat("0", dPart.toString()) : dPart.toString());

        return string.concat(
            '<svg width="320" height="400" viewBox="0 0 320 400" xmlns="http://www.w3.org/2000/svg">',
            '<rect width="100%" height="100%" fill="#ecf0f1"/>',
            '<text x="160" y="40" fill="#022f52" font-size="20" text-anchor="middle">NON-OPTIMIZED CARD</text>',
            '<text x="20" y="100" font-size="14">NAME: ', _name, '</text>',
            '<text x="20" y="130" font-size="14">LANE: ', _lane, '</text>',
            '<text x="20" y="160" font-size="14">GAMES: ', _games.toString(), '</text>',
            '<text x="20" y="190" font-size="14">KDA: ', kdaStr, '</text>',
            '</svg>'
        );
    }

    function safeMint(address to, string memory _name, string memory _lane, uint256 _games, uint256 _kda) public onlyOwner {
        uint256 tokenId = _tokenIds;
        // Pada minting awal, langsung rakit dan simpan seluruh SVG ke storage
        string memory initialSvg = _buildEntireSVG(_name, _lane, _games, _kda);
        s_playerData[tokenId] = PlayerData(_name, _lane, _games, _kda, initialSvg);
        
        _safeMint(to, tokenId);
        _tokenIds++;
    }

    function setSourceCode(string memory _sourceCode) public onlyOwner {
        sourceCode = _sourceCode;
    }

    function requestStatsUpdate(uint256 tokenId, string memory nickname) public onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        string[] memory args = new string[](1);
        args[0] = nickname;
        req.setArgs(args);
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
        s_requestToTokenId[requestId] = tokenId;
    }

    // --- Fulfill: Bagian Termahal (Model A) ---
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        require(err.length == 0, "Oracle Error");
        uint256 tokenId = s_requestToTokenId[requestId];
        
        uint256 packedData = abi.decode(response, (uint256));
        uint256 newKda = packedData & type(uint128).max; 
        uint256 newGames = packedData >> 128;            

        // UPDATE DATA
        s_playerData[tokenId].totalGames = newGames;
        s_playerData[tokenId].avgKda = newKda;

        // MODEL A: Rakit ulang seluruh SVG dan TIMPA storage lama dengan string baru yang panjang
        // Ini akan memakan Gas Fee yang sangat besar dibanding Model B [cite: 71, 142]
        s_playerData[tokenId].fullSvg = _buildEntireSVG(
            s_playerData[tokenId].name, 
            s_playerData[tokenId].lane, 
            newGames, 
            newKda
        );
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        PlayerData memory data = s_playerData[tokenId];
        string memory imageBase64 = Base64.encode(bytes(data.fullSvg)); // Tinggal ambil dari storage
        
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(string.concat('{"name": "Non-Opt #', tokenId.toString(), '", "image": "data:image/svg+xml;base64,', imageBase64, '"}')))
        );
    }
}