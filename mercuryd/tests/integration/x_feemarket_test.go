package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/x/feemarket"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestFeeMarketKeeperTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](CreateEvmd, "evm.IntegrationNetworkApp")
	s := feemarket.NewTestKeeperTestSuite(create)
	suite.Run(t, s)
}
