package testdata

import (
	contractutils "github.com/huyCuong73/mercury/contracts/utils"
	evmtypes "github.com/huyCuong73/mercury/x/vm/types"
)

func LoadERC20Contract() (evmtypes.CompiledContract, error) {
	return contractutils.LegacyLoadContractFromJSONFile("ERC20Contract.json")
}

func LoadMessageCallContract() (evmtypes.CompiledContract, error) {
	return contractutils.LegacyLoadContractFromJSONFile("MessageCallContract.json")
}

func LoadDelegationTargetContract() (evmtypes.CompiledContract, error) {
	return contractutils.LegacyLoadContractFromJSONFile("DelegationTarget.json")
}

func LoadMaliciousDeployerContract() (evmtypes.CompiledContract, error) {
	return contractutils.LegacyLoadContractFromJSONFile("MaliciousDeployer.json")
}
