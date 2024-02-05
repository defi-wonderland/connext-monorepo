import { subtask } from "hardhat/config";
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { HardhatRuntimeEnvironment } from "hardhat/types";

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS)
  .setAction(async (_, hre: HardhatRuntimeEnvironment, runSuper) => {
    const paths = await runSuper();

    return paths.filter((p: string) => !p.endsWith(".t.sol") && !p.includes("test/"));
  });
