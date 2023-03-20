// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.18;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

/**
 *  @title Biorbit
 *
 *  NOTE:
 *
 */

contract Biorbit is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
	using Counters for Counters.Counter;

	bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
	Counters.Counter private protectAreaIdCounter;
	Counters.Counter private satelliteImageIdCounter;

	/* Constants and immutable */

	uint256 public donation = 0.2 ether;
	uint256 public price = 0.1 ether;

	/* Struct */

	struct SatelliteImage {
		uint id;
		IERC721 nft;
		string uri;
		uint price;
		bool sold;
		address payable seller;
	}

	struct ProtectedArea {
		uint256 id;
		string name;
		string photo;
		string description;
		string country;
		string geoJson;
		string lastDetectionDate;
		uint256 totalExtension;
		string[] detectionDates;
		uint256[] forestCoverExtensions;
		address[] donates;
		SatelliteImage[] satelliteImages;
	}

	/* Storage */

	mapping(uint256 => ProtectedArea) protectedAreas;
	mapping(string => bool) protectedAreasNamesUsed;
	mapping(uint => string) public satelliteImagesOfProtectedArea;

	/* Events */

	event ProtectedAreaCreated(uint256, string, string, string, string, string);

	constructor() ERC721('Biorbit', 'BOT') {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function monitorProtectedArea(
		string memory _name,
		string memory _photo,
		string memory _description,
		string memory _geoJson,
		string memory _country
	) external payable {
		require(msg.value >= donation, 'Insufficient funds');
		require(
			protectedAreasNamesUsed[_name] == false,
			'Protected area is being monitored.'
		);

		uint256 protectedAreaId = protectAreaIdCounter.current();
		protectAreaIdCounter.increment();

		ProtectedArea storage protectedArea = protectedAreas[protectedAreaId];
		protectedArea.id = protectedAreaId;
		protectedArea.name = _name;
		protectedArea.photo = _photo;
		protectedArea.description = _description;
		protectedArea.geoJson = _geoJson;
		protectedArea.country = _country;
		protectedArea.donates.push(msg.sender);

		emit ProtectedAreaCreated(
			protectedArea.id,
			protectedArea.name,
			protectedArea.photo,
			protectedArea.description,
			protectedArea.geoJson,
			protectedArea.country
		);
	}

	function storeMonitoringData(
		uint256 _protectedAreaId,
		string memory _protectedAreaName,
		string memory _lastDetectionDate,
		uint256 _totalExtension,
		string[] memory _detectionDates,
		uint256[] memory _forestCoverExtensions
	) external onlyRole(ADMIN_ROLE) {
		protectedAreasNamesUsed[_protectedAreaName] = true;

		ProtectedArea storage protectedArea = protectedAreas[_protectedAreaId];
		protectedArea.lastDetectionDate = _lastDetectionDate;
		protectedArea.totalExtension = _totalExtension;

		for (uint256 i = 0; i < _detectionDates.length; i++) {
			protectedArea.detectionDates.push(_detectionDates[i]);
		}

		for (uint256 i = 0; i < _forestCoverExtensions.length; i++) {
			protectedArea.forestCoverExtensions.push(_forestCoverExtensions[i]);
		}
	}

	function mint(
		string memory _protectedAreaName,
		uint256 _protectedAreaId,
		string memory _protectedAreaURI
	) public onlyRole(ADMIN_ROLE) returns (uint256) {
		require(
			protectedAreasNamesUsed[_protectedAreaName] == true,
			"Protected area isn't being monitored."
		);

		ProtectedArea storage protectedArea = protectedAreas[_protectedAreaId];

		require(
			keccak256(bytes(protectedArea.name)) ==
				keccak256(bytes(_protectedAreaName)),
			"They aren't the same protected area."
		);

		uint256 satelliteImageId = satelliteImageIdCounter.current();
		protectAreaIdCounter.increment();

		SatelliteImage memory satelliteImage = SatelliteImage({
			id: satelliteImageId,
			nft: this,
			uri: _protectedAreaURI,
			price: price,
			sold: false,
			seller: payable(msg.sender)
		});

		protectedArea.satelliteImages.push(satelliteImage);
		satelliteImagesOfProtectedArea[satelliteImageId] = _protectedAreaName;

		_safeMint(msg.sender, satelliteImageId);
		_setTokenURI(satelliteImageId, _protectedAreaURI);

		return satelliteImageId;
	}

	function sellSatelliteImage(
		uint256 _satelliteImageId
	) external onlyRole(ADMIN_ROLE) nonReentrant {
		string memory protectedAreaName = satelliteImagesOfProtectedArea[
			_satelliteImageId
		];
		require(
			bytes(protectedAreaName).length > 0,
			"Satellite image doesn't belong to any protected area."
		);
		require(
			this.ownerOf(_satelliteImageId) == msg.sender,
			"The owner isn't NFT owner"
		);
		require(
			this.getApproved(_satelliteImageId) == address(this),
			"The NFT isn't approved yet."
		);

		this.transferFrom(msg.sender, address(this), _satelliteImageId);
	}

	function getSatelliteImage(
		uint256 _satelliteImageId
	) public view returns (SatelliteImage memory) {
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			ProtectedArea storage protectedArea = protectedAreas[i];
			for (uint256 j = 0; j < protectedArea.satelliteImages.length; j++) {
				SatelliteImage storage satelliteImage = protectedArea.satelliteImages[
					j
				];
				if (satelliteImage.id == _satelliteImageId) {
					return satelliteImage;
				}
			}
		}
		revert('SatelliteImage not found');
	}

	function buySatelliteImage(
		uint256 _satelliteImageId
	) public payable nonReentrant {
		require(
			_satelliteImageId > 0 &&
				_satelliteImageId <= satelliteImageIdCounter.current(),
			"Satellite image doesn't exist."
		);

		SatelliteImage memory satelliteImage = getSatelliteImage(_satelliteImageId);

		require(msg.value == satelliteImage.price, 'Insufficient funds.');
		require(!satelliteImage.sold, 'Satellite Image already sold.');

		satelliteImage.sold = true;

		payable(msg.sender).transfer(price);
	}

	function tokenURI(
		uint256 tokenId
	) public view override(ERC721, ERC721URIStorage) returns (string memory) {
		return super.tokenURI(tokenId);
	}

	function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
		super._burn(tokenId);
	}

	function supportsInterface(
		bytes4 interfaceId
	) public view override(ERC721, AccessControl) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	function withdraw() external onlyRole(ADMIN_ROLE) {
		require(address(this).balance > 0, "The contract hasn't funds.");

		(bool response /*bytes memory data*/, ) = msg.sender.call{
			value: address(this).balance
		}('');
		require(response, 'reverted');
	}

	function receive() external {}

	// ************************************ //
	// *        Getters & Setters         * //
	// ************************************ //

	function setDonation(
		uint256 _donation
	) external onlyRole(ADMIN_ROLE) returns (uint256) {
		require(
			_donation != donation,
			'The new donation value must not be the same.'
		);
		require(
			_donation > 0,
			'The new donation value must be different non-zero.'
		);
		donation = _donation;
		return donation;
	}

	function setPrice(
		uint256 _price
	) external onlyRole(ADMIN_ROLE) returns (uint256) {
		require(_price != price, 'The new NFTs price must not be the same.');
		require(_price > 0, 'The new NFTs price must be different non-zero.');
		price = _price;
		return donation;
	}

	function getProtectedAreasByUsedNames()
		external
		view
		returns (ProtectedArea[] memory)
	{
		uint256 count = 0;
		// Calculate the number of protected areas with used names
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			if (protectedAreasNamesUsed[protectedAreas[i].name]) {
				count++;
			}
		}

		// Create an array to store the protected areas with used names
		ProtectedArea[] memory result = new ProtectedArea[](count);
		uint256 index = 0;
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			if (protectedAreasNamesUsed[protectedAreas[i].name]) {
				result[index] = protectedAreas[i];
				index++;
			}
		}
		return result;
	}

	function getProtectedAreasByNamePagination(
		string calldata name,
		uint256 page,
		uint256 pageSize
	) external view returns (ProtectedArea[] memory) {
		uint256 startIndex = page * pageSize;
		uint256 endIndex = startIndex + pageSize;

		uint256 count = 0;
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			if (
				keccak256(bytes(protectedAreas[i].name)) == keccak256(bytes(name)) &&
				protectedAreasNamesUsed[name]
			) {
				count++;
			}
		}

		require(startIndex < count, 'Invalid page');

		if (endIndex > count) {
			endIndex = count;
		}

		ProtectedArea[] memory result = new ProtectedArea[](endIndex - startIndex);
		uint256 index = 0;
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			if (
				keccak256(bytes(protectedAreas[i].name)) == keccak256(bytes(name)) &&
				protectedAreasNamesUsed[name]
			) {
				if (index >= startIndex && index < endIndex) {
					result[index - startIndex] = protectedAreas[i];
				}
				index++;
			}
		}
		return result;
	}

	function getProtectedAreaByName(
		string calldata name
	) public view returns (ProtectedArea memory) {
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			if (
				keccak256(bytes(protectedAreas[i].name)) == keccak256(bytes(name)) &&
				protectedAreasNamesUsed[name]
			) {
				return protectedAreas[i];
			}
		}

		revert('No matching protected area found.');
	}

	function getSoldSatelliteImagesByProtectedArea(
		string memory _protectedAreaName
	) external view returns (SatelliteImage[] memory) {
		require(
			protectedAreasNamesUsed[_protectedAreaName] == true,
			"Protected area isn't being monitored."
		);

		ProtectedArea storage protectedArea = protectedAreas[
			getProtectedAreaIdByName(_protectedAreaName)
		];
		SatelliteImage[] memory result = new SatelliteImage[](
			protectedArea.satelliteImages.length
		);
		uint256 unsoldImageCount = 0;

		for (uint256 i = 0; i < protectedArea.satelliteImages.length; i++) {
			if (!protectedArea.satelliteImages[i].sold) {
				result[unsoldImageCount] = protectedArea.satelliteImages[i];
				unsoldImageCount++;
			}
		}

		SatelliteImage[] memory unsoldSatelliteImages = new SatelliteImage[](
			unsoldImageCount
		);
		for (uint256 j = 0; j < unsoldImageCount; j++) {
			unsoldSatelliteImages[j] = result[j];
		}

		return unsoldSatelliteImages;
	}

	function getProtectedAreaIdByName(
		string memory _protectedAreaName
	) internal view returns (uint256) {
		for (uint256 i = 0; i < protectAreaIdCounter.current(); i++) {
			if (
				keccak256(bytes(protectedAreas[i].name)) ==
				keccak256(bytes(_protectedAreaName))
			) {
				return i;
			}
		}
		revert('Protected area not found.');
	}
}
