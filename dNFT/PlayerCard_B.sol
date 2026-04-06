// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract MplPlayerCard is ERC721URIStorage, Ownable, FunctionsClient {
    using Strings for uint256;
    using FunctionsRequest for FunctionsRequest.Request;

    uint256 private _tokenIds;
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
    uint64 public subscriptionId;
    string public sourceCode;

    // Automation Variables
    uint256 public lastTimeStamp;
    uint256 public interval = 24 hours;
    uint256 public targetTokenIdToUpdate;

    struct PlayerData {
        string name;
        string lane;
        uint64 games;
        uint64 kills;
        uint64 deaths;
        uint64 assists;
    }

    mapping(uint256 => PlayerData) public s_playerData;
    mapping(bytes32 => uint256) public s_requestToTokenId;

    constructor(uint64 _subscriptionId) 
        ERC721("MPL Model B V2", "MPLB2") 
        Ownable(msg.sender) 
        FunctionsClient(router) 
    {
        subscriptionId = _subscriptionId;
        lastTimeStamp = block.timestamp;
    }

    // Fungsi untuk mengubah interval (detik) dan target token yang di-update otomatis
    function setAutomationSettings(uint256 _intervalSeconds, uint256 _targetTokenId) public onlyOwner {
        interval = _intervalSeconds;
        targetTokenIdToUpdate = _targetTokenId;
    }

    // --- Core Logic: Layered SVG Assembly ---
    // Membagi SVG menjadi bagian-bagian untuk menyisipkan data dinamis
    function generateSVG(uint256 tokenId) public view returns (string memory) {
        PlayerData memory data = s_playerData[tokenId];
        
        // Kalkulasi KDA On-the-fly (Hemat Gas Storage)
        uint64 deaths = data.deaths == 0 ? 1 : data.deaths;
        uint256 kdaValue = (uint256(data.kills) + uint256(data.assists)) * 100 / deaths;
        string memory kdaStr = string.concat((kdaValue / 100).toString(), ".", (kdaValue % 100).toString());

        return string.concat(
            '<svg width="320" height="400" viewBox="0 0 320 400" xmlns="http://www.w3.org/2000/svg">',
            '<g shape-rendering="crispEdges"><rect x="0" y="0" width="320" height="400" fill="#151515"/><rect x="8" y="8" width="304" height="384" fill="#022f52"/><text x="160" y="40" fill="#ecf0f1" font-size="20" text-anchor="middle" font-weight="bold">PLAYER CARD</text><line x1="20" y1="55" x2="300" y2="55" stroke="#ecf0f1" stroke-width="4"/></g>',
            _getPixelArtSVG(),
            _getStatsSVG(data, kdaStr),
            '</svg>'
        );
    }

    function _getPixelArtSVG() internal pure returns (string memory) {
        return '<svg x="10" y="30" width="140" height="380" viewBox="0 0 32 32" shape-rendering="crispEdges"><g transform="translate(32, 0) scale(-1, 1)"><path fill="#000000" d="M11 2h10v1H11z M9 3h2v1H9z M21 3h2v1H21z M8 4h1v1H8z M23 4h1v1H23z M8 5h1v1H8z M24 5h1v1H24z M8 6h1v1H8z M24 6h1v1H24z M8 7h1v1H8z M24 7h1v1H24z M8 8h1v1H8z M24 8h1v1H24z M9 9h1v1H9z M24 9h1v1H24z M9 10h1v1H9z M23 10h1v1H23z M9 11h1v1H9z M12 11h2v1H12z M18 11h2v1H18z M23 11h1v1H23z M9 12h1v1H9z M23 12h1v1H23z M10 13h1v1H10z M22 13h1v1H22z M10 14h1v1H10z M22 14h1v1H22z M10 15h1v1H10z M22 15h1v1H22z M11 16h1v1H11z M21 16h1v1H21z M11 17h1v1H11z M21 17h1v1H21z M12 18h1v1H12z M20 18h1v1H20z M12 19h1v1H12z M20 19h1v1H20z M11 20h1v1H11z M21 20h1v1H21z M9 21h2v1H9z M22 21h2v1H22z M7 22h2v1H7z M24 22h2v1H24z M6 23h1v1H6z M26 23h1v1H26z M5 24h1v1H5z M27 24h1v1H27z M4 25h1v1H4z M28 25h1v1H28z M3 26h1v1H3z M29 26h1v1H29z M3 27h1v1H3z M29 27h1v1H29z M3 28h1v1H3z M29 28h1v1H29z M3 29h1v1H3z M29 29h1v1H29z M3 30h1v1H3z M29 30h1v1H29z M3 31h27v1H3z" /><path fill="#000000" d="M11 3h10v1H11z M9 4h14v1H9z M9 5h15v1H9z M9 6h15v1H9z M9 7h15v1H9z M9 8h3v1H9z M20 8h4v1H20z M10 9h2v1H10z M22 9h2v1H22z M10 10h1v1H10z M22 10h1v1H22z" /><path fill="#e4b590" d="M12 8h8v1H12z M12 9h10v1H12z M11 10h11v1H11z M10 11h2v1H10z M14 11h4v1H14z M20 11h3v1H20z M10 12h13v1H10z M11 13h4v1H11z M17 13h5v1H17z M11 14h11v1H11z M11 15h3v1H11z M18 15h4v1H18z M12 16h9v1H12z M12 17h9v1H12z M13 18h7v1H13z" /><path fill="#c59473" d="M15 13h2v1H15z M13 19h7v1H13z M14 20h5v1H14z" /><path fill="#bd6a4f" d="M14 15h4v1H14z" /><path fill="#ffffff" d="M12 20h2v1H12z M19 20h2v1H19z M11 21h3v1H11z M19 21h3v1H19z M9 22h4v1H9z M20 22h4v1H20z M7 23h5v1H7z M21 23h5v1H21z M6 24h5v1H6z M22 24h5v1H22z M5 25h5v1H5z M13 25h2v1H13z M16 25h2v1H16z M19 25h2v1H19z M23 25h5v1H23z M4 26h5v1H4z M24 26h5v1H24z M4 27h4v1H4z M25 27h4v1H25z M4 28h4v1H4z M25 28h4v1H25z M4 29h4v1H4z M25 29h4v1H25z M6 30h2v1H6z M25 30h2v1H25z" /><path fill="#ef8115" d="M14 21h5v1H14z M13 22h7v1H13z M12 23h9v1H12z M11 24h11v1H11z M10 25h3v1H10z M15 25h1v1H15z M18 25h1v1H18z M21 25h2v1H21z M9 26h15v1H9z M8 27h17v1H8z M8 28h17v1H8z M8 29h17v1H8z M4 30h2v1H4z M8 30h17v1H8z M27 30h2v1H27z" /></g></svg>';
    }

    function _getStatsSVG(PlayerData memory d, string memory kda) internal pure returns (string memory) {
        return string.concat(
            '<g transform="translate(180, 100)" shape-rendering="crispEdges">',
            '<text x="-30" y="20" fill="#3498db" font-size="14">PLAYER NAME:</text><text x="-30" y="50" fill="#ecf0f1" font-size="24" font-weight="bold">', d.name, '</text><line x1="-25" y1="75" x2="120" y2="75" stroke="#555" stroke-width="4" stroke-dasharray="8,6"/>',
            '<text x="-30" y="100" fill="#ecf0f1" font-size="14">LANE:</text><text x="120" y="100" fill="#ecf0f1" font-size="14" text-anchor="end">', d.lane, '</text>',
            '<text x="-30" y="125" fill="#ecf0f1" font-size="14">GAME:</text><text x="120" y="125" fill="#ecf0f1" font-size="14" text-anchor="end">', uint256(d.games).toString(), '</text>',
            '<text x="-30" y="150" fill="#ecf0f1" font-size="14">KILLS:</text><text x="120" y="150" fill="#ecf0f1" font-size="14" text-anchor="end">', uint256(d.kills).toString(), '</text>',
            '<text x="-30" y="175" fill="#ecf0f1" font-size="14">DEATHS:</text><text x="120" y="175" fill="#ecf0f1" font-size="14" text-anchor="end">', uint256(d.deaths).toString(), '</text>',
            '<text x="-30" y="200" fill="#ecf0f1" font-size="14">ASSISTS:</text><text x="120" y="200" fill="#ecf0f1" font-size="14" text-anchor="end">', uint256(d.assists).toString(), '</text>',
            '<text x="-30" y="225" fill="#ecf0f1" font-size="14">KDA:</text><text x="120" y="225" fill="#ecf0f1" font-size="14" text-anchor="end">', kda, '</text>',
            '<line x1="-30" y1="240" x2="120" y2="240" stroke="#555" stroke-width="4" stroke-dasharray="8,6"/></g>'
        );
    }

    // --- Minting & Functions ---
    function safeMint(address to, string memory _name, string memory _lane) public onlyOwner {
        uint256 tokenId = _tokenIds;
        s_playerData[tokenId] = PlayerData(_name, _lane, 0, 0, 0, 0);
        _safeMint(to, tokenId);
        _tokenIds++;
    }

    function setSourceCode(string memory _sourceCode) public onlyOwner {
        sourceCode = _sourceCode;
    }

    function _requestStatsInternal(uint256 tokenId, string memory nickname) internal returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        string[] memory args = new string[](1);
        args[0] = nickname;
        req.setArgs(args);
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
        s_requestToTokenId[requestId] = tokenId;
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        require(err.length == 0, "Oracle Error");
        uint256 tokenId = s_requestToTokenId[requestId];
        uint256 packedData = abi.decode(response, (uint256));
        
        s_playerData[tokenId].assists = uint64(packedData);
        s_playerData[tokenId].deaths = uint64(packedData >> 64);
        s_playerData[tokenId].kills = uint64(packedData >> 128);
        s_playerData[tokenId].games = uint64(packedData >> 192);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string memory imageBase64 = Base64.encode(bytes(generateSVG(tokenId)));
    
    // Kita tambahkan field "description" di sini
    string memory json = Base64.encode(
        bytes(
            string.concat(
                '{"name": "Kartu Pemain MPL ID #', tokenId.toString(), '", ',
                '"description": "Kartu dNFT MPL Indonesia. Statistik pemain diperbarui secara real-time dari API melalui Chainlink Functions.", ',
                '"image": "data:image/svg+xml;base64,', imageBase64, '"}'
            )
        )
    );
    return string.concat("data:application/json;base64,", json);
}

    // --- Automation ---
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval && targetTokenIdToUpdate < _tokenIds;
        performData = bytes("");
    }

    function performUpkeep(bytes calldata) external {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            _requestStatsInternal(targetTokenIdToUpdate, s_playerData[targetTokenIdToUpdate].name);
        }
    }
}