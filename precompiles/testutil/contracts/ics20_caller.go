package contracts

import (
	contractutils "github.com/huyCuong73/mercury/contracts/utils"
	evmtypes "github.com/huyCuong73/mercury/x/vm/types"
)

func LoadIcs20CallerContract() (evmtypes.CompiledContract, error) {
	return contractutils.LoadContractFromJSONFile("ICS20Caller.json")
}
