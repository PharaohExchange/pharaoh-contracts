import { ethers } from "hardhat";

const MainConfig = {
  INITIAL_SUPPLY: ethers.parseEther("50000"),
  MULTISIG: "",
  WETH: "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f",
  INCENTIVE_GROWTH: ethers.parseEther("250"),
  FEE_SETTER: "",
  SALTS: [
    8388, 21667, 111473, 105820, 131817, 138056, 212363, 254261, 291832, 305700,
    315863, 323283, 355373, 483858,1,2,3,4,5,6
  ],

  WHITELIST_TOKENS: [
    "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
  ],
  EMISSIONS_TOKEN_SALT: 1,
};

export { MainConfig };
