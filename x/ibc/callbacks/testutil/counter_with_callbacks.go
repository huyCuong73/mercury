package testutil

import (
	contractutils "github.com/huyCuong73/mercury/contracts/utils"
	evmtypes "github.com/huyCuong73/mercury/x/vm/types"
)

func LoadCounterWithCallbacksContract() (evmtypes.CompiledContract, error) {
	return contractutils.LoadContractFromJSONFile("CounterWithCallbacks.json")
}
