// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// =============================================================================
// PlayerCardRenderer.sol
// Library untuk rendering SVG dengan sistem tier warna dinamis berbasis KDA
// =============================================================================

import "@openzeppelin/contracts/utils/Strings.sol";

library PlayerCardRenderer {
    using Strings for uint256;

    // =========================================================================
    // Tier KDA — disimpan sebagai konstant untuk kemudahan referensi di skripsi
    // KDA dikalikan 100 untuk menghindari floating point (Solidity tidak support)
    // Contoh: KDA 6.92 disimpan sebagai 692
    // =========================================================================
    uint256 constant TIER_BRONZE_MIN = 100;   // KDA >= 1.00
    uint256 constant TIER_SILVER_MIN = 500;   // KDA >= 5.00
    uint256 constant TIER_GOLD_MIN   = 1000;  // KDA >= 10.00
    uint256 constant TIER_LEGEND_MIN = 1500;  // KDA >= 15.00

    // =========================================================================
    // LAYER 0: Tier resolver — menentukan tier berdasarkan nilai KDA
    // Mengembalikan index: 0=Unranked, 1=Bronze, 2=Silver, 3=Gold, 4=Legend
    // =========================================================================
    function getTierIndex(uint256 kdaScaled) internal pure returns (uint8) {
        if (kdaScaled >= TIER_LEGEND_MIN) return 4;
        if (kdaScaled >= TIER_GOLD_MIN)   return 3;
        if (kdaScaled >= TIER_SILVER_MIN) return 2;
        if (kdaScaled >= TIER_BRONZE_MIN) return 1;
        return 0; // Unranked (KDA < 1.00)
    }

    // =========================================================================
    // LAYER 0: Tier name resolver
    // =========================================================================
    function getTierName(uint8 tierIndex) internal pure returns (string memory) {
        if (tierIndex == 4) return "LEGEND";
        if (tierIndex == 3) return "GOLD";
        if (tierIndex == 2) return "SILVER";
        if (tierIndex == 1) return "BRONZE";
        return "UNRANKED";
    }

    // =========================================================================
    // LAYER 1: Background — warna berubah dinamis sesuai tier KDA
    //
    // Struktur warna per tier:
    //   outerColor  = warna border terluar kartu
    //   innerColor  = warna background dalam kartu
    //   accentColor = warna aksen (garis, teks label, tier badge)
    //   glowColor   = warna efek glow pada border (opacity rendah)
    // =========================================================================
    function getBackgroundLayer(uint8 tierIndex) internal pure returns (string memory) {
        // Tentukan palet warna berdasarkan tier
        string memory outerColor;
        string memory innerColor;
        string memory accentColor;
        string memory tierBadgeColor;

        if (tierIndex == 4) {
            // Legend — ungu gelap dengan aksen violet terang
            outerColor     = "#1a0030";
            innerColor     = "#2d0050";
            accentColor    = "#bf7fff";
            tierBadgeColor = "#a020f0";
        } else if (tierIndex == 3) {
            // Gold — hitam keemasan dengan aksen emas terang
            outerColor     = "#1a1400";
            innerColor     = "#2a2000";
            accentColor    = "#ffd700";
            tierBadgeColor = "#c8a600";
        } else if (tierIndex == 2) {
            // Silver — abu-abu gelap dengan aksen perak terang
            outerColor     = "#1a1a1a";
            innerColor     = "#2a2a2a";
            accentColor    = "#c0c0c0";
            tierBadgeColor = "#a8a9ad";
        } else if (tierIndex == 1) {
            // Bronze — coklat tua dengan aksen tembaga terang
            outerColor     = "#1a0e00";
            innerColor     = "#2a1800";
            accentColor    = "#cd7f32";
            tierBadgeColor = "#a0622a";
        } else {
            // Unranked — hitam kebiruan (warna default asli)
            outerColor     = "#151515";
            innerColor     = "#022f52";
            accentColor    = "#ecf0f1";
            tierBadgeColor = "#555555";
        }

        string memory tierName = getTierName(tierIndex);

        return string.concat(
            // Background terluar
            '<rect x="0" y="0" width="320" height="400" fill="', outerColor, '"/>',
            // Background dalam
            '<rect x="8" y="8" width="304" height="384" fill="', innerColor, '"/>',
            // Border dekoratif — warna sesuai tier
            '<rect x="8" y="8" width="304" height="384" fill="none" stroke="', accentColor, '" stroke-width="1.5" rx="2"/>',
            // Header teks
            '<text x="160" y="36" fill="', accentColor, '" font-size="16" text-anchor="middle" font-weight="bold" font-family="monospace">PLAYER CARD</text>',
            // Garis bawah header — warna aksen
            '<line x1="20" y1="50" x2="300" y2="50" stroke="', accentColor, '" stroke-width="2"/>',
            // Tier badge — pojok kanan atas
            '<rect x="230" y="355" width="78" height="22" rx="4" fill="', tierBadgeColor, '"/>',
            '<text x="269" y="370" fill="#ffffff" font-size="11" text-anchor="middle" font-weight="bold" font-family="monospace">', tierName, '</text>'
        );
    }

    // =========================================================================
    // LAYER 2: Pixel Art — tidak berubah, sama untuk semua tier
    // =========================================================================
    function getPixelArtLayer() internal pure returns (string memory) {
        return '<svg x="10" y="30" width="140" height="380" viewBox="0 0 32 32" shape-rendering="crispEdges"><g transform="translate(32, 0) scale(-1, 1)"><path fill="#000000" d="M11 2h10v1H11z M9 3h2v1H9z M21 3h2v1H21z M8 4h1v1H8z M23 4h1v1H23z M8 5h1v1H8z M24 5h1v1H24z M8 6h1v1H8z M24 6h1v1H24z M8 7h1v1H8z M24 7h1v1H24z M8 8h1v1H8z M24 8h1v1H24z M9 9h1v1H9z M24 9h1v1H24z M9 10h1v1H9z M23 10h1v1H23z M9 11h1v1H9z M12 11h2v1H12z M18 11h2v1H18z M23 11h1v1H23z M9 12h1v1H9z M23 12h1v1H23z M10 13h1v1H10z M22 13h1v1H22z M10 14h1v1H10z M22 14h1v1H22z M10 15h1v1H10z M22 15h1v1H22z M11 16h1v1H11z M21 16h1v1H21z M11 17h1v1H11z M21 17h1v1H21z M12 18h1v1H12z M20 18h1v1H20z M12 19h1v1H12z M20 19h1v1H20z M11 20h1v1H11z M21 20h1v1H21z M9 21h2v1H9z M22 21h2v1H22z M7 22h2v1H7z M24 22h2v1H24z M6 23h1v1H6z M26 23h1v1H26z M5 24h1v1H5z M27 24h1v1H27z M4 25h1v1H4z M28 25h1v1H28z M3 26h1v1H3z M29 26h1v1H29z M3 27h1v1H3z M29 27h1v1H29z M3 28h1v1H3z M29 28h1v1H29z M3 29h1v1H3z M29 29h1v1H29z M3 30h1v1H3z M29 30h1v1H29z M3 31h27v1H3z" /><path fill="#000000" d="M11 3h10v1H11z M9 4h14v1H9z M9 5h15v1H9z M9 6h15v1H9z M9 7h15v1H9z M9 8h3v1H9z M20 8h4v1H20z M10 9h2v1H10z M22 9h2v1H22z M10 10h1v1H10z M22 10h1v1H22z" /><path fill="#e4b590" d="M12 8h8v1H12z M12 9h10v1H12z M11 10h11v1H11z M10 11h2v1H10z M14 11h4v1H14z M20 11h3v1H20z M10 12h13v1H10z M11 13h4v1H11z M17 13h5v1H17z M11 14h11v1H11z M11 15h3v1H11z M18 15h4v1H18z M12 16h9v1H12z M12 17h9v1H12z M13 18h7v1H13z" /><path fill="#c59473" d="M15 13h2v1H15z M13 19h7v1H13z M14 20h5v1H14z" /><path fill="#bd6a4f" d="M14 15h4v1H14z" /><path fill="#ffffff" d="M12 20h2v1H12z M19 20h2v1H19z M11 21h3v1H11z M19 21h3v1H19z M9 22h4v1H9z M20 22h4v1H20z M7 23h5v1H7z M21 23h5v1H21z M6 24h5v1H6z M22 24h5v1H22z M5 25h5v1H5z M13 25h2v1H13z M16 25h2v1H16z M19 25h2v1H19z M23 25h5v1H23z M4 26h5v1H4z M24 26h5v1H24z M4 27h4v1H4z M25 27h4v1H25z M4 28h4v1H4z M25 28h4v1H25z M4 29h4v1H4z M25 29h4v1H25z M6 30h2v1H6z M25 30h2v1H25z" /><path fill="#ef8115" d="M14 21h5v1H14z M13 22h7v1H13z M12 23h9v1H12z M11 24h11v1H11z M10 25h3v1H10z M15 25h1v1H15z M18 25h1v1H18z M21 25h2v1H21z M9 26h15v1H9z M8 27h17v1H8z M8 28h17v1H8z M8 29h17v1H8z M4 30h2v1H4z M8 30h17v1H8z M27 30h2v1H27z" /></g></svg>';
    }

    // =========================================================================
    // LAYER 3: Stats — warna label mengikuti aksen tier
    // =========================================================================
    function getStatsLayer(
        string memory name,
        string memory lane,
        uint64 games,
        uint64 kills,
        uint64 deaths,
        uint64 assists,
        string memory kdaStr,
        uint8 tierIndex
    ) internal pure returns (string memory) {
        // Warna label mengikuti tier
        string memory labelColor;
        if (tierIndex == 4)      labelColor = "#bf7fff"; // Legend — violet
        else if (tierIndex == 3) labelColor = "#ffd700"; // Gold — emas
        else if (tierIndex == 2) labelColor = "#c0c0c0"; // Silver — perak
        else if (tierIndex == 1) labelColor = "#cd7f32"; // Bronze — tembaga
        else                     labelColor = "#3498db"; // Unranked — biru default

        return string.concat(
            '<g transform="translate(180, 95)" shape-rendering="crispEdges">',
            '<text x="-30" y="20" fill="', labelColor, '" font-size="13" font-family="monospace">PLAYER NAME:</text>',
            '<text x="-30" y="46" fill="#ecf0f1" font-size="20" font-weight="bold" font-family="monospace">', name, '</text>',
            '<line x1="-25" y1="68" x2="120" y2="68" stroke="#555" stroke-width="3" stroke-dasharray="8,6"/>',
            _getStatsRows(lane, games, kills, deaths, assists, kdaStr, labelColor),
            '</g>'
        );
    }

    // Dipecah karena batas 32 argumen pada string.concat
    function _getStatsRows(
        string memory lane,
        uint64 games,
        uint64 kills,
        uint64 deaths,
        uint64 assists,
        string memory kdaStr,
        string memory labelColor
    ) internal pure returns (string memory) {
        return string.concat(
            '<text x="-30" y="92"  fill="', labelColor, '" font-size="13" font-family="monospace">LANE   :</text>',
            '<text x="120" y="92"  fill="#ecf0f1" font-size="13" text-anchor="end" font-family="monospace">', lane, '</text>',
            '<text x="-30" y="116" fill="', labelColor, '" font-size="13" font-family="monospace">GAMES  :</text>',
            '<text x="120" y="116" fill="#ecf0f1" font-size="13" text-anchor="end" font-family="monospace">', uint256(games).toString(), '</text>',
            '<text x="-30" y="140" fill="', labelColor, '" font-size="13" font-family="monospace">KILLS  :</text>',
            '<text x="120" y="140" fill="#ecf0f1" font-size="13" text-anchor="end" font-family="monospace">', uint256(kills).toString(), '</text>',
            '<text x="-30" y="164" fill="', labelColor, '" font-size="13" font-family="monospace">DEATHS :</text>',
            '<text x="120" y="164" fill="#ecf0f1" font-size="13" text-anchor="end" font-family="monospace">', uint256(deaths).toString(), '</text>',
            '<text x="-30" y="188" fill="', labelColor, '" font-size="13" font-family="monospace">ASSISTS:</text>',
            '<text x="120" y="188" fill="#ecf0f1" font-size="13" text-anchor="end" font-family="monospace">', uint256(assists).toString(), '</text>',
            '<text x="-30" y="212" fill="', labelColor, '" font-size="13" font-family="monospace">KDA    :</text>',
            '<text x="120" y="212" fill="#ecf0f1" font-size="13" text-anchor="end" font-family="monospace">', kdaStr, '</text>',
            '<line x1="-30" y1="228" x2="120" y2="228" stroke="#555" stroke-width="3" stroke-dasharray="8,6"/>'
        );
    }
}


// =============================================================================
// MplPlayerCard.sol — Kontrak utama
// =============================================================================

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract MplPlayerCard_A is ERC721URIStorage, Ownable, FunctionsClient {
    using Strings for uint256;
    using FunctionsRequest for FunctionsRequest.Request;

    error UnknownRequestId(bytes32 requestId);
    error OracleError(bytes err);
    error IntervalTooShort(uint256 provided, uint256 minimum);
    error NoTokensMinted();

    uint256 private _tokenIds;
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
    uint64 public subscriptionId;
    string public sourceCode;

    uint256 public lastTimeStamp;
    uint256 public constant MINIMUM_INTERVAL = 3600;
    uint256 public interval = 24 hours;
    uint256 public targetTokenIdToUpdate;

    struct PlayerData {
        string nickname; // Dipakai sebagai nama tampilan sekaligus identifier API
        string lane;
        uint64 games;
        uint64 kills;
        uint64 deaths;
        uint64 assists;
    }

    mapping(uint256 => PlayerData) public s_playerData;
    mapping(bytes32 => uint256) public s_requestToTokenId;
    mapping(bytes32 => bool) public s_requestExists;

    event PlayerStatsUpdated(
        uint256 indexed tokenId,
        uint64 games,
        uint64 kills,
        uint64 deaths,
        uint64 assists,
        uint8  tierIndex,   // tier baru setelah update — berguna untuk monitoring
        uint256 timestamp
    );
    event StatsRequested(uint256 indexed tokenId, bytes32 indexed requestId, string nickname);
    event AutomationSettingsChanged(uint256 newInterval, uint256 newTargetTokenId);

    constructor(uint64 _subscriptionId)
        ERC721("MPL Player Card", "MPLPC")
        Ownable(msg.sender)
        FunctionsClient(router)
    {
        subscriptionId = _subscriptionId;
        lastTimeStamp = block.timestamp;
    }

    // =========================================================================
    // generateSVG — merakit semua layer
    // Urutan layer (z-order dari bawah ke atas):
    //   Layer 1: Background (warna dinamis per tier)
    //   Layer 2: Pixel Art  (statis)
    //   Layer 3: Stats      (data dinamis + warna label per tier)
    // =========================================================================
    function generateSVG(uint256 tokenId) public view returns (string memory) {
        PlayerData memory d = s_playerData[tokenId];

        // Hitung KDA scaled (x100) untuk penentuan tier — hindari floating point
        uint64 safeDeaths = d.deaths == 0 ? 1 : d.deaths;
        uint256 kdaScaled = (uint256(d.kills) + uint256(d.assists)) * 100 / safeDeaths;

        // String KDA untuk ditampilkan (format: "6.92")
        string memory kdaStr = string.concat(
            (kdaScaled / 100).toString(), ".", (kdaScaled % 100).toString()
        );

        // Tentukan tier sekali, dipakai oleh layer 1 dan layer 3
        uint8 tierIndex = PlayerCardRenderer.getTierIndex(kdaScaled);

        return string.concat(
            '<svg width="320" height="400" viewBox="0 0 320 400" xmlns="http://www.w3.org/2000/svg">',
            '<g shape-rendering="crispEdges">',

            // LAYER 1: Background dinamis
            PlayerCardRenderer.getBackgroundLayer(tierIndex),

            '</g>',

            // LAYER 2: Pixel art statis
            PlayerCardRenderer.getPixelArtLayer(),

            // LAYER 3: Stats dengan warna label dinamis
            PlayerCardRenderer.getStatsLayer(
                d.nickname, d.lane,
                d.games, d.kills, d.deaths, d.assists,
                kdaStr, tierIndex
            ),

            '</svg>'
        );
    }

    // Fungsi publik untuk cek tier saat ini sebuah token (berguna untuk testing)
    function getTokenTier(uint256 tokenId) public view returns (uint8 tierIndex, string memory tierName) {
        PlayerData memory d = s_playerData[tokenId];
        uint64 safeDeaths = d.deaths == 0 ? 1 : d.deaths;
        uint256 kdaScaled = (uint256(d.kills) + uint256(d.assists)) * 100 / safeDeaths;
        tierIndex = PlayerCardRenderer.getTierIndex(kdaScaled);
        tierName  = PlayerCardRenderer.getTierName(tierIndex);
    }

    // =========================================================================
    // Minting & Management
    // =========================================================================
    function safeMint(address to, string memory _nickname, string memory _lane) public onlyOwner {
        uint256 tokenId = _tokenIds;
        s_playerData[tokenId] = PlayerData(_nickname, _lane, 0, 0, 0, 0);
        _safeMint(to, tokenId);
        _tokenIds++;
    }

    function setSourceCode(string memory _sourceCode) public onlyOwner {
        sourceCode = _sourceCode;
    }

    function requestStatsUpdate(uint256 tokenId) public onlyOwner {
        require(tokenId < _tokenIds, "Token ID tidak valid");
        _requestStatsInternal(tokenId, s_playerData[tokenId].nickname);
    }

    function setAutomationSettings(uint256 _intervalSeconds, uint256 _targetTokenId) public onlyOwner {
        if (_intervalSeconds < MINIMUM_INTERVAL) revert IntervalTooShort(_intervalSeconds, MINIMUM_INTERVAL);
        if (_tokenIds == 0) revert NoTokensMinted();
        require(_targetTokenId < _tokenIds, "Token ID tidak valid");
        interval = _intervalSeconds;
        targetTokenIdToUpdate = _targetTokenId;
        emit AutomationSettingsChanged(_intervalSeconds, _targetTokenId);
    }

    // =========================================================================
    // Chainlink Functions
    // =========================================================================
    function _requestStatsInternal(uint256 tokenId, string memory nickname) internal returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        string[] memory args = new string[](1);
        args[0] = nickname;
        req.setArgs(args);
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
        s_requestToTokenId[requestId] = tokenId;
        s_requestExists[requestId] = true;
        emit StatsRequested(tokenId, requestId, nickname);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (!s_requestExists[requestId]) revert UnknownRequestId(requestId);
        if (err.length > 0) revert OracleError(err);

        uint256 tokenId = s_requestToTokenId[requestId];
        uint256 packedData = abi.decode(response, (uint256));

        s_playerData[tokenId].assists = uint64(packedData);
        s_playerData[tokenId].deaths  = uint64(packedData >> 64);
        s_playerData[tokenId].kills   = uint64(packedData >> 128);
        s_playerData[tokenId].games   = uint64(packedData >> 192);

        delete s_requestExists[requestId];
        delete s_requestToTokenId[requestId];

        // Hitung tier baru untuk disertakan di event
        PlayerData memory d = s_playerData[tokenId];
        uint64 safeDeaths = d.deaths == 0 ? 1 : d.deaths;
        uint256 kdaScaled = (uint256(d.kills) + uint256(d.assists)) * 100 / safeDeaths;
        uint8 newTier = PlayerCardRenderer.getTierIndex(kdaScaled);

        emit PlayerStatsUpdated(
            tokenId,
            d.games, d.kills, d.deaths, d.assists,
            newTier,
            block.timestamp
        );
    }

    // =========================================================================
    // Token URI
    // =========================================================================
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        PlayerData memory d = s_playerData[tokenId];
        (, string memory tierName) = getTokenTier(tokenId);

        string memory imageBase64 = Base64.encode(bytes(generateSVG(tokenId)));
        string memory json = Base64.encode(bytes(string.concat(
            '{"name": "Kartu Pemain MPL ID #', tokenId.toString(), '", ',
            '"description": "Kartu dNFT MPL Indonesia. Statistik dan tampilan kartu diperbarui otomatis via Chainlink Functions.", ',
            '"attributes": [',
                '{"trait_type": "Nickname", "value": "',  d.nickname,                     '"},',
                '{"trait_type": "Lane", "value": "',      d.lane,                         '"},',
                '{"trait_type": "Tier", "value": "',      tierName,                       '"},',
                '{"trait_type": "Games", "value": ',      uint256(d.games).toString(),    '},',
                '{"trait_type": "Kills", "value": ',      uint256(d.kills).toString(),    '},',
                '{"trait_type": "Deaths", "value": ',     uint256(d.deaths).toString(),   '},',
                '{"trait_type": "Assists", "value": ',    uint256(d.assists).toString(),  '}',
            '], ',
            '"image": "data:image/svg+xml;base64,', imageBase64, '"}'
        )));
        return string.concat("data:application/json;base64,", json);
    }

    // =========================================================================
    // Chainlink Automation
    // =========================================================================
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval && targetTokenIdToUpdate < _tokenIds;
        performData = bytes("");
    }

    function performUpkeep(bytes calldata) external {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            _requestStatsInternal(targetTokenIdToUpdate, s_playerData[targetTokenIdToUpdate].nickname);
        }
    }

    // =========================================================================
    // View Helpers
    // =========================================================================
    function totalSupply() public view returns (uint256) { return _tokenIds; }

    function getPlayerData(uint256 tokenId) public view returns (PlayerData memory) {
        require(tokenId < _tokenIds, "Token ID tidak valid");
        return s_playerData[tokenId];
    }
}
