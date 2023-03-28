require('@nomicfoundation/hardhat-toolbox')
require('hardhat-deploy')
require('hardhat-deploy-ethers')
require('./tasks')
require('dotenv').config()

const PRIVATE_KEY = process.env.PRIVATE_KEY
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
	defaultNetwork: 'Hyperspace',
	networks: {
		Hyperspace: {
			chainId: 3141,
			url: 'https://api.hyperspace.node.glif.io/rpc/v1',
			accounts: [PRIVATE_KEY],
			gas: 6000000, // Increase the gas limit
			gasPrice: 10000000000 // Set a custom gas price (in Gwei, optional)
		},
		FilecoinMainnet: {
			chainId: 314,
			url: 'https://api.node.glif.io',
			accounts: [PRIVATE_KEY],
			gas: 6000000, // Increase the gas limit
			gasPrice: 10000000000 // Set a custom gas price (in Gwei, optional)
		}
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts'
	}
}
