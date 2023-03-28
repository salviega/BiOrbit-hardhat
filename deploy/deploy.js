require('hardhat-deploy')
require('hardhat-deploy-ethers')

const { networkConfig } = require('../helper-hardhat-config')

const private_key = network.config.accounts[0]
const wallet = new ethers.Wallet(private_key, ethers.provider)

module.exports = async ({ deployments }) => {
	console.log('Wallet Ethereum Address:', wallet.address)
	const chainId = network.config.chainId

	//deploy Biorbit
	const Biorbit = await ethers.getContractFactory('Biorbit', wallet)
	console.log('Deploying Biorbit...')
	const biorbit = await Biorbit.deploy(
		'0xE8e1543235e6C35C656ef0b28526C61571583f4B'
	)
	await biorbit.deployed()
	console.log('biorbit deployed to:', biorbit.address)
}
