// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Impor dari standar OpenZeppelin
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

// Impor Chainlink Functions (Path terbaru tanpa direktori 'dev')
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * @title MPLDynamicNFT
 * @dev Implementasi dNFT untuk kartu pemain MPL Indonesia dengan SVG On-Chain 
 * dan pembaruan data menggunakan Chainlink Functions. 
 */
contract MPLDynamicNFT is ERC721, Ownable, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256; 

    // --- State Variables dNFT --- 
    uint256 private _nextTokenId; 

    // Struktur data statistik pemain (Player Names, Lanes, Total Games, Average KDA)
    struct PlayerStats {
        string playerName;
        string playerLane;
        uint256 totalGames;
        uint256 averageKDA; // Disimpan sebagai integer (misal: KDA 3.52 disimpan sebagai 352) untuk optimasi
    }

    mapping(uint256 => PlayerStats) public playerStats;

    // --- State Variables Chainlink Functions ---
    bytes32 public donId; // ID dari Decentralized Oracle Network
    uint64 public subscriptionId; // ID langganan Chainlink billing
    uint32 public gasLimit = 300000;
    string public sourceCode; // Kode JavaScript off-chain untuk web scraping web MPL

    // Mapping untuk melacak request ID ke Token ID saat update berlangsung
    mapping(bytes32 => uint256) public pendingRequests;

    // --- Events ---
    event StatUpdateRequestSent(bytes32 indexed requestId, uint256 indexed tokenId);
    event StatUpdated(uint256 indexed tokenId, string playerName, string playerLane, uint256 totalGames, uint256 averageKDA);
    event ResponseError(bytes32 indexed requestId, bytes err);

    /**
     * @param router Alamat Chainlink Functions Router (Sepolia: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0)
     * @param _donId ID DON Chainlink (Sepolia: fun-ethereum-sepolia-1)
     * @param _subscriptionId ID Subscription Chainlink
     */
    constructor(
        address router,
        bytes32 _donId,
        uint64 _subscriptionId
    ) ERC721("MPL Player Card", "MPLNFT") Ownable() FunctionsClient(router) {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    /**
     * @dev Mencetak dNFT baru dengan data statistik awal.
     */
    function mintCard(
        address to,
        string memory _playerName,
        string memory _playerLane,
        uint256 _totalGames,
        uint256 _averageKDA
    ) external onlyOwner {
        uint256 tokenId = _nextTokenId++;
        
        playerStats[tokenId] = PlayerStats({
            playerName: _playerName,
            playerLane: _playerLane,
            totalGames: _totalGames,
            averageKDA: _averageKDA
        });

        _safeMint(to, tokenId);
    }

    // --- Chainlink Functions Logic ---

    /**
     * @dev Meminta pembaruan statistik ke oracle (Layer 2) menggunakan Chainlink Functions.
     * @param tokenId ID token yang ingin diperbarui
     * @param args Parameter untuk script off-chain (misal: URL/ID pemain di web MPL)
     */
    function requestStatUpdate(uint256 tokenId, string[] calldata args) external onlyOwner returns (bytes32 requestId) {
        require(_ownerOf(tokenId) != address(0), "Token tidak ada");

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        
        if (args.length > 0) {
            req.setArgs(args);
        }

        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donId
        );

        pendingRequests[requestId] = tokenId;
        emit StatUpdateRequestSent(requestId, tokenId);
    }

    /**
     * @dev Callback yang dipanggil oleh Chainlink DON setelah script off-chain selesai tereksekusi.
     * Menerima byte data hasil agregasi, melakukan decode, dan memperbarui state.
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        uint256 tokenId = pendingRequests[requestId];
        require(_exists(tokenId), "Token tidak ditemukan untuk request ini");

        if (err.length > 0) {
            emit ResponseError(requestId, err);
            return;
        }

        // Asumsi skrip JavaScript off-chain mereturn data dengan tipe:
        // abi.encode(string playerName, string playerLane, uint256 totalGames, uint256 averageKDA)
        (
            string memory newName,
            string memory newLane,
            uint256 newGames,
            uint256 newKDA
        ) = abi.decode(response, (string, string, uint256, uint256));

        // Update data on-chain
        playerStats[tokenId] = PlayerStats(newName, newLane, newGames, newKDA);

        emit StatUpdated(tokenId, newName, newLane, newGames, newKDA);
        delete pendingRequests[requestId]; // Bersihkan memori
    }

    // --- SVG & Metadata Generation (Layered SVG Assembly) ---

    /**
     * @dev Helper untuk mengubah integer KDA (misal 352) menjadi string desimal ("3.52").
     */
    function _formatKDA(uint256 _kda) internal pure returns (string memory) {
        uint256 base = _kda / 100;
        uint256 fraction = _kda % 100;
        
        string memory fractionStr = fraction.toString();
        // Padding nol jika di bawah 10 (misal: 305 menjadi "3.05" bukan "3.5")
        if (fraction < 10) {
            fractionStr = string(abi.encodePacked("0", fractionStr));
        }
        return string(abi.encodePacked(base.toString(), ".", fractionStr));
    }

    /**
     * @dev Menyatukan komponen SVG. Implementasi "Layered SVG Assembly" untuk optimasi gas.
     * Bagian statis dipisahkan dari bagian teks yang dinamis.
     */
    function buildSVG(uint256 tokenId) internal view returns (string memory) {
        PlayerStats memory stats = playerStats[tokenId];

        // Layer 1: Komponen Grafis Statis (Background, Bingkai, Pixel Art)
        // Dipecah menjadi beberapa bagian untuk menghindari limitasi panjang string Solidity
        string memory svgBase1 = "<svg width='320' height='400' viewBox='0 0 320 400' xmlns='http://www.w3.org/2000/svg'><g shape-rendering='crispEdges'><rect x='0' y='0' width='320' height='400' fill='#ecf0f1'/><rect x='8' y='8' width='304' height='384' fill='#022f52'/><text x='160' y='40' fill='#ecf0f1' font-size='20' text-anchor='middle' font-weight='bold'>PLAYER CARD</text><line x1='20' y1='55' x2='300' y2='55' stroke='#ecf0f1' stroke-width='4'/></g>";
        string memory svgBase2 = "<svg x='0' y='30' width='150' height='380' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32' shape-rendering='crispEdges'><path fill='#000000' d='M11 2h10v1H11z M9 3h2v1H9z M21 3h2v1H21z M8 4h1v1H8z M23 4h1v1H23z M8 5h1v1H8z M24 5h1v1H24z M8 6h1v1H8z M24 6h1v1H24z M8 7h1v1H8z M24 7h1v1H24z M8 8h1v1H8z M24 8h1v1H24z M9 9h1v1H9z M24 9h1v1H24z M9 10h1v1H9z M23 10h1v1H23z M9 11h1v1H9z M12 11h2v1H12z M18 11h2v1H18z M23 11h1v1H23z M9 12h1v1H9z M23 12h1v1H23z M10 13h1v1H10z M22 13h1v1H22z M10 14h1v1H10z M22 14h1v1H22z M10 15h1v1H10z M22 15h1v1H22z M11 16h1v1H11z M21 16h1v1H21z M11 17h1v1H11z M21 17h1v1H21z M12 18h1v1H12z M20 18h1v1H20z M12 19h1v1H12z M20 19h1v1H20z M11 20h1v1H11z M21 20h1v1H21z M9 21h2v1H9z M22 21h2v1H22z M7 22h2v1H7z M24 22h2v1H24z M6 23h1v1H6z M26 23h1v1H26z M5 24h1v1H5z M27 24h1v1H27z M4 25h1v1H4z M28 25h1v1H28z M3 26h1v1H3z M29 26h1v1H29z M3 27h1v1H3z M29 27h1v1H29z M3 28h1v1H3z M29 28h1v1H29z M3 29h1v1H3z M29 29h1v1H29z M3 30h1v1H3z M29 30h1v1H29z M3 31h27v1H3z' /><path fill='gray' d='M11 3h10v1H11z M9 4h14v1H9z M9 5h15v1H9z M9 6h15v1H9z M9 7h15v1H9z M9 8h3v1H9z M20 8h4v1H20z M10 9h2v1H10z M22 9h2v1H22z M10 10h1v1H10z M22 10h1v1H22z' /><path fill='#e4b590' d='M12 8h8v1H12z M12 9h10v1H12z M11 10h11v1H11z M10 11h2v1H10z M14 11h4v1H14z M20 11h3v1H20z M10 12h13v1H10z M11 13h4v1H11z M17 13h5v1H17z M11 14h11v1H11z M11 15h3v1H11z M18 15h4v1H18z M12 16h9v1H12z M12 17h9v1H12z M13 18h7v1H13z' />";
        string memory svgBase3 = "<path fill='#c59473' d='M15 13h2v1H15z M13 19h7v1H13z M14 20h5v1H14z' /><path fill='#bd6a4f' d='M14 15h4v1H14z' /><path fill='#ffffff' d='M12 20h2v1H12z M19 20h2v1H19z M11 21h3v1H11z M19 21h3v1H19z M9 22h4v1H9z M20 22h4v1H20z M7 23h5v1H7z M21 23h5v1H21z M6 24h5v1H6z M22 24h5v1H22z M5 25h5v1H5z M13 25h2v1H13z M16 25h2v1H16z M19 25h2v1H19z M23 25h5v1H23z M4 26h5v1H4z M24 26h5v1H24z M4 27h4v1H4z M25 27h4v1H25z M4 28h4v1H4z M25 28h4v1H25z M4 29h4v1H4z M25 29h4v1H25z M6 30h2v1H6z M25 30h2v1H25z' /><path fill='#ef8115' d='M14 21h5v1H14z M13 22h7v1H13z M12 23h9v1H12z M11 24h11v1H11z M10 25h3v1H10z M15 25h1v1H15z M18 25h1v1H18z M21 25h2v1H21z M9 26h15v1H9z M8 27h17v1H8z M8 28h17v1H8z M8 29h17v1H8z M4 30h2v1H4z M8 30h17v1H8z M27 30h2v1H27z' /></svg>";

        // Layer 2: Teks Dinamis
        string memory textName = string(abi.encodePacked(
            "<g transform='translate(180, 100)' shape-rendering='crispEdges'><text x='-30' y='20' fill='#3498db' font-size='14'>PLAYER NAME:</text><text x='-30' y='50' fill='#ecf0f1' font-size='24' font-weight='bold'>",
            stats.playerName,
            "</text><line x1='-25' y1='75' x2='120' y2='75' stroke='#555' stroke-width='4' stroke-dasharray='8,6'/>"
        ));

        string memory textLane = string(abi.encodePacked(
            "<text x='-30' y='115' fill='#e74c3c' font-size='14'>LANE:</text><text x='120' y='115' fill='#ecf0f1' font-size='14' text-anchor='end'>",
            stats.playerLane,
            "</text>"
        ));

        string memory textGames = string(abi.encodePacked(
            "<text x='-30' y='155' fill='#95a5a6' font-size='14'>GAME:</text><text x='120' y='155' fill='#ecf0f1' font-size='14' text-anchor='end'>",
            stats.totalGames.toString(),
            "</text>"
        ));

        string memory textKDA = string(abi.encodePacked(
            "<text x='-30' y='195' fill='#2ecc71' font-size='14'>KDA:</text><text x='120' y='195' fill='#ecf0f1' font-size='14' text-anchor='end'>",
            _formatKDA(stats.averageKDA),
            "</text><line x1='-30' y1='225' x2='120' y2='225' stroke='#555' stroke-width='4' stroke-dasharray='8,6'/></g></svg>"
        ));

        // Menggabungkan semua layer
        return string(abi.encodePacked(svgBase1, svgBase2, svgBase3, textName, textLane, textGames, textKDA));
    }

    /**
     * @dev Fungsi utama ERC721 untuk membaca metadata. Men-generate JSON dan SVG on-chain secara langsung.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token tidak ada");

        // Konversi gambar SVG ke dalam format Base64
        string memory svg = buildSVG(tokenId);
        string memory base64Svg = Base64.encode(bytes(svg));
        string memory imageURI = string(abi.encodePacked("data:image/svg+xml;base64,", base64Svg));

        PlayerStats memory stats = playerStats[tokenId];

        // Membangun metadata JSON yang berstandar ERC721
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "', stats.playerName, ' - MPL Player Card",',
                        '"description": "Dynamic NFT Kartu Pemain eSports MPL Indonesia yang secara otonom memperbarui data statistik melalui Chainlink Functions.",',
                        '"image": "', imageURI, '",',
                        '"attributes": [',
                            '{"trait_type": "Lane", "value": "', stats.playerLane, '"},',
                            '{"display_type": "number", "trait_type": "Total Games", "value": ', stats.totalGames.toString(), '},',
                            '{"display_type": "number", "trait_type": "Avg KDA", "value": ', _formatKDA(stats.averageKDA), '}',
                        ']}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    // --- Admin Configuration ---

    function setSourceCode(string calldata _sourceCode) external onlyOwner {
        sourceCode = _sourceCode;
    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }
}