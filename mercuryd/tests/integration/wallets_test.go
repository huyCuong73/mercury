package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/wallets"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestLedgerTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](CreateEvmd, "evm.IntegrationNetworkApp")
	s := wallets.NewLedgerTestSuite(create)
	suite.Run(t, s)
}
