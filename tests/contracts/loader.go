package contracts

import (
	contractutils "github.com/huyCuong73/mercury/contracts/utils"
	evmtypes "github.com/huyCuong73/mercury/x/vm/types"
)

func LoadSimpleERC20() (evmtypes.CompiledContract, error) {
	return contractutils.LoadContractFromJSONFile("account_abstraction/tokens/SimpleERC20.json")
}

func LoadSimpleEntryPoint() (evmtypes.CompiledContract, error) {
	return contractutils.LoadContractFromJSONFile("account_abstraction//entrypoint/SimpleEntryPoint.json")
}

func LoadSimpleSmartWallet() (evmtypes.CompiledContract, error) {
	return contractutils.LoadContractFromJSONFile("account_abstraction/smartwallet/SimpleSmartWallet.json")
}
