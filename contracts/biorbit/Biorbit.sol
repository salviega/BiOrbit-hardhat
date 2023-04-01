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
 *  NOTE: Biorbit is a blockchain-based platform that enables monitoring and protection of Earth's natural resources
 *  through satellite imagery and community engagement. Users can contribute to the platform by donating to monitor
 *  protected areas and purchasing satellite images, ultimately fostering sustainable development and environmental conservation.
 *
 */

contract Biorbit is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
	using Counters for Counters.Counter;

	bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
	Counters.Counter public protectAreaIdCounter;
	Counters.Counter public satelliteImageIdCounter;

	/* Constants and immutable */

	uint256 public donation = 0.0000002 ether;
	uint256 public price = 0.0000001 ether;
	address public relay;

	/* Struct */

	struct SatelliteImage {
		uint256 id;
		IERC721 nft;
		string uri;
		uint256 price;
		bool sold;
		address payable seller;
	}

	struct ProtectedArea {
		uint256 id;
		string name;
		string footprint;
		string lastDetectionDate;
		string totalExtension;
		string[] detectionDates;
		string[] forestCoverExtensions;
		address[] donates;
		SatelliteImage[] satelliteImages;
	}

	/* Storage */

	mapping(uint256 => ProtectedArea) protectedAreas;
	mapping(string => bool) protectedAreasNamesUsed;
	mapping(uint256 => string) public satelliteImagesOfProtectedArea;

	/* Events */

	event ProtectedAreaCreated(uint256, string, string);

	constructor(address _relay) ERC721('Biorbit', 'BOT') {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(ADMIN_ROLE, msg.sender);
		relay = _relay;
	}

	function monitorProtectedArea(
		string memory _name,
		string memory _footprint
	) external payable {
		require(msg.value >= donation, 'Insufficient funds');
		require(
			!protectedAreasNamesUsed[_name],
			'Protected area is already being monitored.'
		);

		uint256 protectedAreaId = _getNextProtectedAreaId();
		ProtectedArea storage protectedArea = protectedAreas[protectedAreaId];
		_setProtectedAreaData(protectedArea, protectedAreaId, _name, _footprint);
		protectedArea.donates.push(msg.sender);

		payable(relay).transfer(msg.value);

		protectedAreasNamesUsed[_name] = true;

		emit ProtectedAreaCreated(
			protectedArea.id,
			protectedArea.name,
			protectedArea.footprint
		);
	}

	function storeMonitoringData(
		uint256 _protectedAreaId,
		string memory _protectedAreaName,
		string memory _lastDetectionDate,
		string memory _totalExtension,
		string[] memory _detectionDates,
		string[] memory _forestCoverExtensions
	) external onlyRole(ADMIN_ROLE) {
		_validateProtectedArea(_protectedAreaName, _protectedAreaId);
		_validateProtectedAreaData(_protectedAreaId);

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
		uint256 _protectedAreaId,
		string memory _protectedAreaName,
		string memory _protectedAreaURI
	) public onlyRole(ADMIN_ROLE) returns (uint256) {
		_validateProtectedArea(_protectedAreaName, _protectedAreaId);

		uint256 satelliteImageId = _getNextSatelliteImageId();

		SatelliteImage memory satelliteImage = _createSatelliteImage(
			satelliteImageId,
			_protectedAreaURI,
			msg.sender
		);
		_addSatelliteImageToProtectedArea(
			_protectedAreaId,
			_protectedAreaName,
			satelliteImage,
			satelliteImageId
		);

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
		address owner = this.ownerOf(_satelliteImageId);
		address approved = this.getApproved(_satelliteImageId);

		require(
			bytes(protectedAreaName).length > 0,
			"Satellite image doesn't belong to any protected area."
		);

		require(owner == msg.sender, "The owner isn't NFT owner");

		require(approved == address(this), "The NFT isn't approved yet.");

		this.transferFrom(msg.sender, address(this), _satelliteImageId);
	}

	function buySatelliteImage(
		uint256 _satelliteImageId,
		string memory _protectedAreaName
	) public payable nonReentrant {
		require(
			_satelliteImageId <= satelliteImageIdCounter.current(),
			"Satellite image doesn't exist."
		);
		ProtectedArea memory protectedAreaMemory = getProtectedAreaByName(
			_protectedAreaName
		);

		ProtectedArea storage protectedArea = protectedAreas[
			protectedAreaMemory.id
		];

		SatelliteImage storage satelliteImage;

		for (uint i = 0; i < protectedArea.satelliteImages.length; i++) {
			if (protectedArea.satelliteImages[i].id == _satelliteImageId) {
				satelliteImage = protectedArea.satelliteImages[i];
				require(msg.value == satelliteImage.price, 'Insufficient funds.');
				require(!satelliteImage.sold, 'Satellite Image already sold.');

				satelliteImage.sold = true;

				payable(msg.sender).transfer(satelliteImage.price);
				break;
			}
		}
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

	// *********************************** //
	// *        Private funcions         * //
	// *********************************** //

	function _validateProtectedArea(
		string memory _protectedAreaName,
		uint256 _protectedAreaId
	) private view {
		require(
			protectedAreasNamesUsed[_protectedAreaName],
			'Protected area is being monitored.'
		);

		ProtectedArea storage protectedArea = protectedAreas[_protectedAreaId];

		require(
			keccak256(bytes(protectedArea.name)) ==
				keccak256(bytes(_protectedAreaName)),
			"They aren't the same protected area."
		);
	}

	function _validateProtectedAreaData(uint256 _protectedAreaId) private view {
		ProtectedArea storage protectedArea = protectedAreas[_protectedAreaId];

		require(
			bytes(protectedArea.lastDetectionDate).length == 0,
			'Protected area already has lastDetectionDate.'
		);

		require(
			bytes(protectedArea.totalExtension).length == 0,
			'Protected area already has totalExtension.'
		);

		require(
			protectedArea.detectionDates.length == 0,
			'Protected area already has detectionDates.'
		);

		require(
			protectedArea.forestCoverExtensions.length == 0,
			'Protected area already has forestCoverExtensions.'
		);
	}

	function _getNextSatelliteImageId() private returns (uint256) {
		uint256 satelliteImageId = satelliteImageIdCounter.current();
		satelliteImageIdCounter.increment();
		return satelliteImageId;
	}

	function _getNextProtectedAreaId() private returns (uint256) {
		uint256 protectedAreaId = protectAreaIdCounter.current();
		protectAreaIdCounter.increment();
		return protectedAreaId;
	}

	function _createSatelliteImage(
		uint256 _satelliteImageId,
		string memory _protectedAreaURI,
		address _seller
	) private view returns (SatelliteImage memory) {
		SatelliteImage memory satelliteImage = SatelliteImage({
			id: _satelliteImageId,
			nft: this,
			uri: _protectedAreaURI,
			price: price,
			sold: false,
			seller: payable(_seller)
		});

		return satelliteImage;
	}

	function _addSatelliteImageToProtectedArea(
		uint256 _protectedAreaId,
		string memory _protectedAreaName,
		SatelliteImage memory _satelliteImage,
		uint256 _satelliteImageId
	) private {
		ProtectedArea storage protectedArea = protectedAreas[_protectedAreaId];
		protectedArea.satelliteImages.push(_satelliteImage);
		satelliteImagesOfProtectedArea[_satelliteImageId] = _protectedAreaName;
	}

	function _setProtectedAreaData(
		ProtectedArea storage protectedArea,
		uint256 _id,
		string memory _name,
		string memory _footprint
	) private {
		protectedArea.id = _id;
		protectedArea.name = _name;
		protectedArea.footprint = _footprint;
	}

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

	function setRelayAddress(address _relay) external onlyRole(ADMIN_ROLE) {
		require(_relay != address(0), 'Invalid relay address');
		relay = _relay;
	}

	function setPrice(
		uint256 _price
	) external onlyRole(ADMIN_ROLE) returns (uint256) {
		require(_price != price, 'The new NFTs price must not be the same.');
		require(_price > 0, 'The new NFTs price must be different non-zero.');
		price = _price;
		return donation;
	}

	function totalAsserts() public view returns (uint256) {
		return address(this).balance;
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

	function getProtectedAreaByName(
		string memory name
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
