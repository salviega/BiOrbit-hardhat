require('@nomicfoundation/hardhat-toolbox')
require('@nomiclabs/hardhat-etherscan')
require('hardhat-deploy')
require('hardhat-deploy-ethers')
require('./tasks')
require('dotenv').config()

const { POLYGONSCAN_API_KEY, MUMBAI_RPC_URL, PRIVATE_KEY } = process.env

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
	solidity: {
		version: '0.8.17',
		settings: {
			optimizer: {
				enabled: true,
				runs: 2000,
				details: { yul: false }
			}
		}
	},
	defaultNetwork: 'mumbai',
	networks: {
		filecoinMainnet: {
			chainId: 314,
			url: 'https://api.node.glif.io',
			accounts: [PRIVATE_KEY],
			gas: 6000000, // Increase the gas limit
			gasPrice: 10000000000 // Set a custom gas price (in Gwei, optional)
		},
		hyperspace: {
			chainId: 3141,
			url: 'https://api.hyperspace.node.glif.io/rpc/v1',
			accounts: [PRIVATE_KEY],
			gas: 6000000, // Increase the gas limit
			gasPrice: 10000000000 // Set a custom gas price (in Gwei, optional)
		},
		mumbai: {
			chainId: 80001,
			accounts: [PRIVATE_KEY],
			url: MUMBAI_RPC_URL,
			gas: 6000000, // Increase the gas limit
			gasPrice: 10000000000 // Set a custom gas price (in Gwei, optional)
		}
	},
	etherscan: {
		apiKey: POLYGONSCAN_API_KEY
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts'
	}
}
