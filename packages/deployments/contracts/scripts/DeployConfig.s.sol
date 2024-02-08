// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Executables} from "./Executables.sol";

/// @title DeployConfig
/// @notice Represents the configuration required to deploy the system. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract DeployConfig is Script {
  string internal _json;
  string internal _configJson;

  struct ProtocolConfig {
    uint256 chainId;
    uint256 delayBlocks;
    uint256 domain;
    address hubAmb;
    string name;
    string prefix;
    uint256 processGas;
    uint256 reserveGas;
    address spokeAmb;
    uint256 minDisputeBlocks;
    uint256 disputeBlocks;
  }

  struct AgentConfig {
    mapping(uint256 => address) relayerFeeVaults;
    address[] watchersAllowList;
    address[] watchersBlackList;
    address[] routersAllowList;
    address[] routersBlackList;
    address[] sequencersAllowList;
    address[] sequencersBlackList;
    address[] relayersAllowList;
    address[] relayersBlackList;
  }

  uint256 public domain;
  uint256 public hubChainId;
  uint256 public chainsLength;
  uint256[] public chains;

  mapping(uint256 => ProtocolConfig) internal _protocolConfigs;
  AgentConfig internal _agentConfig;

  constructor(string memory _path) {
    console.log("DeployConfig: reading file %s", _path);
    try vm.readFile(_path) returns (string memory data) {
      _json = data;
    } catch {
      console.log("Warning: unable to read config. Do not deploy unless you are not using config.");
      return;
    }

    domain = stdJson.readUint(_json, "$.domain");
    console.log("Read domain from json: %s", domain);

    // Read messaging config
    try vm.readFile(string.concat(vm.projectRoot(), "/scripts/deploy-config/all.json")) returns (string memory data) {
      _configJson = data;
    } catch {
      console.log("Warning: unable to read messaging config. Do not deploy unless you are not using config.");
      return;
    }
    hubChainId = stdJson.readUint(_configJson, "$.hub");
    chainsLength = stdJson.readUint(_configJson, "$.chains");
    console.log("Read hub chain Id from json: %s", hubChainId);

    for (uint256 index = 0; index < chainsLength; index++) {
      string memory key = string(abi.encodePacked(".messaging.configs[", vm.toString(index), "]"));
      ProtocolConfig memory rawConfig = abi.decode(stdJson.parseRaw(_configJson, key), (ProtocolConfig));
      uint256 chainId = rawConfig.chainId;
      if (_protocolConfigs[chainId].chainId > 0) {
        console.log("Duplicated chain config: %s", chainId);
        continue;
      }

      _protocolConfigs[chainId] = rawConfig;
      chains.push(chainId);

      //Read Relayer Fee Vaults
      key = string(abi.encodePacked("$.agents.relayerFeeVaults.", vm.toString(rawConfig.domain)));
      _agentConfig.relayerFeeVaults[rawConfig.domain] = stdJson.readAddress(_configJson, key);
      console.log(
        "Read relayer fee vault (%s) from json: %s",
        rawConfig.domain,
        _agentConfig.relayerFeeVaults[rawConfig.domain]
      );
    }

    _agentConfig.watchersAllowList = stdJson.readAddressArray(_configJson, "$.agents.watchers.allowlist");
    _agentConfig.watchersBlackList = stdJson.readAddressArray(_configJson, "$.agents.watchers.blacklist");

    _agentConfig.routersAllowList = stdJson.readAddressArray(_configJson, "$.agents.routers.allowlist");
    _agentConfig.routersBlackList = stdJson.readAddressArray(_configJson, "$.agents.routers.blacklist");

    _agentConfig.sequencersAllowList = stdJson.readAddressArray(_configJson, "$.agents.sequencers.allowlist");
    _agentConfig.sequencersBlackList = stdJson.readAddressArray(_configJson, "$.agents.sequencers.blacklist");

    _agentConfig.relayersAllowList = stdJson.readAddressArray(_configJson, "$.agents.relayers.allowlist");
    _agentConfig.relayersBlackList = stdJson.readAddressArray(_configJson, "$.agents.relayers.blacklist");
  }

  function getMessagingConfig(uint256 chainId) public view returns (ProtocolConfig memory config) {
    config = _protocolConfigs[chainId];
  }

  function getAgentRelayerFeeVault(uint256 chainId) public view returns (address) {
    return _agentConfig.relayerFeeVaults[_protocolConfigs[chainId].domain];
  }

  function getAgentWatchersConfig() public view returns (address[] memory allow, address[] memory black) {
    allow = _agentConfig.watchersAllowList;
    black = _agentConfig.watchersAllowList;
  }

  function getAgentRoutersConfig() public view returns (address[] memory allow, address[] memory black) {
    allow = _agentConfig.routersAllowList;
    black = _agentConfig.watchersBlackList;
  }

  function getAgentSequencersConfig() public view returns (address[] memory allow, address[] memory black) {
    allow = _agentConfig.sequencersAllowList;
    black = _agentConfig.sequencersBlackList;
  }

  function getAgentRelayersConfig() public view returns (address[] memory allow, address[] memory black) {
    allow = _agentConfig.relayersAllowList;
    black = _agentConfig.relayersBlackList;
  }

  function getChainIdFromIndex(uint256 index) public view returns (uint256) {
    return chains[index];
  }
}
