async function main() {
  const { chainId } = await global.ethers.provider.getNetwork()
  const args = require(`../args/args-${chainId}`)
  console.log(
    `Deploying to chain ${chainId}`,
    `with args = ${JSON.stringify(args, null, 2)}...`,
  )

  const MinterContract = await global.ethers.getContractFactory('SCVxACSMinter')
  const SCVxACSMinter = await MinterContract.deploy(...args)
  const tx = await SCVxACSMinter.deployed()
  await tx.deployTransaction.wait()
  console.log('Contract deployed to:', SCVxACSMinter.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
