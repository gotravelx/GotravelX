const { exec } = require('child_process');
const util = require('util');

const execAsync = util.promisify(exec);

async function runTests() {
  console.log("🚀 Starting FlightStatusOracle Test Suite\n");

  try {
    // Clean and compile contracts
    console.log("📋 Cleaning and compiling contracts...");
    await execAsync('npx hardhat clean');
    await execAsync('npx hardhat compile');
    console.log("✅ Compilation successful\n");

    // Run basic tests
    console.log("🧪 Running basic tests...");
    const { stdout: basicTests } = await execAsync('npx hardhat test test/FlightStatusOracle.test.js');
    console.log(basicTests);

    // Run advanced tests
    console.log("🔬 Running advanced tests...");
    const { stdout: advancedTests } = await execAsync('npx hardhat test test/FlightStatusOracle.advanced.test.js');
    console.log(advancedTests);

    // Run all tests with gas reporting
    console.log("⛽ Running tests with gas reporting...");
    const { stdout: gasReport } = await execAsync('REPORT_GAS=true npx hardhat test');
    console.log(gasReport);

    // Generate coverage report
    console.log("📊 Generating coverage report...");
    const { stdout: coverage } = await execAsync('npx hardhat coverage');
    console.log(coverage);

    console.log("🎉 All tests completed successfully!");

  } catch (error) {
    console.error("❌ Test execution failed:");
    console.error(error.stdout || error.message);
    process.exit(1);
  }
}

// Test categories
const testCategories = {
  basic: async () => {
    console.log("Running basic functionality tests...");
    const { stdout } = await execAsync('npx hardhat test test/FlightStatusOracle.test.js');
    console.log(stdout);
  },
  
  advanced: async () => {
    console.log("Running advanced scenario tests...");
    const { stdout } = await execAsync('npx hardhat test test/FlightStatusOracle.advanced.test.js');
    console.log(stdout);
  },
  
  gas: async () => {
    console.log("Running gas optimization tests...");
    const { stdout } = await execAsync('REPORT_GAS=true npx hardhat test');
    console.log(stdout);
  },
  
  coverage: async () => {
    console.log("Generating code coverage report...");
    const { stdout } = await execAsync('npx hardhat coverage');
    console.log(stdout);
  }
};

// Command line argument handling
const testType = process.argv[2];

if (testType && testCategories[testType]) {
  testCategories[testType]()
    .then(() => console.log(`✅ ${testType} tests completed!`))
    .catch(error => {
      console.error(`❌ ${testType} tests failed:`, error.message);
      process.exit(1);
    });
} else if (testType) {
  console.log(`Unknown test type: ${testType}`);
  console.log('Available options: basic, advanced, gas, coverage');
  process.exit(1);
} else {
  runTests();
}

module.exports = { runTests, testCategories };