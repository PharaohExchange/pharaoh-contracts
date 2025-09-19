
export const MULTISIG = ""
export const PAIR_FACTORY = ""
export const WETH = "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f"

export const WEEK = 7 * 24 * 60 * 60;
export const FEES = { STABLE: 500, NORMAL: 3000, EXOTIC: 10000 };
export const TICK_SPACINGS = { STABLE: 10, NORMAL: 60, EXOTIC: 200 };
export const FEES_TO_TICK_SPACINGS: Record<number, number> = {
    500: 10,
    3000: 60,
    10000: 200,
};
