package mercuryd

import (
	cmn "github.com/huyCuong73/mercury/precompiles/common"
	evmtypes "github.com/huyCuong73/mercury/x/vm/types"
)

type BankKeeper interface {
	evmtypes.BankKeeper
	cmn.BankKeeper
}
