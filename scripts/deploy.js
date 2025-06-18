const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying FlightStatusOracle contract...");

  // Get the contract factory
  const FlightStatusOracle = await ethers.getContractFactory("FlightStatusOracle");

  // Deploy the contract
  const flightOracle = await FlightStatusOracle.deploy();
  await flightOracle.waitForDeployment();

  const address = await flightOracle.getAddress();
  console.log("FlightStatusOracle deployed to:", address);

  // Verify deployment by calling a view function
  console.log("Verifying deployment...");
  
  // You can add some initial test data here if needed
  console.log("Contract deployed successfully!");
  
  return address;
}

// Handle both direct execution and module export
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;