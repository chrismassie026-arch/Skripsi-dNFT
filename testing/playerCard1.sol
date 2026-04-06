// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract MplSvgRenderer {
    using Strings for uint256;

    // Fungsi untuk mengubah integer KDA (misal: 452) menjadi string desimal (4.52)
    function formatKda(uint256 _kda) public pure returns (string memory) {
        uint256 integerPart = _kda / 100;
        uint256 decimalPart = _kda % 100;
        string memory decimalStr = decimalPart < 10 ? 
            string.concat("0", decimalPart.toString()) : 
            decimalPart.toString();
        return string.concat(integerPart.toString(), ".", decimalStr);
    }

    function generateSVG(
        string memory _name, 
        string memory _lane, 
        uint256 _games, 
        uint256 _kda
    ) public pure returns (string memory) {
        // Bagian Awal SVG (Hingga sebelum Nama Pemain)
        string memory svgHeader = '<svg width="320" height="400" viewBox="0 0 320 400" xmlns="http://www.w3.org/2000/svg"><g shape-rendering="crispEdges"><rect x="0" y="0" width="320" height="400" fill="#ecf0f1"/><rect x="8" y="8" width="304" height="384" fill="#022f52"/><text x="160" y="40" fill="#ecf0f1" font-size="20" text-anchor="middle" font-weight="bold">PLAYER CARD</text><line x1="20" y1="55" x2="300" y2="55" stroke="#ecf0f1" stroke-width="4"/></g>';
        
        // Pixel Art Karakter (Statis)
        string memory pixelArt = '<svg x="0" y="30" width="150" height="380" viewBox="0 0 32 32" shape-rendering="crispEdges"><path fill="#000000" d="M11 2h10v1H11z M9 3h2v1H9z...[KODE PATH LENGKAP ANDA]..." /></svg>';

        // Data Dinamis
        string memory dynamicSection = string.concat(
            '<g transform="translate(180, 100)" shape-rendering="crispEdges">',
            '<text x="-30" y="20" fill="#3498db" font-size="14">PLAYER NAME:</text>',
            '<text x="-30" y="50" fill="#ecf0f1" font-size="24" font-weight="bold">', _name, '</text>',
            '<line x1="-25" y1="75" x2="120" y2="75" stroke="#555" stroke-width="4" stroke-dasharray="8,6"/>',
            '<text x="-30" y="115" fill="#e74c3c" font-size="14">LANE:</text>',
            '<text x="120" y="115" fill="#ecf0f1" font-size="14" text-anchor="end">', _lane, '</text>',
            '<text x="-30" y="155" fill="#95a5a6" font-size="14">GAME:</text>',
            '<text x="120" y="155" fill="#ecf0f1" font-size="14" text-anchor="end">', _games.toString(), '</text>',
            '<text x="-30" y="195" fill="#2ecc71" font-size="14">KDA:</text>',
            '<text x="120" y="195" fill="#ecf0f1" font-size="14" text-anchor="end">', formatKda(_kda), '</text>',
            '</g></svg>'
        );

        return string.concat(svgHeader, pixelArt, dynamicSection);
    }
}