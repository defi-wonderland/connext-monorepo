// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Common} from "./Common.sol";
import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {IBridge} from "../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";

import "forge-std/Test.sol";

contract Integration_Connector_TaikoHubConnector is Common {
  error B_STATUS_MISMATCH();
  event RootReceived(uint32 domain, bytes32 receivedRoot, uint256 queueIndex);

  /**
   * @notice Emitted on Taiko's Bridge contract when a message is sent through it
   * @param msgHash The message hash
   * @param message The message
   */
  event MessageSent(bytes32 indexed msgHash, IBridge.Message message);

  /**
   * @notice Tests that the tx for sending the message through the taik signal service the message
   */
  function test_sendMessage() public {
    bytes memory _data = abi.encode(bytes32("aggregateRoot"));
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);

    // Next id grabbed from the Taiko's Bridge state on the current block number
    uint256 _id = 728618;
    IBridge.Message memory _message = IBridge.Message({
      id: _id,
      from: address(taikoHubConnector),
      srcChainId: block.chainid,
      destChainId: taikoHubConnector.SPOKE_CHAIN_ID(),
      user: MIRROR_CONNECTOR,
      to: MIRROR_CONNECTOR,
      refundTo: MIRROR_CONNECTOR,
      value: 0,
      fee: 0,
      gasLimit: _gasCap,
      data: _calldata,
      memo: ""
    });

    // Expect the `MessageSent` event to be emitted correctly with the messag on taiko bridge
    vm.expectEmit(true, true, true, true, address(BRIDGE));
    emit MessageSent(keccak256(abi.encode(_message)), _message);

    // Send message from the root manager
    vm.prank(address(rootManager));
    bytes memory _encodedData = "";
    taikoHubConnector.sendMessage(_data, _encodedData);
  }

  function test_receiveMessage() public {
    // relay message on taiko
    IBridge.Message memory _message = IBridge.Message({
      id: 205254,
      from: 0x0006e19078A46C296eb6b44d37f05ce926403A82,
      srcChainId: 167007,
      destChainId: 11155111,
      user: 0x0006e19078A46C296eb6b44d37f05ce926403A82,
      to: 0xC7501687169b955FAFe10bb9Cd1a1a8FeF8Db1D1,
      refundTo: 0xC7501687169b955FAFe10bb9Cd1a1a8FeF8Db1D1,
      value: 0,
      fee: 0,
      gasLimit: 200_000,
      data: abi.encodeWithSelector(Connector.processMessage.selector, abi.encode(bytes32("aggregateRoot"))),
      memo: ""
    });

    uint256 _queueIndex = 1;
    vm.expectEmit(true, true, true, true, address(rootManager));
    emit RootReceived(MIRROR_DOMAIN, bytes32("aggregateRoot"), _queueIndex);

    bytes
      memory _proof = hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000209a06000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008f6f908f3b90214f90211a0c6867c9926bcd1ada379bc7810418208163eaab11f4b40cc3069a59a826c7830a084803753255a345044b426f0a866d1ddb76c9f99e223c4a922fa8c7866362b6da0281aaf013b06c958759ed721f2ccd72a5d5308c2ec5d35b39a85ef311ec8c176a0b960108995af2f34604efadb65d13bd6a72cbb67a93d48d073e07123cacb19f0a0e07aacadb9909e377351c335fe7fd10192702ebd7c751c7f6292d0cb978b7b23a0a7cf09ea3fb8400696a3b7d8c98978db3cd062978a4747fe2155b858005b405fa05bc936fa76581867140575daf8b704d40986854bad11e51b39bd29d2ecbbeb5fa093f8a7e45bda1d0aadf8ecf3c0a59c71eedcbee8b6a4e7161ade1420b2cc95e3a06268da789462c60ed84ba41930ce176508a51452f5f85a3a3135138053775074a0c9c4608a5cc334edc42b4e2a18d0ffb7f6f1c205ac9407e57b5b655938e2d052a09192532d37ff31cd04546d21af7620674c62a5a881c0fe418133a2eaefcb8ff5a09bbfbb5e060a4d792fd9dfed8fdb638af8173b3449290f5d337cb5b122f09b19a0a79edded040fd1a4c926717eb48bc11f73234067c6a57b48f6a391234f2c12b4a05e1028aae9c0676e60efeb8da5ca9145b010b34ae1e55a23442f5d01920ba406a0fe057d5d342000265585e44415d657a3685ebe6b3a3fdf978deee61f2e42802aa01a074e508ecadec396ea6cede594fb30b13219818845e59216a65a52fee2573080b90214f90211a0a1d210ed15dec52eddfe120362c390acde3320cf9d65a0cd95c9ffa554144719a0aabe84a7a76fe5091bf9b6b3fcf8eb9ea200068f7d16bc893491797fb0d08b0da0f6c6f463daa73bcdc3b91e9d5d1a61b15b18692a1306147c13e38bac0c428c09a0004caa4751c4212966e71cf53e401ac9bb74b1a02f230a671c678abc8f39502ea02acfbbb10fdd64b622662ec2ff3cbb705025205ea3ee18547167de086ef24c14a09c4aebbba254e38d98bee063473953c49c8eb7e72e4c0f99cb78907565f7c4a6a0bdbba38e4340a073056f5613dd35da02de86a9c888ee638a70d8ffb2fa49e151a02e78a1e84da4bece2626b08267b7ed5de08f6e138332d5ba975a0226035845d8a00b34d208d0615ede7de0a4636d6f6383322167799940b80f107e608e40ee3fd4a06405e9c4104c2123986544ed97fd90c28319ba7f1586bd5216e8290484cc2194a054b7a8426ed22f92045b57a6bf2b16847fb8f399a2367cf7644386b6269c5aeca0f6907b952100c1382712abd8df5ee1a7b1826d2449ca4aedc6ec88e50cabcf98a0ceb77e8b72bd81dbfced6ccf559f41e79f3fe92d1cadb9c72865cf87efba8ccca0cb05c6c6bfedf51e3828262dd7e047df0955aac4a73af27acd795c9bbed28955a0bba00ba81e6d55bb9997b095def835a57bdd6ed1abc09b329a989b5c52bf4e96a051c70b7ce78fbbde7ba2f6c1a8496f1f0b0dca88d2a85a085ca8f18808ecf02980b90214f90211a00a49d76443ee38e5950aa604aaf28373154041c9ee4ab08e084135a2a04d625fa0cfc81e9b9d5bae2c1fce23e36c1c890c72fae22bfc6761beb1da8fdfe14b016ea05c938e0ce1f71871793e8f9d87f5944c8559cb16140e066d2303a4b96057eacfa05262843aa5482c858d714c60cf2a0d24bcfedf47fd75c42a40a2ab51b5107dbaa059b46efe4a81a6983b51b2b9ceb563233a0752db55bce1c80a5300de757c0adda0729143f0451558d2f75ab267e2121725a70d663122ffc4a410f820909ec0d8baa051eafe3bd3c6ce408fbac81ea3cb5372425fd11adaee338d79ce8c6c517c0c58a09233793f4934cb1ba8e1a28e9be92ffeb6dca13d219af61e94ee72251a2b1111a05e306093b52fed454b5ab4e6104833a87847cd09a25a45d9ceb183b8286a9d72a0780bb154c974b3571394b0ca7c05ee28d14332762b43556747ddbbf35f6e3374a0d883dcb5a02ac63cb0bd7dc1959a60beb5e73ef582dd203950981d249b941db8a0d0c7a9e4118ef34c95f74aed780fa2feee7972b25d5986cf50e8fa3d4600f4afa0eca0979b7a6a725ba1dbf1f3bcc96b398de44d048e36f97a44a777def583f403a07d32a4a893356e42d5b3c7bf4c9ee2c02fdfde12ce94d81065aa115f60900621a0712aeb1f0362533fbb09e0449d0de361097d1775c8f43be6b8ad6baa74bacacea059bfa940d21663efe0fe7d0170c154d7815bffda482565584d8dbeffd5229b7880b901f4f901f1a06356f9244551b9e583a00dcc802664d7dd7df6d9cacaa4b9418e301bc71068e1a01adccf42adb9f06836054d2ba90da901d3c6b64b669763c0bd57d974c99654b9a0e3bc39f8ade839aa7feaf3d05fcd87e147d21137bb0d51adef65e614756c166ca0d13be634e2b897617ea4e2ce072fad5ba990d95f4399174fc68cb9a584eeb2eca0fd6af0453837b20c1e4724b8433ed724d632d0c6a18378cf62987e929b67e558a00e5518126e9fc5784bea31a1c03f1b5fa640b305239e045b7655b93f1b5a64ad80a07a1e1e15982b0b964ee753601a7620f882ee329c0e03a3fd5e30f955b5c6b744a04b7287149591734f3a0d8e8df1055bef03ac5ad668daa8053c0eef65cd463052a03d226fe54eab77d25748b00bf233f140d29b62af57326394a8a621879b3371f9a0b158ab8f014ddac75f8ea396ef8818a038f5daa6c401c301ded19de89ae549fda0b670fe9d792248540c2ed78909dae3522801d1d04943188e0710550d1ea93d49a09b33b15fd193ba6288db172835389c18a13c16af167f7a2505638a6bf35bf18fa07253ec57eb3c2bd4fd23a9bb5dbdc0e666e2d835c1968dae67bceca3f25f22dea02aa462d37f4d3f7a8b34eff1d3dbea207adb634637338f5d41156dd80df0ecb0a0305a0599776d670fb18f067035d2cfd925d702c3ad6be4e667d1ff6d802ba01980b893f8918080a010a2c9b6e6715e02eeb6ff339840f43914bed8e48577e00b4b66d2eb6939acc8a09416d711e1e131da0016cfddf770e00454b82489a0e123fc7676a67a1e9b73dd8080a0edf2bad5b74236e635f8bf9d420faacb44dc26ae602e45f32f11fb07a6879c1f8080808080a04f1604a9c70fd2db0971ff62e965db52312054e0e0b7d12e3b9d04a4fcd50e4680808080a1e09e3f3d16690f5c2349a1d981ec518142a314b3dc599346d3e4190a5d3ff2ae0100000000000000000000";
    BRIDGE.processMessage(_message, _proof);
  }
}
