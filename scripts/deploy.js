async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contract with account:", deployer.address);
  
    const balance = await deployer.getBalance();
    console.log("Account balance:", ethers.utils.formatEther(balance), "CAM");
  
    const TravelBooking = await ethers.getContractFactory("FlightBooking");
    const travelBooking = await TravelBooking.deploy();
  
    console.log("Go travel flight booking contract deployed to:", travelBooking.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  