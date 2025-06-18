const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("FlightStatusOracle - Advanced Tests", function () {
  let flightOracle;
  let owner;
  let user1, user2, user3;

  // Helper function to create flight data
  function createFlightData(flightNumber, date, carrierCode, city1 = "NYC", city2 = "LAX") {
    return [
      flightNumber,      // flightNumber
      date,              // scheduledDepartureDate
      carrierCode,       // carrierCode
      city1,             // arrivalCity
      city2,             // departureCity
      "JFK",             // arrivalAirport
      "LAX",             // departureAirport
      carrierCode,       // operatingAirlineCode
      "A12",             // arrivalGate
      "B5",              // departureGate
      "On Time",         // flightStatus
      "Boeing 737"       // equipmentModel
    ];
  }

  function createUtcTimes(baseDate) {
    return [
      `${baseDate}T10:30:00Z`, // actualArrivalUTC
      `${baseDate}T06:00:00Z`, // actualDepartureUTC
      `${baseDate}T10:35:00Z`, // estimatedArrivalUTC
      `${baseDate}T06:05:00Z`, // estimatedDepartureUTC
      `${baseDate}T10:30:00Z`, // scheduledArrivalUTC
      `${baseDate}T06:00:00Z`, // scheduledDepartureUTC
      "5",                     // arrivalDelayMinutes
      "5",                     // departureDelayMinutes
      "Carousel 3"             // bagClaim
    ];
  }

  function createStatus(statusCode = "OT", statusDesc = "On Time") {
    return [
      statusCode,              // flightStatusCode
      statusDesc,              // flightStatusDescription
      "Arrived",               // ArrivalState
      "Departed",              // DepartureState
      "2025-06-15T06:00:00Z",  // outUtc
      "2025-06-15T06:15:00Z",  // offUtc
      "2025-06-15T10:15:00Z",  // onUtc
      "2025-06-15T10:30:00Z"   // inUtc
    ];
  }

  beforeEach(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();
    
    const FlightStatusOracle = await ethers.getContractFactory("FlightStatusOracle");
    flightOracle = await FlightStatusOracle.deploy();
    await flightOracle.waitForDeployment();
  });

  describe("Complex Flight Data Management", function () {
    it("Should handle multiple flights with same flight number but different dates", async function () {
      const flightNumber = "AA123";
      const carrierCode = "AA";
      const dates = ["2025-06-15", "2025-06-16", "2025-06-17"];
      
      // Insert flights for different dates
      for (const date of dates) {
        await flightOracle.insertFlightDetails(
          createFlightData(flightNumber, date, carrierCode),
          createUtcTimes(date),
          createStatus(),
          ["AA", "DL"],
          ["AA123", "DL456"]
        );
      }

      // Check that all dates are stored
      const storedDates = await flightOracle.flightDates(flightNumber, carrierCode, 0);
      expect(storedDates).to.equal("2025-06-15");
    });

    it("Should handle multiple carriers for same flight number", async function () {
      const flightNumber = "123";
      const date = "2025-06-15";
      const carriers = ["AA", "DL", "UA"];

      // Insert flight data for different carriers
      for (const carrier of carriers) {
        await flightOracle.insertFlightDetails(
          createFlightData(flightNumber, date, carrier),
          createUtcTimes(date),
          createStatus(),
          [carrier],
          [flightNumber]
        );
      }

      // Verify data exists for all carriers
      const aaStatus = await flightOracle.checkFlightStatus(flightNumber, date, "AA");
      const dlStatus = await flightOracle.checkFlightStatus(flightNumber, date, "DL");
      const uaStatus = await flightOracle.checkFlightStatus(flightNumber, date, "UA");

      expect(aaStatus.flightStatusCode).to.equal("OT");
      expect(dlStatus.flightStatusCode).to.equal("OT");
      expect(uaStatus.flightStatusCode).to.equal("OT");
    });

    it("Should prevent duplicate date entries for same flight/carrier", async function () {
      const flightData = createFlightData("AA123", "2025-06-15", "AA");
      const utcTimes = createUtcTimes("2025-06-15");
      const status = createStatus();

      // Insert same flight data twice
      await flightOracle.insertFlightDetails(
        flightData,
        utcTimes,
        status,
        ["AA"],
        ["AA123"]
      );

      await flightOracle.insertFlightDetails(
        flightData,
        utcTimes,
        status,
        ["AA"],
        ["AA123"]
      );

      // The implementation should handle this gracefully without duplicates
      // This tests the duplicate prevention logic in _storeDateInfo
    });
  });

  describe("Flight Details Retrieval with Date Ranges", function () {
    beforeEach(async function () {
      // Setup multiple flights with different dates
      const flightNumber = "AA123";
      const carrierCode = "AA";
      const dates = ["2025-06-10", "2025-06-15", "2025-06-20", "2025-06-25"];

      for (const date of dates) {
        await flightOracle.insertFlightDetails(
          createFlightData(flightNumber, date, carrierCode),
          createUtcTimes(date),
          createStatus(),
          ["AA", "DL"],
          [flightNumber, "DL456"]
        );
      }
    });

    it("Should retrieve flights within date range", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-06-12",
        currentTimestamp - 1000000, // Within 30 days
        "2025-06-22",
        "AA"
      );

      expect(results.length).to.equal(2); // Should get 2025-06-15 and 2025-06-20
      expect(results[0].scheduledDepartureDate).to.be.oneOf(["2025-06-15", "2025-06-20"]);
      expect(results[1].scheduledDepartureDate).to.be.oneOf(["2025-06-15", "2025-06-20"]);
    });

    it("Should return empty array when no flights in date range", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-07-01",
        currentTimestamp - 1000000,
        "2025-07-10",
        "AA"
      );

      expect(results.length).to.equal(0);
    });

    it("Should revert when flight doesn't exist", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      await expect(
        flightOracle.getFlightDetails(
          "XX999",
          "2025-06-15",
          currentTimestamp - 1000000,
          "2025-06-20",
          "XX"
        )
      ).to.be.revertedWith("Flight does not exist");
    });

    it("Should revert when no data for carrier", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      await expect(
        flightOracle.getFlightDetails(
          "AA123",
          "2025-06-15",
          currentTimestamp - 1000000,
          "2025-06-20",
          "XX" // Non-existent carrier
        )
      ).to.be.revertedWith("No data for carrier");
    });

    it("Should revert when fromDate is older than 30 days", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const oldTimestamp = currentTimestamp - (31 * 24 * 60 * 60); // 31 days ago
      
      await expect(
        flightOracle.getFlightDetails(
          "AA123",
          "2025-05-01",
          oldTimestamp,
          "2025-06-20",
          "AA"
        )
      ).to.be.revertedWith("please enter under 30 days");
    });

    it("Should include marketed flight segments in results", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-06-15",
        currentTimestamp - 1000000,
        "2025-06-15",
        "AA"
      );

      expect(results.length).to.equal(1);
      expect(results[0].marketedSegments.length).to.equal(2);
      expect(results[0].marketedSegments[0].MarketingAirlineCode).to.equal("AA");
      expect(results[0].marketedSegments[0].FlightNumber).to.equal("AA123");
      expect(results[0].marketedSegments[1].MarketingAirlineCode).to.equal("DL");
      expect(results[0].marketedSegments[1].FlightNumber).to.equal("DL456");
    });

    it("Should return correct current status", async function () {
      // Update status first
      await flightOracle.updateFlightStatus(
        "AA123",
        "2025-06-15",
        "AA",
        "2025-06-15T05:30:00Z",
        "Delayed",
        "DL"
      );

      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-06-15",
        currentTimestamp - 1000000,
        "2025-06-15",
        "AA"
      );

      expect(results[0].currentStatus).to.equal("Delayed");
    });
  });

  describe("Advanced Subscription Management", function () {
    beforeEach(async function () {
      // Setup multiple flights
      const flights = [
        { number: "AA123", carrier: "AA", airport: "LAX" },
        { number: "DL456", carrier: "DL", airport: "JFK" },
        { number: "UA789", carrier: "UA", airport: "ORD" }
      ];

      for (const flight of flights) {
        await flightOracle.insertFlightDetails(
          createFlightData(flight.number, "2025-06-15", flight.carrier),
          createUtcTimes("2025-06-15"),
          createStatus(),
          [flight.carrier],
          [flight.number]
        );
      }
    });

    it("Should handle multiple subscriptions for same user", async function () {
      // Subscribe to multiple flights
      await flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX");
      await flightOracle.connect(user1).addFlightSubscription("DL456", "DL", "JFK");
      await flightOracle.connect(user1).addFlightSubscription("UA789", "UA", "ORD");

      // Check all subscriptions
      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user1.address, "DL456", "DL", "JFK")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user1.address, "UA789", "UA", "ORD")).to.be.true;
    });

    it("Should handle bulk unsubscription", async function () {
      // Subscribe to multiple flights first
      await flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX");
      await flightOracle.connect(user1).addFlightSubscription("DL456", "DL", "JFK");
      await flightOracle.connect(user1).addFlightSubscription("UA789", "UA", "ORD");

      // Bulk unsubscribe
      await expect(
        flightOracle.connect(user1).removeFlightSubscription(
          ["AA123", "DL456", "UA789"],
          ["AA", "DL", "UA"],
          ["LAX", "JFK", "ORD"]
        )
      ).to.emit(flightOracle, "SubscriptionsRemoved")
       .withArgs(user1.address, 3);

      // Check all subscriptions are removed
      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.false;
      expect(await flightOracle.isFlightSubscribed(user1.address, "DL456", "DL", "JFK")).to.be.false;
      expect(await flightOracle.isFlightSubscribed(user1.address, "UA789", "UA", "ORD")).to.be.false;
    });

    it("Should handle partial unsubscription (some subscriptions don't exist)", async function () {
      // Subscribe to only one flight
      await flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX");

      // Try to unsubscribe from multiple flights (some don't exist)
      await expect(
        flightOracle.connect(user1).removeFlightSubscription(
          ["AA123", "DL456", "UA789"],
          ["AA", "DL", "UA"],
          ["LAX", "JFK", "ORD"]
        )
      ).to.emit(flightOracle, "SubscriptionsRemoved")
       .withArgs(user1.address, 1); // Only one actual unsubscription

      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.false;
    });

    it("Should allow different users to subscribe to same flight", async function () {
      await flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX");
      await flightOracle.connect(user2).addFlightSubscription("AA123", "AA", "LAX");
      await flightOracle.connect(user3).addFlightSubscription("AA123", "AA", "LAX");

      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user2.address, "AA123", "AA", "LAX")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user3.address, "AA123", "AA", "LAX")).to.be.true;
    });

    it("Should emit correct events for each subscription/unsubscription", async function () {
      // Test subscription events
      await expect(
        flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX")
      ).to.emit(flightOracle, "SubscriptionDetails")
       .withArgs("AA123", user1.address, "AA", "LAX", true);

      // Test unsubscription events
      await expect(
        flightOracle.connect(user1).removeFlightSubscription(
          ["AA123"],
          ["AA"],
          ["LAX"]
        )
      ).to.emit(flightOracle, "SubscriptionDetails")
       .withArgs("AA123", user1.address, "AA", "LAX", false);
    });
  });

  // describe("Gas Optimization and Batch Operations", function () {
  //   it("Should handle maximum batch size efficiently", async function () {
  //     const flightInputs = [];
      
  //     // Create 50 flight inputs (maximum allowed)
  //     for (let i = 0; i < 50; i++) {
  //       flightInputs.push({
  //         flightdata: createFlightData(`FL${i.toString().padStart(3, '0')}`, "2025-06-15", "AA"),
  //         Utctimes: createUtcTimes("2025-06-15"),
  //         status: createStatus(),
  //         MarketingAirlineCode: ["AA"],
  //         marketingFlightNumber: [`FL${i.toString().padStart(3, '0')}`]
  //       });
  //     }

  //     await expect(
  //       flightOracle.insertMultipleFlightDetails(flightInputs)
  //     ).to.not.be.reverted;

  //     // Verify all flights were inserted
  //     for (let i = 0; i < 50; i++) {
  //       const flightNumber = `FL${i.toString().padStart(3, '0')}`;
  //       expect(await flightOracle.isFlightExist(flightNumber)).to.be.true;
  //     }
  //   });

  //   it("Should optimize storage for marketing segments", async function () {
  //     const marketingCodes = ["AA", "DL", "UA", "SW", "B6"];
  //     const marketingNumbers = ["AA123", "DL456", "UA789", "SW012", "B6345"];

  //     await flightOracle.insertFlightDetails(
  //       createFlightData("AA123", "2025-06-15", "AA"),
  //       createUtcTimes("2025-06-15"),
  //       createStatus(),
  //       marketingCodes,
  //       marketingNumbers
  //     );

  //     // Verify all marketing segments are stored
  //     const segments = await flightOracle.MarketedFlightSegments("AA123", "2025-06-15", "AA", 0);
  //     expect(segments.MarketingAirlineCode).to.equal("AA");
  //     expect(segments.FlightNumber).to.equal("AA123");
  //   });
  // });

  describe("Edge Cases and Error Handling", function () {
    it("Should handle empty marketing segments gracefully", async function () {
      await expect(
        flightOracle.insertFlightDetails(
          createFlightData("AA123", "2025-06-15", "AA"),
          createUtcTimes("2025-06-15"),
          createStatus(),
          [], // Empty marketing codes
          []  // Empty marketing numbers
        )
      ).to.not.be.reverted;

      expect(await flightOracle.isFlightExist("AA123")).to.be.true;
    });

    it("Should handle date boundary conditions", async function () {
      // Test with same date for from and to
      await flightOracle.insertFlightDetails(
        createFlightData("AA123", "2025-06-15", "AA"),
        createUtcTimes("2025-06-15"),
        createStatus(),
        ["AA"],
        ["AA123"]
      );

      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-06-15",
        currentTimestamp - 1000000,
        "2025-06-15", // Same date
        "AA"
      );

      expect(results.length).to.equal(1);
    });

    it("Should handle very long flight numbers and codes", async function () {
      const longFlightNumber = "VERYLONGFLIGHTNUMBER123456789";
      const longCarrierCode = "VERYLONGCARRIERCODE";

      await expect(
        flightOracle.insertFlightDetails(
          createFlightData(longFlightNumber, "2025-06-15", longCarrierCode),
          createUtcTimes("2025-06-15"), 
          createStatus(),
          [longCarrierCode],
          [longFlightNumber]
        )
      ).to.not.be.reverted;

      expect(await flightOracle.isFlightExist(longFlightNumber)).to.be.true;
    });

    it("Should handle multiple status updates for same flight", async function () {
      await flightOracle.insertFlightDetails(
        createFlightData("AA123", "2025-06-15", "AA"),
        createUtcTimes("2025-06-15"),
        createStatus(),
        ["AA"],
        ["AA123"]
      );

      const statusUpdates = [
        { status: "Delayed", code: "DL" },
        { status: "Boarding", code: "BD" },
        { status: "Departed", code: "DP" },
        { status: "Arrived", code: "AR" }
      ];

      for (const update of statusUpdates) {
        await expect(
          flightOracle.updateFlightStatus(
            "AA123",
            "2025-06-15",
            "AA",
            "2025-06-15T05:30:00Z",
            update.status,
            update.code
          )
        ).to.not.be.reverted;

        expect(await flightOracle.setStatus("AA123")).to.equal(update.status);
      }
    });
  });

  describe("Complex Date Range Scenarios", function () {
    beforeEach(async function () {
      // Setup flights across multiple months
      const dates = [
        "2025-05-15", "2025-05-30", 
        "2025-06-01", "2025-06-15", "2025-06-30",
        "2025-07-01", "2025-07-15", "2025-07-30"
      ];

      for (const date of dates) {
        await flightOracle.insertFlightDetails(
          createFlightData("AA123", date, "AA"),
          createUtcTimes(date),
          createStatus(),
          ["AA"],
          ["AA123"]
        );
      }
    });

    it("Should handle cross-month date ranges", async function () {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-05-20",
        currentTimestamp - 1000000,
        "2025-06-20",
        "AA"
      );

      // Should get flights from 2025-05-30, 2025-06-01, and 2025-06-15
      expect(results.length).to.equal(3);
    });

    it("Should handle year boundary conditions", async function () {
      // Add flights for year boundary
      await flightOracle.insertFlightDetails(
        createFlightData("AA123", "2024-12-31", "AA"),
        createUtcTimes("2024-12-31"),
        createStatus(),
        ["AA"],
        ["AA123"]
      );

      await flightOracle.insertFlightDetails(
        createFlightData("AA123", "2025-01-01", "AA"),
        createUtcTimes("2025-01-01"),
        createStatus(),
        ["AA"],
        ["AA123"]
      );

      const currentTimestamp = Math.floor(Date.now() / 1000);
      
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2024-12-30",
        currentTimestamp - 1000000,
        "2025-01-05",
        "AA"
      );

      expect(results.length).to.equal(2);
    });
  });

  describe("Integration Tests", function () {
    it("Should handle complete flight lifecycle", async function () {
      // 1. Insert flight
      await flightOracle.insertFlightDetails(
        createFlightData("AA123", "2025-06-15", "AA"),
        createUtcTimes("2025-06-15"),
        createStatus("OT", "On Time"),
        ["AA", "DL"],
        ["AA123", "DL456"]
      );

      // 2. Users subscribe
      await flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX");
      await flightOracle.connect(user2).addFlightSubscription("AA123", "AA", "LAX");

      // 3. Update status multiple times
      await flightOracle.updateFlightStatus(
        "AA123", "2025-06-15", "AA", "2025-06-15T05:30:00Z", "Delayed", "DL"
      );
      await flightOracle.updateFlightStatus(
        "AA123", "2025-06-15", "AA", "2025-06-15T06:30:00Z", "Boarding", "BD"
      );
      await flightOracle.updateFlightStatus(
        "AA123", "2025-06-15", "AA", "2025-06-15T07:00:00Z", "Departed", "DP"
      );

      // 4. Retrieve flight details
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const results = await flightOracle.getFlightDetails(
        "AA123", "2025-06-15", currentTimestamp - 1000000, "2025-06-15", "AA"
      );

      // 5. Verify final state
      expect(results.length).to.equal(1);
      expect(results[0].currentStatus).to.equal("Departed");
      expect(results[0].status.flightStatusCode).to.equal("DP");
      expect(results[0].marketedSegments.length).to.equal(2);

      // 6. Verify subscriptions still active
      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user2.address, "AA123", "AA", "LAX")).to.be.true;

      // 7. Unsubscribe users
      await flightOracle.connect(user1).removeFlightSubscription(["AA123"], ["AA"], ["LAX"]);
      await flightOracle.connect(user2).removeFlightSubscription(["AA123"], ["AA"], ["LAX"]);

      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.false;
      expect(await flightOracle.isFlightSubscribed(user2.address, "AA123", "AA", "LAX")).to.be.false;
    });

    it("Should handle concurrent operations from multiple users", async function () {
      // Setup multiple flights
      const flights = ["AA123", "DL456", "UA789"];
      
      for (const flight of flights) {
        await flightOracle.insertFlightDetails(
          createFlightData(flight, "2025-06-15", flight.substring(0, 2)),
          createUtcTimes("2025-06-15"),
          createStatus(),
          [flight.substring(0, 2)],
          [flight]
        );
      }

      // Multiple users subscribe to different flights simultaneously
      const subscriptionPromises = [
        flightOracle.connect(user1).addFlightSubscription("AA123", "AA", "LAX"),
        flightOracle.connect(user2).addFlightSubscription("DL456", "DL", "JFK"),
        flightOracle.connect(user3).addFlightSubscription("UA789", "UA", "ORD"),
        flightOracle.connect(user1).addFlightSubscription("DL456", "DL", "JFK"),
        flightOracle.connect(user2).addFlightSubscription("UA789", "UA", "ORD"),
        flightOracle.connect(user3).addFlightSubscription("AA123", "AA", "LAX")
      ];

      await Promise.all(subscriptionPromises);

      // Verify all subscriptions
      expect(await flightOracle.isFlightSubscribed(user1.address, "AA123", "AA", "LAX")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user1.address, "DL456", "DL", "JFK")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user2.address, "DL456", "DL", "JFK")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user2.address, "UA789", "UA", "ORD")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user3.address, "UA789", "UA", "ORD")).to.be.true;
      expect(await flightOracle.isFlightSubscribed(user3.address, "AA123", "AA", "LAX")).to.be.true;
    });
  });

  describe("Performance and Scalability", function () {
    it("Should handle large number of flight dates efficiently", async function () {
      const flightNumber = "AA123";
      const carrierCode = "AA";
      
      // Insert flights for 100 different dates
      const promises = [];
      for (let i = 1; i <= 100; i++) {
        const date = `2025-06-${i.toString().padStart(2, '0')}`;
        if (i <= 30) { // Only valid dates in June
          promises.push(
            flightOracle.insertFlightDetails(
              createFlightData(flightNumber, date, carrierCode),
              createUtcTimes(date),
              createStatus(),
              [carrierCode],
              [flightNumber]
            )
          );
        }
      }

      await Promise.all(promises);

      // Test retrieval performance
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const results = await flightOracle.getFlightDetails(
        flightNumber,
        "2025-06-01",
        currentTimestamp - 1000000,
        "2025-06-30",
        carrierCode
      );

      expect(results.length).to.equal(30);
    });

    it("Should maintain performance with many marketing segments", async function () {
      const marketingCodes = [];
      const marketingNumbers = [];
      
      // Create 20 marketing segments
      for (let i = 0; i < 20; i++) {
        marketingCodes.push(`MK${i.toString().padStart(2, '0')}`);
        marketingNumbers.push(`FL${i.toString().padStart(3, '0')}`);
      }

      await expect(
        flightOracle.insertFlightDetails(
          createFlightData("AA123", "2025-06-15", "AA"),
          createUtcTimes("2025-06-15"),
          createStatus(),
          marketingCodes,
          marketingNumbers
        )
      ).to.not.be.reverted;

      // Verify retrieval still works efficiently
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const results = await flightOracle.getFlightDetails(
        "AA123",
        "2025-06-15",
        currentTimestamp - 1000000,
        "2025-06-15",
        "AA"
      );

      expect(results[0].marketedSegments.length).to.equal(20);
    });
  });
});