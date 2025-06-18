const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FlightStatusOracle", function () {
  let flightOracle;
  let owner;
  let user1, user2;

  // Sample flight data for testing
  const sampleFlightData = [
    "AA123",           // flightNumber
    "2025-06-15",      // scheduledDepartureDate  
    "AA",              // carrierCode
    "New York",        // arrivalCity
    "Los Angeles",     // departureCity
    "JFK",             // arrivalAirport
    "LAX",             // departureAirport
    "AA",              // operatingAirlineCode
    "A12",             // arrivalGate
    "B5",              // departureGate
    "On Time",         // flightStatus
    "Boeing 737"       // equipmentModel
  ];

  const sampleUtcTimes = [
    "2025-06-15T10:30:00Z", // actualArrivalUTC
    "2025-06-15T06:00:00Z", // actualDepartureUTC
    "2025-06-15T10:35:00Z", // estimatedArrivalUTC
    "2025-06-15T06:05:00Z", // estimatedDepartureUTC
    "2025-06-15T10:30:00Z", // scheduledArrivalUTC
    "2025-06-15T06:00:00Z", // scheduledDepartureUTC
    "5",                    // arrivalDelayMinutes
    "5",                    // departureDelayMinutes
    "Carousel 3"            // bagClaim
  ];

  const sampleStatus = [
    "OT",              // flightStatusCode
    "On Time",         // flightStatusDescription
    "Arrived",         // ArrivalState
    "Departed",        // DepartureState
    "2025-06-15T06:00:00Z", // outUtc
    "2025-06-15T06:15:00Z", // offUtc
    "2025-06-15T10:15:00Z", // onUtc
    "2025-06-15T10:30:00Z"  // inUtc
  ];

  const sampleMarketingCodes = ["AA", "DL"];
  const sampleMarketingFlightNumbers = ["AA123", "DL456"];

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    const FlightStatusOracle = await ethers.getContractFactory("FlightStatusOracle");
    flightOracle = await FlightStatusOracle.deploy();
    await flightOracle.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      expect(await flightOracle.getAddress()).to.not.equal(ethers.ZeroAddress);
    });
  });

  describe("Flight Data Insertion", function () {
    it("Should insert flight details successfully", async function () {
      await expect(
        flightOracle.insertFlightDetails(
          sampleFlightData,
          sampleUtcTimes,
          sampleStatus,
          sampleMarketingCodes,
          sampleMarketingFlightNumbers
        )
      ).to.not.be.reverted;

      // Check if flight exists
      expect(await flightOracle.isFlightExist("AA123")).to.be.true;
    });

    it("Should emit FlightDataSet event", async function () {
      await expect(
        flightOracle.insertFlightDetails(
          sampleFlightData,
          sampleUtcTimes,
          sampleStatus,
          sampleMarketingCodes,
          sampleMarketingFlightNumbers
        )
      ).to.emit(flightOracle, "FlightDataSet")
       .withArgs(
         "AA123",
         "2025-06-15",
         "AA",
         "New York",
         "Los Angeles", 
         "JFK",
         "LAX",
         "A12",
         "B5",
         "On Time",
         [
           "2025-06-15T10:30:00Z",
           "2025-06-15T06:00:00Z", 
           "2025-06-15T10:35:00Z",
           "2025-06-15T06:05:00Z",
           "2025-06-15T10:30:00Z",
           "2025-06-15T06:00:00Z"
         ]
       );
    });

    it("Should store flight data correctly", async function () {
      await flightOracle.insertFlightDetails(
        sampleFlightData,
        sampleUtcTimes,
        sampleStatus,
        sampleMarketingCodes,
        sampleMarketingFlightNumbers
      );

      // Check UTC times
      const utcTime = await flightOracle.UtcTimes("AA123", "2025-06-15", "AA");
      expect(utcTime.actualArrivalUTC).to.equal("2025-06-15T10:30:00Z");
      expect(utcTime.bagClaim).to.equal("Carousel 3");

      // Check flight status
      const status = await flightOracle.checkFlightStatus("AA123", "2025-06-15", "AA");
      expect(status.flightStatusCode).to.equal("OT");
      expect(status.flightStatusDescription).to.equal("On Time");

      // Check current status
      expect(await flightOracle.setStatus("AA123")).to.equal("On Time");
    });
  });

  describe("Multiple Flight Insertion", function () {
    it("Should insert multiple flights successfully", async function () {
      const flightInput1 = {
        flightdata: sampleFlightData,
        Utctimes: sampleUtcTimes,
        status: sampleStatus,
        MarketingAirlineCode: sampleMarketingCodes,
        marketingFlightNumber: sampleMarketingFlightNumbers
      };

      const flightData2 = [...sampleFlightData];
      flightData2[0] = "DL456"; // Different flight number

      const flightInput2 = {
        flightdata: flightData2,
        Utctimes: sampleUtcTimes,
        status: sampleStatus,
        MarketingAirlineCode: sampleMarketingCodes,
        marketingFlightNumber: sampleMarketingFlightNumbers
      };

      await expect(
        flightOracle.insertMultipleFlightDetails([flightInput1, flightInput2])
      ).to.not.be.reverted;

      expect(await flightOracle.isFlightExist("AA123")).to.be.true;
      expect(await flightOracle.isFlightExist("DL456")).to.be.true;
    });

    it("Should revert if no flight data provided", async function () {
      await expect(
        flightOracle.insertMultipleFlightDetails([])
      ).to.be.revertedWith("No flight data provided");
    });

    it("Should revert if too many flights in batch", async function () {
      const flights = [];
      for (let i = 0; i < 51; i++) {
        flights.push({
          flightdata: sampleFlightData,
          Utctimes: sampleUtcTimes,
          status: sampleStatus,
          MarketingAirlineCode: sampleMarketingCodes,
          marketingFlightNumber: sampleMarketingFlightNumbers
        });
      }

      await expect(
        flightOracle.insertMultipleFlightDetails(flights)
      ).to.be.revertedWith("Too many flights in batch");
    });
  });

  describe("Flight Status Updates", function () {
    beforeEach(async function () {
      await flightOracle.insertFlightDetails(
        sampleFlightData,
        sampleUtcTimes,
        sampleStatus,
        sampleMarketingCodes,
        sampleMarketingFlightNumbers
      );
    });

    it("Should update flight status successfully", async function () {
      await expect(
        flightOracle.updateFlightStatus(
          "AA123",
          "2025-06-15",
          "AA",
          "2025-06-15T05:30:00Z",
          "Delayed",
          "DL"
        )
      ).to.not.be.reverted;

      const status = await flightOracle.checkFlightStatus("AA123", "2025-06-15", "AA");
      expect(status.flightStatusCode).to.equal("DL");
      expect(status.flightStatusDescription).to.equal("Delayed");
      expect(await flightOracle.setStatus("AA123")).to.equal("Delayed");
    });

    it("Should emit FlightStatusUpdate event", async function () {
      await expect(
        flightOracle.updateFlightStatus(
          "AA123",
          "2025-06-15", 
          "AA",
          "2025-06-15T05:30:00Z",
          "Delayed",
          "DL"
        )
      ).to.emit(flightOracle, "FlightStatusUpdate")
       .withArgs(
         "AA123",
         "2025-06-15",
         "2025-06-15T05:30:00Z",
         "AA",
         "Delayed",
         "Arrived",    // ArrivalState from original data
         "Departed",   // DepartureState from original data
         "Carousel 3", // bagClaim from original data
         "DL"
       );
    });

    it("Should revert when updating non-existent flight", async function () {
      await expect(
        flightOracle.updateFlightStatus(
          "XX999",
          "2025-06-15",
          "XX",
          "2025-06-15T05:30:00Z",
          "Delayed",
          "DL"
        )
      ).to.be.revertedWith("Flight does not exist");
    });
  });

  describe("Flight Subscriptions", function () {
    beforeEach(async function () {
      await flightOracle.insertFlightDetails(
        sampleFlightData,
        sampleUtcTimes,
        sampleStatus,
        sampleMarketingCodes,
        sampleMarketingFlightNumbers
      );
    });

    it("Should allow user to subscribe to flight", async function () {
      await expect(
        flightOracle.connect(user1).addFlightSubscription(
          "AA123",
          "AA", 
          "LAX"
        )
      ).to.not.be.reverted;

      expect(
        await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")
      ).to.be.true;
    });

    it("Should emit SubscriptionDetails event on subscribe", async function () {
      await expect(
        flightOracle.connect(user1).addFlightSubscription(
          "AA123",
          "AA",
          "LAX"
        )
      ).to.emit(flightOracle, "SubscriptionDetails")
       .withArgs("AA123", user1.address, "AA", "LAX", true);
    });

    it("Should prevent duplicate subscriptions", async function () {
      await flightOracle.connect(user1).addFlightSubscription(
        "AA123",
        "AA",
        "LAX"
      );

      await expect(
        flightOracle.connect(user1).addFlightSubscription(
          "AA123", 
          "AA",
          "LAX"
        )
      ).to.be.revertedWith("you are already Subscribed user");
    });

    it("Should prevent subscription to non-existent flight", async function () {
      await expect(
        flightOracle.connect(user1).addFlightSubscription(
          "XX999",
          "XX",
          "XXX"
        )
      ).to.be.revertedWith("Flight is not Exist here");
    });

    it("Should allow user to unsubscribe from flights", async function () {
      // Subscribe first
      await flightOracle.connect(user1).addFlightSubscription(
        "AA123",
        "AA",
        "LAX"
      );

      // Unsubscribe
      await expect(
        flightOracle.connect(user1).removeFlightSubscription(
          ["AA123"],
          ["AA"],
          ["LAX"]
        )
      ).to.not.be.reverted;

      expect(
        await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")
      ).to.be.false;
    });

    it("Should emit events on unsubscribe", async function () {
      // Subscribe first
      await flightOracle.connect(user1).addFlightSubscription(
        "AA123",
        "AA",
        "LAX"
      );

      // Unsubscribe and check events
      await expect(
        flightOracle.connect(user1).removeFlightSubscription(
          ["AA123"],
          ["AA"], 
          ["LAX"]
        )
      ).to.emit(flightOracle, "SubscriptionDetails")
       .withArgs("AA123", user1.address, "AA", "LAX", false)
       .and.to.emit(flightOracle, "SubscriptionsRemoved")
       .withArgs(user1.address, 1);
    });
  });

  describe("Date Comparison Helper", function () {
    it("Should compare dates correctly", async function () {
      expect(await flightOracle.isDateLessThanOrEqual("2025-06-14", "2025-06-15")).to.be.true;
      expect(await flightOracle.isDateLessThanOrEqual("2025-06-15", "2025-06-15")).to.be.true;
      expect(await flightOracle.isDateLessThanOrEqual("2025-06-16", "2025-06-15")).to.be.false;
    });

    it("Should revert on invalid date format", async function () {
      await expect(
        flightOracle.isDateLessThanOrEqual("2025-6-14", "2025-06-15")
      ).to.be.revertedWith("Invalid date format");
      
      await expect(
        flightOracle.isDateLessThanOrEqual("2025-06-14", "2025-6-15")
      ).to.be.revertedWith("Invalid date format");
    });
  });
});