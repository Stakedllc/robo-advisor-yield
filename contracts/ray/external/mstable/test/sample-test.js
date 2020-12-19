const { expect } = require("chai");

describe("MyOpportunity", function() {

  it("Should deploy and have an address", async function() {
    const MStable = await ethers.getContractFactory("MStableOpportunity");
    const mStable = await MStable.deploy();
    
    await mStable.deployed();
    expect(mStable.address);
    console.log(mStable.address)
    

  });
 
});
