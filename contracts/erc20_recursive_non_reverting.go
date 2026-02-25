package contracts

import (
	contractutils "github.com/huyCuong73/mercury/contracts/utils"
	evmtypes "github.com/huyCuong73/mercury/x/vm/types"
)

func LoadERC20RecursiveNonReverting() (evmtypes.CompiledContract, error) {
	return contractutils.LoadContractFromJSONFile("solidity/ERC20RecursiveNonRevertingPrecompileCall.json")
}
